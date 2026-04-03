#!/usr/bin/env bash

config() {
	bucket="{{ .Values.global.private_container_name }}"
	brokerList={{ .Values.global.kafka.host }}:{{ .Values.global.kafka.port }}
	topic={{ .Values.topic }}
	sinkTopic={{ .Values.sink_topic }}

	    if [ -z "$2" ]; then endDate=$(date --date yesterday "+%Y-%m-%d"); else endDate=$2; fi
		if [ ! -z "$3" ]; then inputBucket=$3; fi
		if [ ! -z "$4" ]; then sinkTopic=$4; fi
		if [ ! -z "$2" ]; then keyword=$2; fi
		case "$1" in
		"wfs")
		echo '{"search":{"type":"{{ .Values.global.cloud_storage_provider }}","queries":[{"bucket":"'$bucket'","prefix":"{{ .Values.dp_raw_telemetry_backup_location }}","endDate":"'$endDate'","delta":0}]},"model":"org.ekstep.analytics.model.WorkflowSummary","modelParams":{"apiVersion":"v2","storageKeyConfig":"storage.key.config", "storageSecretConfig":"storage.secret.config"},"output":[{"to":"console","params":{"printEvent": true}},{"to":"kafka","params":{"brokerList":"'$brokerList'","topic":"'$topic'"}}],"parallelization":8,"appName":"Workflow Summarizer","deviceMapping":true}'
		;;
        "*")
		echo "Unknown model code"
      	exit 1 # Command to come out of the program with status 1
      	;;
		esac
   }






