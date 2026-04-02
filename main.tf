data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "random_string" "state_bucket_suffix" {
  count   = var.create_state_bucket && var.state_bucket_name == "" ? 1 : 0
  length  = 6
  upper   = false
  special = false
}

locals {
  selected_az = var.availability_zone != null ? var.availability_zone : data.aws_availability_zones.available.names[0]

  generated_state_bucket_name = var.state_bucket_name != "" ? var.state_bucket_name : "${local.name_prefix}-tfstate-${random_string.state_bucket_suffix[0].result}"
  effective_state_bucket_name = var.create_state_bucket ? local.generated_state_bucket_name : var.state_bucket_name

  effective_lock_table_name = var.lock_table_name

  github_allowlist_csv = join(",", var.github_owner_allowlist)
}

resource "aws_s3_bucket" "terraform_state" {
  count  = var.create_state_bucket ? 1 : 0
  bucket = local.effective_state_bucket_name

  tags = local.tags
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  count  = var.create_state_bucket ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count  = var.create_state_bucket ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count  = var.create_state_bucket ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_lock" {
  count        = var.create_lock_table ? 1 : 0
  name         = local.effective_lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = local.tags
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = local.selected_az
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-public-subnet"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "atlantis" {
  name        = "${local.name_prefix}-atlantis-sg"
  description = "Security group for Atlantis EC2"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-atlantis-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  for_each          = local.use_nginx ? toset(var.allowed_web_cidrs) : toset([])
  security_group_id = aws_security_group.atlantis.id
  description       = "HTTPS ingress for webhook traffic"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each          = toset(var.ssh_allowed_cidrs)
  security_group_id = aws_security_group.atlantis.id
  description       = "SSH ingress"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.atlantis.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_iam_role" "atlantis_ec2" {
  name = "${local.name_prefix}-atlantis-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "atlantis_runtime" {
  name = "${local.name_prefix}-atlantis-runtime"
  role = aws_iam_role.atlantis_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadGithubSecretsFromSSM"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = [
          local.gh_token_param_arn,
          local.gh_webhook_secret_param_arn
        ]
      },
      {
        Sid    = "StateBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${local.effective_state_bucket_name}",
          "arn:aws:s3:::${local.effective_state_bucket_name}/*"
        ]
      },
      {
        Sid    = "StateLockTableAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:UpdateItem",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${local.effective_lock_table_name}"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "extra" {
  for_each   = toset(var.atlantis_extra_iam_policy_arns)
  role       = aws_iam_role.atlantis_ec2.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "atlantis" {
  name = "${local.name_prefix}-atlantis-instance-profile"
  role = aws_iam_role.atlantis_ec2.name
}

resource "aws_instance" "atlantis" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.atlantis.id]
  iam_instance_profile        = aws_iam_instance_profile.atlantis.name
  key_name                    = var.ec2_key_pair_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region                     = var.aws_region
    atlantis_version               = var.atlantis_version
    terraform_version              = var.terraform_version
    atlantis_public_url            = local.atlantis_public_url
    atlantis_domain                = var.atlantis_domain
    ingress_mode                   = var.ingress_mode
    github_user                    = var.github_user
    github_owner_allowlist         = local.github_allowlist_csv
    github_token_ssm_name          = var.github_token_ssm_name
    github_webhook_secret_ssm_name = var.github_webhook_secret_ssm_name
    enable_repo_level_locking      = tostring(var.enable_repo_level_locking)
    tls_cert_pem_base64            = base64encode(var.tls_cert_pem)
    tls_key_pem_base64             = base64encode(var.tls_key_pem)
    cloudflare_named_tunnel_token  = var.cloudflare_named_tunnel_token != null ? var.cloudflare_named_tunnel_token : ""
  })

  user_data_replace_on_change = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-atlantis"
  })

  lifecycle {
    precondition {
      condition     = !local.use_nginx || (length(trimspace(var.tls_cert_pem)) > 0 && length(trimspace(var.tls_key_pem)) > 0)
      error_message = "tls_cert_pem and tls_key_pem are required when ingress_mode=nginx."
    }

    precondition {
      condition     = !local.use_cloudflare_named_tunnel || (var.cloudflare_named_tunnel_token != null && length(trimspace(var.cloudflare_named_tunnel_token)) > 0)
      error_message = "cloudflare_named_tunnel_token is required when ingress_mode=cloudflare_named_tunnel."
    }
  }
}

resource "aws_eip" "atlantis" {
  count    = var.create_eip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.atlantis.id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-atlantis-eip"
  })
}
