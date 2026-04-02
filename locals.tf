locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })

  use_nginx                   = var.ingress_mode == "nginx"
  use_cloudflare_quick_tunnel = var.ingress_mode == "cloudflare_quick_tunnel"
  use_cloudflare_named_tunnel = var.ingress_mode == "cloudflare_named_tunnel"

  atlantis_public_url = (local.use_nginx || local.use_cloudflare_named_tunnel) ? "https://${var.atlantis_domain}" : var.quick_tunnel_url

  gh_webhook_secret_param_arn = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.github_webhook_secret_ssm_name}"
  gh_token_param_arn          = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.github_token_ssm_name}"
}
