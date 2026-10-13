#!/bin/bash
# Creates the AWS resources for the LiveKit media server: an instance role,
# a security group, an Elastic IP, and a t4g.small instance that runs
# livekit-user-data.sh on first boot. Every resource is tagged project=plugnmeet.
# Run with AWS_PROFILE set to an admin profile. Prints the Elastic IP at the end.
set -euo pipefail

NAME="plugnmeet-livekit"
TAGS="Key=project,Value=plugnmeet"
HERE="$(cd "$(dirname "$0")" && pwd)"
REGION="$(aws configure get region)"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

# Instance role: Session Manager access plus read access to the LiveKit keys.
if ! aws iam get-role --role-name "$NAME" >/dev/null 2>&1; then
  aws iam create-role --role-name "$NAME" --tags "$TAGS" \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null
  aws iam attach-role-policy --role-name "$NAME" \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
  aws iam put-role-policy --role-name "$NAME" --policy-name read-livekit-params \
    --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"ssm:GetParameter\",\"Resource\":\"arn:aws:ssm:${REGION}:${ACCOUNT_ID}:parameter/plugnmeet/livekit/*\"}]}"
  aws iam create-instance-profile --instance-profile-name "$NAME" --tags "$TAGS" >/dev/null
  aws iam add-role-to-instance-profile --instance-profile-name "$NAME" --role-name "$NAME"
  sleep 10 # Let the new instance profile propagate before RunInstances uses it.
fi

# Security group: HTTPS signaling, ICE over TCP, TURN, and the WebRTC UDP range. No SSH.
VPC_ID="$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)"
SG_ID="$(aws ec2 describe-security-groups --filters Name=group-name,Values="$NAME" Name=vpc-id,Values="$VPC_ID" --query 'SecurityGroups[0].GroupId' --output text)"
if [ "$SG_ID" = "None" ]; then
  SG_ID="$(aws ec2 create-security-group --group-name "$NAME" --description "LiveKit media server for plugNmeet" \
    --vpc-id "$VPC_ID" --tag-specifications "ResourceType=security-group,Tags=[{$TAGS}]" --query GroupId --output text)"
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --ip-permissions \
    'IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0,Description=ACME HTTP challenge}]' \
    'IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0,Description=LiveKit signaling over HTTPS}]' \
    'IpProtocol=tcp,FromPort=7881,ToPort=7881,IpRanges=[{CidrIp=0.0.0.0/0,Description=WebRTC ICE over TCP}]' \
    'IpProtocol=udp,FromPort=3478,ToPort=3478,IpRanges=[{CidrIp=0.0.0.0/0,Description=TURN over UDP}]' \
    'IpProtocol=udp,FromPort=50000,ToPort=60000,IpRanges=[{CidrIp=0.0.0.0/0,Description=WebRTC media}]' >/dev/null
fi

# Instance: Graviton t4g.small, standard CPU credits (no surplus charges), IMDSv2 only, encrypted gp3 disk.
INSTANCE_ID="$(aws ec2 describe-instances --filters Name=tag:Name,Values="$NAME" \
  Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[0].Instances[0].InstanceId' --output text)"
if [ "$INSTANCE_ID" = "None" ]; then
  AMI_ID="$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64 --query Parameter.Value --output text)"
  INSTANCE_ID="$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type t4g.small \
    --iam-instance-profile Name="$NAME" --security-group-ids "$SG_ID" \
    --credit-specification CpuCredits=standard \
    --metadata-options HttpTokens=required,HttpEndpoint=enabled,HttpPutResponseHopLimit=2 \
    --block-device-mappings 'DeviceName=/dev/xvda,Ebs={VolumeSize=10,VolumeType=gp3,Encrypted=true,DeleteOnTermination=true}' \
    --user-data "file://${HERE}/livekit-user-data.sh" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NAME},{$TAGS}]" \
      "ResourceType=volume,Tags=[{Key=Name,Value=$NAME},{$TAGS}]" \
    --query 'Instances[0].InstanceId' --output text)"
fi
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

# Elastic IP: a fixed address so DNS and LiveKit survive the scheduled stop and start.
ALLOC_ID="$(aws ec2 describe-addresses --filters Name=tag:Name,Values="$NAME" --query 'Addresses[0].AllocationId' --output text)"
if [ "$ALLOC_ID" = "None" ]; then
  ALLOC_ID="$(aws ec2 allocate-address --domain vpc \
    --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$NAME},{$TAGS}]" --query AllocationId --output text)"
fi
aws ec2 associate-address --instance-id "$INSTANCE_ID" --allocation-id "$ALLOC_ID" >/dev/null

echo "INSTANCE_ID=$INSTANCE_ID"
echo "SECURITY_GROUP=$SG_ID"
echo "ELASTIC_IP=$(aws ec2 describe-addresses --allocation-ids "$ALLOC_ID" --query 'Addresses[0].PublicIp' --output text)"
