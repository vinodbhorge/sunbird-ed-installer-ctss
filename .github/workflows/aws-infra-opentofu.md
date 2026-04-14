# AWS Infrastructure — OpenTofu Workflow

**File:** `.github/workflows/aws-infra-opentofu.yml`

This is a manually triggered GitHub Actions workflow that provisions and manages AWS infrastructure using [OpenTofu](https://opentofu.org/) (open-source Terraform) and [Terragrunt](https://terragrunt.gruntwork.io/).

---

## Prerequisites

Before running the workflow, ensure the following are configured in your GitHub repository:

### Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ROLE_ARN` | ARN of the AWS IAM role to assume via OIDC (e.g. `arn:aws:iam::123456789012:role/github-actions-role`) |

### Variables

| Variable | Description |
|----------|-------------|
| `AWS_REGION` | AWS region to deploy into (e.g. `ap-south-1`) |

### GitHub Environments

The workflow uses GitHub Environments to gate deployments and scope secrets/variables. Configure your environments under **Settings → Environments** (e.g. `test`, `staging`, `prod`).

The IAM role must trust the GitHub OIDC provider and allow assumption from your repository. See [Configuring OIDC in AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services).

---

## Directory Structure

The workflow expects the following layout in the repository:

```
opentofu/
└── aws/
    └── <environment-name>/       ← environment_dir input
        ├── create_tf_backend.sh  ← creates the S3 backend bucket
        ├── tf.sh                 ← exports backend config as env vars
        ├── root.hcl              ← root Terragrunt config
        ├── network/
        │   └── terragrunt.hcl
        ├── iam/
        │   └── terragrunt.hcl
        ├── eks/
        │   └── terragrunt.hcl
        └── storage/
            └── terragrunt.hcl
```

Example `environment_dir` value: `opentofu/aws/template`

---

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `environment_dir` | Yes | Path to the OpenTofu environment directory (e.g. `opentofu/aws/template`) |
| `environment` | Yes | GitHub Environment to use — determines which secrets/vars are injected |
| `module` | Yes | Module to target. Choose `all` to run across all modules, or pick a specific one: `network`, `iam`, `eks`, `storage` |
| `action` | Yes | Operation to perform (see [Actions](#actions) below) |
| `destroy_confirmation` | No | Must be set to `DESTROY` (exact string) when `action` is `destroy` |

---

## Actions

| Action | Description |
|--------|-------------|
| `init` | Initialises the Terragrunt/OpenTofu working directory and downloads providers/modules |
| `init-reconfigure` | Same as `init` but passes `-reconfigure` — forces re-initialisation of the backend, useful when backend config changes |
| `plan` | Shows the execution plan — what will be created, changed, or destroyed. Output is saved as a downloadable artifact |
| `apply` | Provisions or updates infrastructure as per the current configuration |
| `destroy` | **Permanently deletes** all resources managed by the selected module. Requires `destroy_confirmation = DESTROY` |

---

## Typical Usage Flow

The recommended order for a fresh environment is:

```
init → plan → apply
```

### 1. Initialise

Go to **Actions → aws-infra-opentofu → Run workflow** and set:

- `environment_dir`: `opentofu/aws/template`
- `environment`: `test`
- `module`: `all`
- `action`: `init`

This sets up the S3 backend and initialises all modules.

### 2. Plan

Run the workflow again with `action: plan`. Review the plan output in:
- The job logs
- The **Artifacts** section of the run (file: `plan-<module>-<run-id>.txt`, retained for 7 days)

### 3. Apply

After reviewing the plan, run with `action: apply`.

### Targeting a Single Module

To work on a single module (e.g. just EKS), set `module: eks` instead of `all`. The workflow will scope its working directory to `<environment_dir>/eks`.

### Reconfiguring the Backend

If backend configuration changes (bucket name, region, key), run:

- `action`: `init-reconfigure`
- `module`: `all` (or the specific module)

This forces Terragrunt to re-initialise against the updated backend config.

---

## Destroy

> **This is irreversible. Destroyed infrastructure cannot be recovered.**

To destroy resources:

1. Set `action: destroy`
2. Set `destroy_confirmation: DESTROY` (the workflow will fail immediately without this)
3. Choose `module: all` to destroy everything or a specific module to scope destruction

---

## How the Workflow Works Internally

```
Trigger (workflow_dispatch)
        │
        ▼
[Validate Destroy Confirmation]  ← fails fast if destroying without confirmation
        │
        ▼
[Checkout] → [Setup OpenTofu] → [Cache/Install Terragrunt] → [Configure AWS OIDC]
        │
        ▼
[Set Working Directory]          ← WORK_DIR = environment_dir (all) or environment_dir/module
        │
        ▼
[Create Backend S3 Bucket]       ← runs create_tf_backend.sh to ensure the state bucket exists
        │
        ▼
[Run selected action]
  ├── init / init-reconfigure    ← terragrunt init [-reconfigure]
  ├── plan                       ← terragrunt plan → saves output as artifact
  ├── apply                      ← terragrunt apply -auto-approve
  └── destroy                    ← terragrunt destroy -auto-approve
```

**Key behaviours:**

- **Concurrency lock:** Only one run targeting the same `environment_dir + module` combination can execute at a time. A second trigger will queue rather than run in parallel, preventing state conflicts.
- **Job timeout:** The job is capped at 60 minutes to prevent runaway apply/destroy operations from consuming Actions minutes indefinitely.
- **Terragrunt binary caching:** The Terragrunt binary is cached by version. Subsequent runs skip the download step.
- **OIDC authentication:** No long-lived AWS credentials are stored. The workflow assumes an IAM role using GitHub's OIDC token, scoped to the selected GitHub Environment.
- **`TF_INPUT=false`:** Interactive prompts are disabled across all steps, ensuring the workflow never hangs waiting for input.

---

## Tool Versions

| Tool | Version |
|------|---------|
| OpenTofu | `1.11.1` |
| Terragrunt | `v0.96.0` |
| setup-opentofu action | `v1.0.4` |

To update versions, modify the `TERRAGRUNT_VERSION` env var and `tofu_version` in the workflow file.
