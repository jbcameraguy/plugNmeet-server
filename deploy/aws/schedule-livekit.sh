#!/bin/bash
# Creates EventBridge Scheduler schedules that start the LiveKit instance at 10:30
# and stop it at 15:00 Central time on Tuesdays and Thursdays.
# Usage: AWS_PROFILE=limo-training ./schedule-livekit.sh <instance-id>
set -euo pipefail

INSTANCE_ID="$1"
ROLE="plugnmeet-livekit-scheduler"
TZ_NAME="America/Chicago"
REGION="$(aws configure get region)"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

if ! aws iam get-role --role-name "$ROLE" >/dev/null 2>&1; then
  aws iam create-role --role-name "$ROLE" --tags Key=project,Value=plugnmeet \
    --assume-role-policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"scheduler.amazonaws.com\"},\"Action\":\"sts:AssumeRole\",\"Condition\":{\"StringEquals\":{\"aws:SourceAccount\":\"${ACCOUNT_ID}\"}}}]}" >/dev/null
  sleep 10 # Let the new role propagate before the scheduler validates it.
fi
aws iam put-role-policy --role-name "$ROLE" --policy-name start-stop-livekit \
  --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"ec2:StartInstances\",\"ec2:StopInstances\"],\"Resource\":\"arn:aws:ec2:${REGION}:${ACCOUNT_ID}:instance/${INSTANCE_ID}\"}]}"

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE}"
INPUT="{\\\"InstanceIds\\\":[\\\"${INSTANCE_ID}\\\"]}"

upsert() { # name, cron expression, API action
  local args=(--name "$1" --schedule-expression "$2" --schedule-expression-timezone "$TZ_NAME"
    --flexible-time-window '{"Mode":"OFF"}'
    --target "{\"Arn\":\"arn:aws:scheduler:::aws-sdk:ec2:$3\",\"RoleArn\":\"${ROLE_ARN}\",\"Input\":\"${INPUT}\"}")
  if aws scheduler get-schedule --name "$1" >/dev/null 2>&1; then
    aws scheduler update-schedule "${args[@]}" >/dev/null
  else
    aws scheduler create-schedule "${args[@]}" >/dev/null
  fi
}

upsert plugnmeet-livekit-start 'cron(30 10 ? * TUE,THU *)' startInstances
upsert plugnmeet-livekit-stop 'cron(0 15 ? * TUE,THU *)' stopInstances

aws scheduler list-schedules --name-prefix plugnmeet-livekit --query 'Schedules[].[Name,State]' --output text
