variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "nimbuscart"
}

variable "web_vpc_cidr" {
  description = "CIDR for Web VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "data_vpc_cidr" {
  description = "CIDR for Data VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "web_public_subnet_cidr" {
  description = "Public subnet for Web tier"
  type        = string
  default     = "10.0.1.0/24"
}

variable "app_private_subnet_cidr" {
  description = "Private subnet for App tier"
  type        = string
  default     = "10.0.2.0/24"
}

variable "data_private_subnet_a_cidr" {
  description = "Data subnet AZ-A"
  type        = string
  default     = "10.1.1.0/24"
}

variable "data_private_subnet_b_cidr" {
  description = "Data subnet AZ-B"
  type        = string
  default     = "10.1.2.0/24"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "db_name" {
  type    = string
  default = "nimbuscart"
}

variable "db_username" {
  type    = string
  default = "nimbus"
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = "NimbusCart123!"
}
variable "admin_cidr" {
  description = "Public IP allowed to SSH into the Web EC2"
  type        = string
}
variable "key_name" {
  description = "Existing AWS EC2 key pair name"
  type        = string
}
variable "ssh_private_key_path" {
  description = "Path to the EC2 SSH private key"
  type        = string
}
