#!/usr/bin/env bash
DATA_DIR=/data/analytics/logs/data-products
[[ -d $DATA_DIR ]] || mkdir -p $DATA_DIR
export SPARK_HOME={{ .Values.global.spark_home }}
export MODELS_HOME={{ .Values.analytics_home }}/models-2.0
export DP_LOGS=$DATA_DIR
## Job to run daily
cd /data/analytics/scripts
source model-config.sh
today=$(date "+%Y-%m-%d")

job_id=$1
if [ ! -z "$1" ]; then job_config=$(config $1 $2); else job_config="$2"; fi
echo "Job config: $job_config" >> "$DP_LOGS/$today-config.log"



echo "Starting the job - $1" >> "$DP_LOGS/$today-job-execution.log"

echo "Job modelName - $job_id" >> "$DP_LOGS/$today-job-execution.log"

nohup $SPARK_HOME/bin/spark-submit \
--conf spark.jars.ivy=/tmp/.ivy \
--conf spark.driver.extraJavaOptions='-Dconfig.file=/data/analytics/scripts/common.conf' \
--master 'local[*]' \
--jars $MODELS_HOME/analytics-framework-2.0.jar,$MODELS_HOME/scruid_2.12-2.5.0.jar,$MODELS_HOME/batch-models-2.0.jar \
--class org.ekstep.analytics.job.JobExecutor \
$MODELS_HOME/batch-models-2.0.jar --model "$job_id" --config "$job_config$batchIds" \
>> "$DP_LOGS/$today-job-execution.log" 2>&1

# Log completion
if [[ $? -eq 0 ]]; then
  echo "Job execution completed successfully - $1" >> "$DP_LOGS/$today-job-execution.log"
else
  echo "Job execution failed - $1" >> "$DP_LOGS/$today-job-execution.log"
fi
