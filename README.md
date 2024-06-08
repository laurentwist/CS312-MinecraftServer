# Minecraft Server

This tutorial demonstrates how to set up a Minecraft server on AWS using Terraform, Ansible, and a Bash script to manage the entire process.

## Requirements

### Install Terraform

To install Terraform, run the following command in terminal.
```
brew install terraform
```

### Configure AWS Credentials

Update your AWS credentials (**aws_access_key_id**, **aws_secret_access_key**, **aws_session_token**) by navigating to the `~/.aws/credentials` file.

### Generate a Key Pair

Create a directory to store the private and public key files, then generate the RSA key pair by executing the following commands in the terminal. While running the command press **Enter** to skip additional prompts. 
```
mkdir -p keys
ssh-keygen -t rsa -b 2048 -f keys/Minecraft-Server-Key
```
This will create `keys/Minecraft-Server-Key` (private key) and `keys/Minecraft-Server-Key.pub` (public key). Once the key pair is generated change the permissions on the private key file to make it usable using the following command. 
```
chmod 600 Minecraft-Server-Key
```

## Terraform File Configurations

Create a directory to store all the Terraform files, then create the Terraform files `main.tf`, `variable.tf`, `output.tf` using the following commands in terminal. 
   ```
   mkdir -p terraform-aws-instance 
   touch terraform-aws-instance/main.tf
   touch terraform-aws-instance/variable.tf
   touch terraform-aws-instance/output.tf
   ```
   
### variable.tf File Set Up 

Include the following content in your `variable.tf` file. You can adjust the region based on the location of the players for the Minecraft server. You can also modify the public key path based on where you've stored your public key.
```
variable "region" {
  description = "The AWS region to deploy the resources"
  type        = string
  default     = "us-west-2"
}

variable "key_name" {
    description = "The name of the key pair"
    type = string
    default = "Minecraft-Server-Key"
}

variable "public_key_path" {
  description = "The path to the public key file"
  type        = string
  default     = "~/ComputerScience/Minecraft-Server/keys/Minecraft-Server-Key.pub"
}
```

### output.tf File Set Up

Include the following content in your `output.tf` file.
```
output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value = aws_instance.minecraft_server.public_ip
}
```

### main.tf File Set Up

Include the following content in your `main.tf` file.
```
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.region
  shared_credentials_files = ["~/.aws/credentials"]
}

resource "aws_instance" "minecraft_server" {
  ami           = "ami-02e8e2a390064c712" 
  instance_type = "t2.medium"
  key_name      = aws_key_pair.minecraft_key.key_name

  vpc_security_group_ids = [aws_security_group.minecraft_sg.id]

  tags = {
    Name = "Minecraft-Server-Bedrock"
  }
}

resource "aws_security_group" "minecraft_sg" {
  name_prefix = "minecraft-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MinecraftSecurityGroup"
  }
}

resource "aws_key_pair" "minecraft_key" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}
```

## Ansible Playbook Configuration

Create the Ansible playbook file `playbook.yml` using the following command in terminal. 
```
touch playbook.yml
```

Include the following content in your `playbook.yml` file.
```yml
---
- hosts: minecraft_server
  become: yes
  tasks:
    - name: Create minecraft_server directory
      file:
        path: /home/ec2-user/minecraft_server
        state: directory
        owner: ec2-user
        group: ec2-user
        mode: '0755'

    - name: Set eula.txt file
      copy:
        content: "eula=true"
        dest: /home/ec2-user/minecraft_server/eula.txt
        owner: ec2-user
        group: ec2-user
        mode: '0644'

    - name: Download Minecraft server JAR file
      get_url:
        url: "https://launcher.mojang.com/v1/objects/a412fd69db1f81db3f511c1463fd304675244077/server.jar"
        dest: "/home/ec2-user/minecraft_server/server.jar"
        owner: ec2-user
        group: ec2-user
        mode: '0644'

    - name: Create systemd file for Minecraft server
      copy:
        content: |
          [Unit]
          Description=Minecraft Server
          After=network.target

          [Service]
          WorkingDirectory=/home/ec2-user/minecraft_server
          ExecStart=/usr/bin/java -Xmx1024M -Xms1024M -jar server.jar nogui
          ExecStop=/bin/kill -s SIGINT $MAINPID
          User=ec2-user
          Restart=on-failure
          RestartSec=5

          [Install]
          WantedBy=multi-user.target
        dest: /etc/systemd/system/minecraft.service
        owner: root
        group: root
        mode: '0644'

    - name: Reload systemd to apply
      systemd:
        daemon_reload: yes

    - name: Start Minecraft server
      systemd:
        name: minecraft
        enabled: yes
        state: started

    - name: Stop Minecraft server
      systemd:
        name: minecraft
        state: stopped
```

## Bash Script Configurations

Create bash script files `deploy.sh` and `destroy.sh` using the following commands in terminal. 
   ```
   touch deploy.sh
   touch destroy.sh
   ```

### deploy.sh Set Up

Include the following content in your `deploy.sh` file. You can modify the region according to the configuration specified in the variable.tf file earlier. You can also modify the private key path based on where you've stored your private key.
```sh
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
```
Give the bash script executable permissions using the following command.
```
chmod +x deploy.sh
```

### destroy.sh Set Up

Include the following content in your `destroy.sh` file. 
```sh
#!/bin/bash

# Define variables
TERRAFORM_DIR="terraform-aws-instance"

# Navigate to the Terraform directory
cd "$TERRAFORM_DIR" || exit

# Destroy the Terraform-managed infrastructure
echo "Destroying Terraform-managed infrastructure..."
terraform destroy -auto-approve

echo "Script execution complete."
```
Give the bash script executable permissions using the following command.
```
chmod +x destroy.sh
```

## Deploying the Minecraft Server

To deploy the Minecraft server run the following command in terminal.
```
./deploy.sh
```
After the deployment script finishes running, verify that the server is operational by executing the following command in the terminal. If the status indicates "open," the server is up and running.
```
nmap -sV -Pn -p T:25565 <instance_public_ip>
```
You're now prepared to enjoy Minecraft 1.17 on your server.

## Destroying the Minecraft Server
This step is entirely optional and will erase all prior progress made in setting up your Minecraft Server. To destroy the Minecraft server run the following command in terminal.
```
./destroy.sh
```