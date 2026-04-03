#!/bin/bash
set -euo pipefail

echo -e "\nPlease ensure you have updated all the mandatory variables as mentioned in the documentation."
echo "The installation will fail if any of the mandatory variables are missing."
echo "Press Enter to continue..."
read -r

environment=$(basename "$(pwd)")

function create_tf_backend() {
    echo -e "Creating terraform state backend"
    bash create_tf_backend.sh
}

function backup_configs() {
    timestamp=$(date +%d%m%y_%H%M%S)
    echo -e "\nBackup existing config files if they exist"
    mkdir -p ~/.kube
    mv ~/.kube/config ~/.kube/config.$timestamp || true
    mkdir -p ~/.config/rclone
    mv ~/.config/rclone/rclone.conf ~/.config/rclone/rclone.conf.$timestamp || true
    export KUBECONFIG=~/.kube/config
}

function create_tf_resources() {
    source tf.sh
    echo -e "\nCreating resources on AWS"
    terragrunt init -upgrade
    terragrunt run-all apply --terragrunt-non-interactive 
    chmod 600 ~/.kube/config
}

function certificate_keys() {
    #  # If keys already present in global-values.yaml → skip writing
    if grep -q -E '^[[:space:]]*CERTIFICATE_PRIVATE_KEY:' ../opentofu/aws/$environment/global-values.yaml 2>/dev/null; then
        echo "Certificate keys already present — skipping generation and write."
        return
    fi
    # Generate private and public keys using openssl
    echo "Creation of RSA keys for certificate signing"
    openssl genrsa -out ../opentofu/aws/$environment/certkey.pem;
    openssl rsa -in ../opentofu/aws/$environment/certkey.pem -pubout -out ../opentofu/aws/$environment/certpubkey.pem;
    
    CERTPRIVATEKEY=$(sed 's/KEY-----/KEY-----\\n/g' ../opentofu/aws/$environment/certkey.pem | sed 's/-----END/\\n-----END/g' | awk '{printf("%s",$0)}')
    CERTPUBLICKEY=$(sed 's/KEY-----/KEY-----\\n/g' ../opentofu/aws/$environment/certpubkey.pem | sed 's/-----END/\\n-----END/g' | awk '{printf("%s",$0)}')
    CERTIFICATESIGNPRKEY=$(sed 's/BEGIN PRIVATE KEY-----/BEGIN PRIVATE KEY-----\\\\n/g' ../opentofu/aws/$environment/certkey.pem | sed 's/-----END PRIVATE KEY/\\\\n-----END PRIVATE KEY/g' | awk '{printf("%s",$0)}')
    CERTIFICATESIGNPUKEY=$(sed 's/BEGIN PUBLIC KEY-----/BEGIN PUBLIC KEY-----\\\\n/g' ../opentofu/aws/$environment/certpubkey.pem | sed 's/-----END PUBLIC KEY/\\\\n-----END PUBLIC KEY/g' | awk '{printf("%s",$0)}')
    
    printf "\n" >> ../opentofu/aws/$environment/global-values.yaml
    echo "  CERTIFICATE_PRIVATE_KEY: \"$CERTPRIVATEKEY\"" >> ../opentofu/aws/$environment/global-values.yaml
    echo "  CERTIFICATE_PUBLIC_KEY: \"$CERTPUBLICKEY\"" >> ../opentofu/aws/$environment/global-values.yaml
    echo "  CERTIFICATESIGN_PRIVATE_KEY: \"$CERTIFICATESIGNPRKEY\"" >> ../opentofu/aws/$environment/global-values.yaml
    echo "  CERTIFICATESIGN_PUBLIC_KEY: \"$CERTIFICATESIGNPUKEY\"" >> ../opentofu/aws/$environment/global-values.yaml
}

function certificate_config() {
    echo "Configuring Certificate keys"
    if ! kubectl -n sunbird exec deploy/nodebb -- which jq >/dev/null 2>&1; then
        echo "jq not found in nodebb container, attempting to install..."
        kubectl -n sunbird exec deploy/nodebb -- bash -c "apt-get update || true"
        kubectl -n sunbird exec deploy/nodebb -- bash -c "apt-get install -y jq || true"
    fi
    
    CERTKEY=$(kubectl -n sunbird exec deploy/nodebb -- curl --location --request POST 'http://registry-service:8081/api/v1/PublicKey/search' --header 'Content-Type: application/json' --data-raw '{ "filters": {}}' | jq '.[] | .value')
    
    if [ -z "$CERTKEY" ]; then
        echo "Certificate RSA public key not available"
        CERTPUBKEY=$(awk -F'"' '/CERTIFICATE_PUBLIC_KEY/{print $2}' global-values.yaml)
        curl_data="curl --location --request POST 'http://registry-service:8081/api/v1/PublicKey' --header 'Content-Type: application/json' --data-raw '{\"value\":\"$CERTPUBKEY\"}'"
        echo "kubectl -n sunbird exec deploy/nodebb -- $curl_data" | sh -
    fi
}

function install_component() {
    kubectl create configmap keycloak-key -n sunbird 2>/dev/null || true
    local current_directory="$(pwd)"
    if [ "$(basename $current_directory)" != "helmcharts" ]; then
        cd ../../../helmcharts 2>/dev/null || true
    fi
    
    local component="$1"
    kubectl create namespace sunbird 2>/dev/null || true
    # kubectl create namespace velero 2>/dev/null || true
    kubectl create namespace volume-autoscaler 2>/dev/null || true
    # kubectl create namespace nlweb 2>/dev/null || true

    echo -e "\nInstalling $component"
    local ed_values_flag=""
    if [ -f "$component/ed-values.yaml" ]; then
        ed_values_flag="-f $component/ed-values.yaml --wait --wait-for-jobs"
    fi
    
    if [ $component = "learnbb" ]; then
        if kubectl get job keycloak-kids-keys -n sunbird >/dev/null 2>&1; then
            echo "Deleting existing job keycloak-kids-keys..."
            kubectl delete job keycloak-kids-keys -n sunbird
        fi

        if [ -f "certkey.pem" ] && [ -f "certpubkey.pem" ]; then
            echo "Certificate keys are already created. Skipping the keys creation..."
        else
            certificate_keys
        fi
    fi
    
    helm upgrade --install "$component" "$component" --namespace sunbird -f "$component/values.yaml" \
        $ed_values_flag \
        -f "images.yaml" \
        -f "global-resources.yaml" \
        -f "../opentofu/aws/$environment/global-values.yaml" \
        -f "../opentofu/aws/$environment/global-cloud-values.yaml" --timeout 30m --debug
}

function install_helm_components() {
    components=("monitoring" "edbb" "learnbb" "knowledgebb" "obsrvbb" "inquirybb" "additional")
    for component in "${components[@]}"; do
        install_component "$component"
    done
}

function dns_mapping() {
    echo -e "\nConfiguring DNS..."
    public_lb=$(kubectl get svc -n sunbird nginx-public-ingress -ojsonpath='{.status.loadBalancer.ingress[0].hostname}')
    domain=$(yq '.global.domain' global-values.yaml)
    
    echo "Public LoadBalancer: $public_lb"
    echo "Domain: $domain"
    
    # Check if Route53 is managed
    manage_dns=$(yq '.global.manage_dns' global-values.yaml)
    
    if [ "$manage_dns" = "true" ]; then
        zone_id=$(yq '.global.route53_zone_id' global-values.yaml)
        aws_region=$(yq '.global.cloud_storage_region' global-values.yaml)
        
        echo "Creating Route53 CNAME record..."
        aws route53 change-resource-record-sets --hosted-zone-id "$zone_id" --change-batch "{
          \"Changes\": [{
            \"Action\": \"UPSERT\",
            \"ResourceRecordSet\": {
              \"Name\": \"$domain\",
              \"Type\": \"CNAME\",
              \"TTL\": 300,
              \"ResourceRecords\": [{\"Value\": \"$public_lb\"}]
            }
          }]
        }"
        
        echo "✓ DNS record created for $domain pointing to $public_lb"
        
        # Wait for DNS propagation
        echo "Waiting for DNS propagation (this may take a few minutes)..."
        local timeout=$((SECONDS + 600))
        while [ $SECONDS -lt $timeout ]; do
            current_dns=$(dig +short "$domain" | tail -n1)
            if [ -n "$current_dns" ]; then
                echo "✓ DNS propagated successfully: $domain -> $current_dns"
                return
            fi
            echo "Waiting for DNS propagation... (retrying in 10 seconds)"
            sleep 10
        done
        echo "⚠ DNS propagation timeout. Please verify manually."
    else
        echo ""
        echo "======================================"
        echo "MANUAL DNS CONFIGURATION REQUIRED"
        echo "======================================"
        echo "Please create a CNAME record:"
        echo "  Name:  $domain"
        echo "  Type:  CNAME"
        echo "  Value: $public_lb"
        echo "  TTL:   300"
        echo "======================================"
        echo ""
        echo "After configuring DNS, wait for propagation and then run:"
        echo "./install.sh generate_postman_env"
        echo "./install.sh run_post_install"
    fi
}

function generate_postman_env() {
    local current_directory="$(pwd)"
    if [ "$(basename $current_directory)" != "$environment" ]; then
        cd ../opentofu/aws/$environment 2>/dev/null || true
    fi
    
    domain_name=$(kubectl get cm -n sunbird lms-env -ojsonpath='{.data.sunbird_web_url}')
    blob_store_path=$(kubectl get cm -n sunbird player-env -o jsonpath='{.data.sunbird_public_storage_account_name}' | sed 's|/$||')
    public_bucket=$(kubectl get cm -n sunbird player-env -ojsonpath='{.data.cloud_storage_resourceBundle_bucketname}')
    api_key=$(kubectl get cm -n sunbird player-env -ojsonpath='{.data.sunbird_api_auth_token}')
    keycloak_secret=$(kubectl get cm -n sunbird player-env -ojsonpath='{.data.sunbird_portal_session_secret}')
    keycloak_admin=$(kubectl get cm -n sunbird userorg-env -ojsonpath='{.data.sunbird_sso_username}')
    keycloak_password=$(kubectl get cm -n sunbird userorg-env -ojsonpath='{.data.sunbird_sso_password}')
    generated_uuid=$(uuidgen)
    
    temp_file=$(mktemp)
    cp postman.env.json "${temp_file}"
    
    sed -e "s|REPLACE_WITH_DOMAIN|${domain_name}|g" \
        -e "s|REPLACE_WITH_APIKEY|${api_key}|g" \
        -e "s|REPLACE_WITH_SECRET|${keycloak_secret}|g" \
        -e "s|REPLACE_WITH_KEYCLOAK_ADMIN|${keycloak_admin}|g" \
        -e "s|REPLACE_WITH_KEYCLOAK_PASSWORD|${keycloak_password}|g" \
        -e "s|GENERATE_UUID|${generated_uuid}|g" \
        -e "s|BLOB_STORE_PATH|${blob_store_path}|g" \
        -e "s|PUBLIC_CONTAINER_NAME|${public_bucket}|g" \
        "${temp_file}" >"env.json"

    echo -e "A env.json file is created in this directory: opentofu/aws/$environment"
    echo "Import the env.json file into postman to invoke other APIs"
}

function restart_workloads_using_keys() {
    echo -e "\nRestart workloads using keycloak keys and wait for them to start..."
    kubectl rollout restart deployment -n sunbird neo4j knowledge-mw player report content adminutil cert-registry groups userorg lms notification registry analytics
    kubectl rollout status deployment -n sunbird neo4j knowledge-mw player report content adminutil cert-registry groups userorg lms notification registry analytics
}

function run_post_install() {
    local current_directory="$(pwd)"
    if [ "$(basename $current_directory)" != "$environment" ]; then
        cd ../opentofu/aws/$environment 2>/dev/null || true
    fi
    
    check_pod_status
    echo "Starting post install..."
    cp ../../../postman-collection/collection${RELEASE}.json .
    postman collection run collection${RELEASE}.json --environment env.json --delay-request 500 --bail --insecure
}

function post_install_nodebb_plugins() {
    echo ">> Waiting for NodeBB deployment to be ready..."
    kubectl rollout status deployment nodebb -n sunbird --timeout=300s

    echo ">> Activating NodeBB plugins..."
    kubectl exec -n sunbird deploy/nodebb -- ./nodebb activate nodebb-plugin-create-forum
    kubectl exec -n sunbird deploy/nodebb -- ./nodebb activate nodebb-plugin-sunbird-oidc
    kubectl exec -n sunbird deploy/nodebb -- ./nodebb activate nodebb-plugin-write-api

    echo ">> Rebuilding NodeBB to apply plugin changes..."
    kubectl exec -n sunbird deploy/nodebb -- ./nodebb build

    echo ">> Restarting NodeBB..."
    kubectl delete pod -n sunbird -l app.kubernetes.io/name=nodebb

    echo "✓ NodeBB plugins activated and restarted"
}

function create_client_forms() {
    local current_directory="$(pwd)"
    if [ "$(basename $current_directory)" != "$environment" ]; then
        cd ../opentofu/aws/$environment 2>/dev/null || true
    fi
    
    cp -rf ../../../postman-collection/ED-${RELEASE} .
    check_pod_status
    
    for FILES in ED-${RELEASE}/*.json; do
        echo "Creating client forms in.. $FILES"
        postman collection run $FILES --environment env.json --delay-request 500 --bail --insecure
    done
}

function cleanworkspace() {
        rm certkey.pem certpubkey.pem
        sed -i '/CERTIFICATE_PRIVATE_KEY:/d' global-values.yaml
        sed -i '/CERTIFICATE_PUBLIC_KEY:/d' global-values.yaml
        sed -i '/CERTIFICATESIGN_PRIVATE_KEY:/d' global-values.yaml
        sed -i '/CERTIFICATESIGN_PUBLIC_KEY:/d' global-values.yaml
        echo "cleanup completed"
}

function destroy_tf_resources() {
    source tf.sh
    cleanworkspace
    echo -e "Destroying resources on AWS cloud"
    terragrunt run-all destroy
}

function invoke_functions() {
    for func in "$@"; do
        $func
    done
}

function check_pod_status() {
    echo -e "\nRemove any orphaned pods if they exist."
    kubectl get pod -n sunbird --no-headers | grep -v Completed | grep -v Running | awk '{print $1}' | xargs -I {} kubectl delete -n sunbird pod {} || true
    local timeout=$((SECONDS + 600))
    consecutive_runs=0
    echo "Ensure the pods are stable for 100 seconds"
    
    while [ $SECONDS -lt $timeout ]; do
        if ! kubectl get pods --no-headers -n sunbird | grep -v Running | grep -v Completed; then
            echo "All pods are running successfully."
            break
        else
            ((consecutive_runs++))
        fi

        if [ $consecutive_runs -ge 10 ]; then
            echo "Timed out after 10 tries. Some pods are still not running successfully. Check the crashing pod logs and resolve the issues. Once pods are running successfully, re-reun this script as below:"
            echo "./install.sh run_post_install"
            exit
        fi

        echo "Number of crashing pods found. Countdown to 10"
        sleep 10
    done
    echo "All pods are running successfully."
}

RELEASE="release700"
POSTMAN_COLLECTION_LINK="https://api.postman.com/collections/5338608-e28d5510-20d5-466e-a9ad-3fcf59ea9f96?access_key=PMAT-01HMV5SB2ZPXCGNKD74J7ARKRQ"

if [ $# -eq 0 ]; then
    create_tf_backend
    backup_configs
    create_tf_resources
    cd ../../../helmcharts
    install_helm_components
    cd ../opentofu/aws/$environment
    post_install_nodebb_plugins
    restart_workloads_using_keys
    certificate_config
    dns_mapping
    generate_postman_env
    run_post_install
    create_client_forms
else
    case "$1" in
    "create_tf_backend")
        create_tf_backend
        ;;
    "create_tf_resources")
        create_tf_resources
        ;;
    "generate_postman_env")
        generate_postman_env
        ;;
    "dns_mapping")
        dns_mapping
        ;;
    "install_component")
        shift
        install_component "$1"
        ;;
    "install_helm_components")
        install_helm_components
        ;;
    "run_post_install")
        run_post_install
        ;;
    "destroy_tf_resources")
        destroy_tf_resources
        ;;
    "certificate_config")
        certificate_config
        ;;
    "create_client_forms")
        create_client_forms
        ;;
    "post_install_nodebb_plugins")
        post_install_nodebb_plugins
        ;;
    *)
        invoke_functions "$@"
        ;;
    esac
fi
