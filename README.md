# Atlantis on EC2 (HTTPS Free Paths)

Bo nay trien khai Atlantis tren EC2 theo dung breakdown flow:
- PR mo/cap nhat -> webhook vao `/events`
- Atlantis `plan` -> luu `.tfplan` tren EBS
- Comment ket qua len PR
- Nguoi dung comment `atlantis apply`
- Atlantis dung lai file `.tfplan` da luu de apply
- Terraform cap nhat state len S3 va lock/unlock bang DynamoDB

## Ingress modes

- `nginx`: HTTPS ket thuc tai Nginx (port 443) roi proxy vao Atlantis `127.0.0.1:4141`.
- `cloudflare_quick_tunnel`: khong can domain, cloudflared mo URL `*.trycloudflare.com` (POC, URL co the doi).
- `cloudflare_named_tunnel`: dung token tunnel cua Cloudflare, domain on dinh, khong can mo 443 vao EC2.

## Yeu cau truoc khi apply

1. Da dang nhap AWS CLI va co quyen tao VPC/EC2/IAM/S3/DynamoDB/SSM.
2. Tao SSM SecureString cho GitHub token va webhook secret.
3. Chuan bi `terraform.tfvars` tu file mau.

## Setup nhanh

1. Tao file bien:
```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Luu secret vao SSM:
```bash
chmod +x scripts/bootstrap_secrets.sh
./scripts/bootstrap_secrets.sh ap-southeast-1 /atlantis/prod/github_token /atlantis/prod/github_webhook_secret <GITHUB_TOKEN>
```

3. Neu dung `nginx`:
- Can cert hop le cho domain webhook.
- Dien `tls_cert_pem` va `tls_key_pem` trong `terraform.tfvars`.
- Mo DNS tro domain ve EIP cua EC2.

4. Apply Terraform:
```bash
terraform init
terraform plan
terraform apply
```

5. Lay endpoint webhook tu output:
```bash
terraform output atlantis_webhook_endpoint
```

## GitHub webhook

- URL: output `atlantis_webhook_endpoint` (duoi dang `https://.../events`)
- Content type: `application/json`
- Secret: chinh la value trong SSM parameter `github_webhook_secret_ssm_name`
- Events:
  - Pull requests
  - Issue comments

## Breakdown flow mapping

1. Tao/cap nhat PR voi code Terraform.
2. GitHub gui webhook HTTPS den Atlantis `/events`.
3. Ingress (Nginx hoac Cloudflare tunnel) chuyen vao Atlantis.
4. Atlantis chay `terraform plan`; state duoc doc tu S3, lock bang DynamoDB.
5. File `.tfplan` luu trong `/var/lib/atlantis` (EBS root volume).
6. Atlantis comment ket qua plan vao PR.
7. Engineer comment `atlantis apply`.
8. GitHub gui webhook lan 2.
9. Atlantis tim dung `.tfplan` da luu, thuc thi apply.
10. Terraform cap nhat `.tfstate` len S3 va unlock DynamoDB.
11. Atlantis comment ket qua apply len PR.

## Ghi chu bao mat

- Khong hardcode GitHub token/webhook secret trong Terraform vars.
- Chi mo SSH cho IP ca nhan qua `ssh_allowed_cidrs`.
- Voi `nginx`, nen chi allow `allowed_web_cidrs` la Cloudflare IP ranges neu dung Cloudflare proxy.
- Gan them policy toi thieu cho `atlantis_extra_iam_policy_arns` thay vi AdminAccess trong production.

## Van hanh

- Atlantis data dir: `/var/lib/atlantis`
- Atlantis compose dir: `/opt/atlantis`
- Bootstrap log: `/var/log/atlantis-bootstrap.log`
- Kiem tra service:
```bash
sudo systemctl status nginx
sudo systemctl status cloudflared
sudo docker ps
```

## Luu y quan trong khi khong co domain

- Ban van co the chay `cloudflare_quick_tunnel` de test full flow ngay.
- De production on dinh, can endpoint co hostname co dinh va cert hop le (domain + nginx hoac cloudflare named tunnel).
