variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
  default     = "atlantis"
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)."
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region to deploy Atlantis."
  type        = string
  default     = "ap-southeast-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.42.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block."
  type        = string
  default     = "10.42.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for public subnet and EC2. If null, first AZ in region is used."
  type        = string
  default     = null
}

variable "ec2_instance_type" {
  description = "EC2 instance type for Atlantis host."
  type        = string
  default     = "t2.micro"
}

variable "ec2_key_pair_name" {
  description = "Optional EC2 key pair name for SSH access."
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB. Atlantis .tfplan files are stored here."
  type        = number
  default     = 40
}

variable "ssh_allowed_cidrs" {
  description = "CIDR list allowed to SSH into EC2."
  type        = list(string)
  default     = []
}

variable "allowed_web_cidrs" {
  description = "CIDR list allowed to reach HTTPS on EC2/Nginx. Use 0.0.0.0/0 or Cloudflare ranges."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "create_eip" {
  description = "Whether to allocate and attach an Elastic IP to Atlantis EC2."
  type        = bool
  default     = true
}

variable "ingress_mode" {
  description = "Ingress strategy: nginx, cloudflare_quick_tunnel, or cloudflare_named_tunnel."
  type        = string
  default     = "nginx"

  validation {
    condition     = contains(["nginx", "cloudflare_quick_tunnel", "cloudflare_named_tunnel"], var.ingress_mode)
    error_message = "ingress_mode must be nginx, cloudflare_quick_tunnel, or cloudflare_named_tunnel."
  }
}

variable "atlantis_domain" {
  description = "Public hostname for Atlantis webhook endpoint, e.g. atlantis.example.com."
  type        = string
  default     = ""

  validation {
    condition     = var.ingress_mode == "cloudflare_quick_tunnel" || length(trim(var.atlantis_domain)) > 0
    error_message = "atlantis_domain is required for nginx and cloudflare_named_tunnel modes."
  }
}

variable "tls_cert_pem" {
  description = "PEM certificate for Nginx HTTPS. Required when ingress_mode=nginx."
  type        = string
  default     = ""
  sensitive   = true
}

variable "tls_key_pem" {
  description = "PEM private key for Nginx HTTPS. Required when ingress_mode=nginx."
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_owner_allowlist" {
  description = "GitHub owner/org allowlist for Atlantis, e.g. github.com/my-org/*."
  type        = list(string)
}

variable "github_user" {
  description = "GitHub bot username used by Atlantis."
  type        = string
}

variable "github_token_ssm_name" {
  description = "SSM parameter name containing GitHub token (SecureString), e.g. /atlantis/prod/github_token."
  type        = string
}

variable "github_webhook_secret_ssm_name" {
  description = "SSM parameter name containing GitHub webhook secret (SecureString)."
  type        = string
}

variable "enable_repo_level_locking" {
  description = "Enable Atlantis repo locking to serialize apply operations."
  type        = bool
  default     = true
}

variable "terraform_version" {
  description = "Terraform version installed in Atlantis container."
  type        = string
  default     = "1.8.5"
}

variable "atlantis_version" {
  description = "Atlantis container image tag."
  type        = string
  default     = "v0.30.0"
}

variable "create_state_bucket" {
  description = "Create S3 bucket for Terraform remote state."
  type        = bool
  default     = true
}

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform state. Leave empty to auto-generate when create_state_bucket=true."
  type        = string
  default     = ""

  validation {
    condition     = var.create_state_bucket || length(trim(var.state_bucket_name)) > 0
    error_message = "state_bucket_name must be set when create_state_bucket=false."
  }
}

variable "create_lock_table" {
  description = "Create DynamoDB table for Terraform state locking."
  type        = bool
  default     = true
}

variable "lock_table_name" {
  description = "DynamoDB lock table name."
  type        = string
  default     = "terraform-locks"
}

variable "atlantis_extra_iam_policy_arns" {
  description = "Additional IAM policy ARNs to attach to Atlantis EC2 role for provisioning target AWS resources."
  type        = list(string)
  default     = []
}

variable "cloudflare_named_tunnel_token" {
  description = "Token for cloudflared named tunnel (required for ingress_mode=cloudflare_named_tunnel)."
  type        = string
  default     = null
  sensitive   = true
}

variable "quick_tunnel_url" {
  description = "Public Quick Tunnel URL (trycloudflare) if you pin one externally. Used only for Atlantis URL setting in quick mode."
  type        = string
  default     = "https://example.trycloudflare.com"
}

variable "tags" {
  description = "Additional tags for all resources."
  type        = map(string)
  default     = {}
}
