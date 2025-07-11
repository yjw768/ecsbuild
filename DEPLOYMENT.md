# GroupUp 私有化部署指南

## 系统要求

- **操作系统**: Ubuntu 20.04+ / CentOS 7+ / Debian 10+
- **CPU**: 最低 2 核心，推荐 4 核心
- **内存**: 最低 4GB，推荐 8GB
- **存储**: 最低 20GB，推荐 50GB+
- **软件**: Docker 20.10+, Docker Compose 2.0+

## 快速部署

### 1. 准备服务器

```bash
# 安装 Docker
curl -fsSL https://get.docker.com | bash

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 2. 克隆项目

```bash
git clone https://github.com/your-repo/groupup.git
cd groupup
```

### 3. 配置环境

编辑 `.env` 文件，设置以下关键配置：

```env
# 数据库密码（自动生成）
POSTGRES_PASSWORD=xxx

# JWT密钥（自动生成）
JWT_SECRET=xxx

# Supabase密钥（需要手动生成）
SUPABASE_ANON_KEY=xxx
SUPABASE_SERVICE_KEY=xxx

# 域名配置
SITE_URL=https://app.yourdomain.com
ALLOWED_URLS=https://app.yourdomain.com

# SMTP邮件配置
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
```

### 4. 生成密钥

使用以下命令生成 Supabase 密钥：

```bash
# 生成 JWT 密钥对
node -e "
const jwt = require('jsonwebtoken');
const secret = process.env.JWT_SECRET || 'your-jwt-secret';

// Anon key
const anonPayload = {
  role: 'anon',
  iss: 'supabase',
  iat: Math.floor(Date.now() / 1000),
  exp: Math.floor(Date.now() / 1000) + (60 * 60 * 24 * 365 * 10) // 10 years
};
console.log('SUPABASE_ANON_KEY:', jwt.sign(anonPayload, secret));

// Service key
const servicePayload = {
  role: 'service_role',
  iss: 'supabase',
  iat: Math.floor(Date.now() / 1000),
  exp: Math.floor(Date.now() / 1000) + (60 * 60 * 24 * 365 * 10) // 10 years
};
console.log('SUPABASE_SERVICE_KEY:', jwt.sign(servicePayload, secret));
"
```

### 5. SSL证书配置

```bash
# 创建SSL目录
mkdir -p ssl

# 方式1：使用 Let's Encrypt (推荐)
sudo certbot certonly --standalone -d app.yourdomain.com -d studio.yourdomain.com
sudo cp /etc/letsencrypt/live/app.yourdomain.com/fullchain.pem ./ssl/cert.pem
sudo cp /etc/letsencrypt/live/app.yourdomain.com/privkey.pem ./ssl/key.pem

# 方式2：使用自签名证书（仅用于测试）
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ./ssl/key.pem \
  -out ./ssl/cert.pem \
  -subj "/C=CN/ST=State/L=City/O=Organization/CN=app.yourdomain.com"
```

### 6. 运行部署脚本

```bash
./deploy.sh
```

## 服务架构

```
┌─────────────────┐     ┌─────────────────┐
│   Nginx (80)   │────▶│   Kong (8000)   │
└─────────────────┘     └─────────────────┘
         │                       │
         │              ┌────────┴────────┐
         │              │                 │
         ▼              ▼                 ▼
┌─────────────────┐ ┌──────────────┐ ┌──────────────┐
│ Studio (3000)   │ │ Auth (9999)  │ │ Rest (3001)  │
└─────────────────┘ └──────────────┘ └──────────────┘
                            │               │
                            └───────┬───────┘
                                    ▼
                          ┌─────────────────┐
                          │ Postgres (5432) │
                          └─────────────────┘
```

## 端口说明

- **80/443**: Nginx (对外服务)
- **3000**: Supabase Studio (管理界面)
- **5432**: PostgreSQL (数据库)
- **8000**: Kong API Gateway
- **9999**: GoTrue (认证服务)
- **3001**: PostgREST (API)
- **4000**: Realtime (实时通信)
- **5000**: Storage (存储服务)

## 维护命令

```bash
# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f [service-name]

# 重启服务
docker-compose restart [service-name]

# 备份数据库
docker-compose exec postgres pg_dump -U postgres postgres > backup.sql

# 恢复数据库
docker-compose exec postgres psql -U postgres postgres < backup.sql

# 更新服务
docker-compose pull
docker-compose up -d
```

## 监控建议

1. **系统监控**: 使用 Prometheus + Grafana
2. **日志管理**: 使用 ELK Stack 或 Loki
3. **备份策略**: 
   - 数据库: 每日备份
   - 存储文件: 增量备份
   - 配置文件: Git 版本控制

## 安全建议

1. **防火墙配置**
   ```bash
   # 只开放必要端口
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw allow 22/tcp
   sudo ufw enable
   ```

2. **定期更新**
   ```bash
   # 更新系统
   sudo apt update && sudo apt upgrade
   
   # 更新 Docker 镜像
   docker-compose pull
   docker-compose up -d
   ```

3. **访问控制**
   - 使用强密码
   - 启用双因素认证
   - 限制管理界面访问IP

## 故障排查

### 数据库连接失败
```bash
# 检查数据库状态
docker-compose logs postgres

# 重启数据库
docker-compose restart postgres
```

### 服务无法访问
```bash
# 检查端口占用
sudo netstat -tlnp | grep :80

# 检查防火墙
sudo ufw status
```

### 存储空间不足
```bash
# 清理Docker垃圾
docker system prune -a

# 检查磁盘使用
df -h
```

## 技术支持

如有问题，请查看：
- 项目 Wiki
- GitHub Issues
- 官方文档