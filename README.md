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
This will create `keys/Minecraft-Server-Key` (private key) and `keys/Minecraft-Server-Key.pub` (public key).

## Terraform File Configurations

Create Terraform files `main.tf`, `variable.tf`, `output.tf` using the following command in terminal. 
   ```
   touch main.tf
   touch variable.tf
   touch output.tf
   ```
   
### variable.tf File Set Up 

Include the following content in your variable.tf file. You can adjust the region based on the location of the players for the Minecraft server. You can also modify the public key path based on where you've stored your public key.
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

Include the following content in your output.tf file.
```
output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value = aws_instance.minecraft_server.public_ip
}
```

### main.tf File Set Up

Include the following content in your main.tf file.
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