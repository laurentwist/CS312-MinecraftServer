#!/bin/bash

# Define variables
TERRAFORM_DIR="terraform-aws-instance"

# Navigate to the Terraform directory
cd "$TERRAFORM_DIR" || exit

# Destroy the Terraform-managed infrastructure
echo "Destroying Terraform-managed infrastructure..."
terraform destroy -auto-approve

echo "Script execution complete."