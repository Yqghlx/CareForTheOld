# SSL 证书配置说明

## 获取证书

### 方式一：购买商业证书
从证书颁发机构（如阿里云、腾讯云）购买 SSL 证书，下载 Nginx 格式。

### 方式二：使用 Let's Encrypt 免费证书

```bash
# 安装 certbot
apt install certbot

# 申请证书（替换为实际域名）
certbot certonly --standalone -d your-domain.com

# 证书路径
# /etc/letsencrypt/live/your-domain.com/fullchain.pem → cert.pem
# /etc/letsencrypt/live/your-domain.com/privkey.pem → key.pem
```

### 方式三：自签名证书（仅测试用）

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout key.pem -out cert.pem \
  -subj "/CN=localhost"
```

## 放置证书

将证书文件放入此目录：
- `cert.pem`：SSL 证书（包含公钥）
- `key.pem`：SSL 私钥

## 注意事项

- 私钥文件权限应为 600，仅 root 可读
- 证书过期前需及时更新（Let's Encrypt 证书有效期 90 天）
- 生产环境建议使用商业证书或配置自动续期
