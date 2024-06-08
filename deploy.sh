#!/bin/bash

# Define variables
PRIVATE_KEY_PATH="~/ComputerScience/Minecraft-Server/keys/Minecraft-Server-Key"
HOSTS_FILE="../hosts"
PLAYBOOK_FILE="../playbook.yml"
TERRAFORM_DIR="terraform-aws-instance" 
USERNAME="ec2-user"  
REGION="us-west-2" 

# Navigate to the Terraform directory
cd "$TERRAFORM_DIR" || exit

# Terraform commands
echo "Initializing Terraform..."
terraform init

echo "Applying Terraform configuration..."
terraform apply -auto-approve

# Get EC2 instance public IP address from Terraform output
EC2_PUBLIC_IP=$(terraform output -json instance_public_ip | jq -r '.')

# Transform the public IP address into the EC2 public DNS name
EC2_PUBLIC_DNS="ec2-${EC2_PUBLIC_IP//./-}.${REGION}.compute.amazonaws.com"

# SSH into the server and install JDK 19.0.2
echo "Connecting to the EC2 instance and installing Java JDK 19.0.2..."
ssh -i "$PRIVATE_KEY_PATH" "$USERNAME@$EC2_PUBLIC_DNS" << 'EOF'
  sudo yum install -y java
  java --version
EOF

# Write the public DNS name to the Ansible hosts file using cat
cat <<EOL > $HOSTS_FILE
[minecraft_server]
${EC2_PUBLIC_DNS}   ansible_user=${USERNAME}    ansible_ssh_private_key_file=${PRIVATE_KEY_PATH}
EOL

# Run the ansible playbook 
ansible-playbook $PLAYBOOK_FILE -i $HOSTS_FILE

echo "Script execution complete."