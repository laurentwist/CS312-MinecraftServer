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
  default     = "~/ComputerScience/Minecraft-Server/keys/Minecraft-Server-Private-Key.pub"
}