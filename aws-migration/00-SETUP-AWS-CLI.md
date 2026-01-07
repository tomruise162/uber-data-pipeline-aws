# AWS CLI Installation and Setup Guide

## Bước 1: Cài đặt AWS CLI

### Option A: Download Installer (Khuyến nghị)

1. **Download AWS CLI v2 cho Windows**:
   - Link: https://awscli.amazonaws.com/AWSCLIV2.msi
   - Hoặc: https://aws.amazon.com/cli/

2. **Chạy installer**:
   - Double-click file `AWSCLIV2.msi`
   - Click "Next" → "Next" → "Install"
   - Chờ cài đặt hoàn tất

3. **Verify installation**:
   ```powershell
   # Mở PowerShell mới và chạy:
   aws --version
   # Nên hiển thị: aws-cli/2.x.x Python/3.x.x Windows/...
   ```

### Option B: Sử dụng Chocolatey (nếu đã cài)

```powershell
choco install awscli
```

### Option C: Sử dụng pip (nếu có Python)

```powershell
pip install awscli
```

---

## Bước 2: Lấy AWS Credentials

Bạn cần **Access Key ID** và **Secret Access Key** từ AWS Console.

### Cách lấy credentials:

1. **Đăng nhập AWS Console**:
   - https://console.aws.amazon.com/

2. **Vào IAM Console**:
   - https://console.aws.amazon.com/iam/

3. **Tạo Access Key**:
   - Click vào tên user (góc phải trên)
   - Chọn "Security credentials"
   - Scroll xuống "Access keys"
   - Click "Create access key"
   - Chọn use case: "Command Line Interface (CLI)"
   - Check "I understand..." → Next
   - (Optional) Add description tag
   - Click "Create access key"

4. **Lưu credentials**:
   - **Access Key ID**: Sẽ hiển thị (ví dụ: AKIAIOSFODNN7EXAMPLE)
   - **Secret Access Key**: Click "Show" để xem (chỉ hiện 1 lần!)
   - **QUAN TRỌNG**: Download .csv file hoặc copy ngay, không thể xem lại!

---

## Bước 3: Cấu hình AWS CLI

```powershell
# Chạy lệnh configure
aws configure

# Nhập thông tin khi được hỏi:
# AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region name [None]: ap-southeast-1
# Default output format [None]: json
```

**Thông tin cần nhập**:
- **Access Key ID**: Paste key vừa tạo
- **Secret Access Key**: Paste secret key vừa tạo
- **Region**: `ap-southeast-1` (Singapore - giống bucket của bạn)
- **Output format**: `json`

---

## Bước 4: Verify Setup

```powershell
# Test AWS CLI
aws --version

# Test credentials
aws sts get-caller-identity

# Nên hiển thị:
# {
#     "UserId": "AIDAI...",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/your-username"
# }

# Test S3 access
aws s3 ls s3://uber-data-v1 --region ap-southeast-1

# Nên hiển thị nội dung bucket (hoặc empty nếu chưa có gì)
```

---

## Bước 5: Chạy lại Deployment Script

Sau khi cài đặt và cấu hình xong:

```powershell
cd d:\DE_project\uber-etl-pipeline-data-engineering-project\aws-migration

# Chạy lại script
.\01-upload-to-s3.ps1
```

---

## Troubleshooting

### Issue: "aws: command not found"
**Solution**: 
- Restart PowerShell sau khi cài AWS CLI
- Hoặc thêm AWS CLI vào PATH:
  ```powershell
  $env:Path += ";C:\Program Files\Amazon\AWSCLIV2"
  ```

### Issue: "Unable to locate credentials"
**Solution**:
- Chạy lại `aws configure`
- Kiểm tra file credentials tại: `C:\Users\ADMIN\.aws\credentials`

### Issue: "Access Denied"
**Solution**:
- Kiểm tra IAM user có quyền S3 và Glue
- Attach policy: `AmazonS3FullAccess` và `AWSGlueConsoleFullAccess`

### Issue: "Region not found"
**Solution**:
- Đảm bảo region là `ap-southeast-1`
- Chạy: `aws configure set region ap-southeast-1`

---

## Quick Reference

```powershell
# Check AWS CLI version
aws --version

# Check current configuration
aws configure list

# Check credentials
aws sts get-caller-identity

# List S3 buckets
aws s3 ls

# List specific bucket
aws s3 ls s3://uber-data-v1 --region ap-southeast-1

# Reconfigure
aws configure
```

---

## Next Steps

Sau khi setup xong AWS CLI:

1. ✅ Verify `aws --version` works
2. ✅ Verify `aws sts get-caller-identity` returns your account
3. ✅ Verify `aws s3 ls s3://uber-data-v1` works
4. ▶️ Run `.\01-upload-to-s3.ps1`

---

## IAM Permissions Required

User cần có các permissions sau:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "glue:*",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:PutRolePolicy",
        "athena:*"
      ],
      "Resource": "*"
    }
  ]
}
```

Hoặc attach các managed policies:
- `AmazonS3FullAccess`
- `AWSGlueConsoleFullAccess`
- `IAMFullAccess` (hoặc ít nhất quyền tạo role)
- `AmazonAthenaFullAccess`
