n#!/bin/bash
# Author: IM-Hanzou 
# Install awscli and jq first!

#banner
cat << "EOF"
  ___    ___   ___          ___   _____         _                
 | __|  / __| |_  )  ___   / __| |_   _|  ___  | |__  ___   _ _  
 | _|  | (__   / /  |___| | (__    | |   / _ \ | / / / -_) | ' \ 
 |___|  \___| /___|        \___|   |_|   \___/ |_\_\ \___| |_||_|
                                                                 
EOF
printf "AWS Instance Creator using AWS Session Token\n\n"
# awscli check
if ! command -v aws > /dev/null; then
    echo "jq is not installed. Please install awscli first."
    exit 1
fi
# jq check
if ! command -v jq > /dev/null; then
    echo "jq is not installed. Please install jq first."
    exit 1
fi
# credentials set
read -p "Access Key ID: " key 
read -p "Secret Key: " secret
read -p "Token Key: " token
read -p "Region: " region
echo " => Credentials Loaded!"
# awscli ec2 access check
perm=$(aws ec2 describe-regions)
if [[ $perm =~ "Regions" ]]; then
    echo " => Access Granted!"
else
    echo " => Access Denied!"
    exit 1
fi
echo "============================================================================="

export AWS_ACCESS_KEY_ID=$key
export AWS_SECRET_ACCESS_KEY=$secret
export AWS_SESSION_TOKEN=$token
export AWS_DEFAULT_REGION=$region

printf "\n"
echo "========================= Enter Instance Details ============================"
printf "\n"
# security group
read -p "SecurityGroup Name: " security_group
sgroup=$(aws ec2 create-security-group --group-name $security_group --description "SSH Access" --output text)
if [[ $sgroup =~ "sg-" ]]; then
    echo " => Security Group Created!" 
else
    echo " => Security Group Already Exists!"
fi
printf "\n"
# enable port 
read -p "Enabled Port? (22 ssh/3389 winrdp or other): " port
eport=$(aws ec2 authorize-security-group-ingress --group-name $security_group --protocol tcp --port "$port" --cidr 0.0.0.0/0)
if [[ $eport =~ "true" ]]; then
    echo " => Port $port Enabled!"
else
    echo " => Port $port Already Enabled!"
fi
printf "\n"
# keypair
read -p "KeyPair Name: " key_pair
key=$(aws ec2 create-key-pair --key-name $key_pair --query 'KeyMaterial' --output text)
if [[ $key =~ "-----BEGIN RSA PRIVATE KEY-----" ]]; then
    echo " => Key Pair Created!" 
    echo "$key" > "$key_pair".pem
else
    echo " => Key Pair Already Exists!"
fi
printf "\n"
# make instance
echo "Insert AMI from your selected Region!"
echo "For list ami details (ubuntu) you can check in https://cloud-images.ubuntu.com/locator/ec2/"
echo "Other OS? maybe you can try this! https://gist.github.com/magnetikonline/e822a78a9b691d86d6e45626f8f0c977"
printf "\n"
read -p "Insert AMI (ex ami-12345): " ami
printf "\n"
printf "Insert instance type\n. You can instance types here! https://aws.amazon.com/ec2/instance-types/\n"
read -p "Instance Type: " instance_type
run_instance=$(aws ec2 run-instances --image-id "$ami" --instance-type "$instance_type" --key-name "$key_pair" --security-group-ids "$sgroup" --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=100}' --region "$region" | jq -r '.Instances[0].InstanceId')
if [[ $run_instance =~ "i-" ]]; then
    printf "\n => Success!\n => Instance Created!\n" 
    echo "============================================================================="
else
    echo " => Failed to Create Instance!"
    echo "============================================================================="
    exit 1
fi
printf "\n"
# instance details
echo "============================= Instance Details =============================="
echo "Your Instance ID: $run_instance"
ipinstance=$(aws ec2 describe-instances --instance-ids "$run_instance" --query 'Reservations[].Instances[].PublicIpAddress' --output text)
echo "Your Instance IP: $ipinstance"
echo "Your KeyPair: $key_pair"
echo "============================================================================="
printf "\n"
echo "============================= How to connect ================================"
echo "(Linux): ssh -i $key_pair.pem ubuntu@$ipinstance"
echo "(Windows): use remote desktop software. then do this command" 
echo "[aws ec2 get-password-data --instance-id  "$run_instance" --priv-launch-key "$key_pair".pem --region "$region"]"
echo "============================================================================="

# unset credentials
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
unset AWS_DEFAULT_REGION
