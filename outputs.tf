output "atlantis_instance_id" {
  description = "Atlantis EC2 instance ID."
  value       = aws_instance.atlantis.id
}

output "atlantis_public_ip" {
  description = "Atlantis public IPv4 address (EIP if enabled)."
  value       = var.create_eip ? aws_eip.atlantis[0].public_ip : aws_instance.atlantis.public_ip
}

output "atlantis_webhook_endpoint" {
  description = "Configure GitHub/GitLab webhook to this endpoint."
  value       = "${local.atlantis_public_url}/events"
}

output "terraform_state_bucket" {
  description = "S3 bucket used as Terraform remote backend bucket."
  value       = local.effective_state_bucket_name
}

output "terraform_lock_table" {
  description = "DynamoDB table used for Terraform state lock."
  value       = local.effective_lock_table_name
}

output "backend_tf_snippet" {
  description = "Copy this backend configuration into Terraform repos managed by Atlantis."
  value       = <<-EOT
terraform {
  backend "s3" {
    bucket         = "${local.effective_state_bucket_name}"
    key            = "env/prod/terraform.tfstate"
    region         = "${var.aws_region}"
    dynamodb_table = "${local.effective_lock_table_name}"
    encrypt        = true
  }
}
EOT
}
