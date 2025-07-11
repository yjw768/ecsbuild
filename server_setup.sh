#!/bin/bash

# GroupUp 服务器初始化脚本
# 适用于Ubuntu 22.04

echo "🚀 开始 GroupUp 服务器初始化..."

# 1. 更新系统包
echo "📦 更新系统包..."
sudo apt update && sudo apt upgrade -y

# 2. 安装基础工具
echo "🛠️ 安装基础工具..."
sudo apt install -y \
    curl \
    wget \
    vim \
    git \
    htop \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# 3. 安装 Docker
echo "🐳 安装 Docker..."
# 添加 Docker 官方 GPG 密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 添加 Docker 仓库
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新包索引并安装 Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# 启动并启用 Docker 服务
sudo systemctl start docker
sudo systemctl enable docker

# 将当前用户添加到 docker 组
sudo usermod -aG docker $USER

# 4. 安装 Docker Compose
echo "📦 安装 Docker Compose..."
DOCKER_COMPOSE_VERSION="v2.21.0"
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 创建符号链接
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# 5. 配置防火墙
echo "🔥 配置防火墙..."
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3000/tcp  # Supabase Studio
sudo ufw allow 8000/tcp  # Kong API Gateway

# 6. 创建项目目录
echo "📁 创建项目目录..."
sudo mkdir -p /opt/groupup
sudo chown $USER:$USER /opt/groupup
cd /opt/groupup

# 7. 创建 .env 文件模板
echo "⚙️ 创建环境配置..."
cat > .env.example << 'EOF'
# GroupUp 环境配置

# 基础配置
POSTGRES_PASSWORD=your_super_secure_password
JWT_SECRET=your_jwt_secret_key
ANON_KEY=your_anon_key
SERVICE_ROLE_KEY=your_service_role_key

# 数据库配置
POSTGRES_HOST=db
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PORT=5432

# Supabase 配置
SITE_URL=http://your-domain.com
ADDITIONAL_REDIRECT_URLS=""
DISABLE_SIGNUP=false

# OSS 配置 (稍后配置)
OSS_ENDPOINT=
OSS_ACCESS_KEY_ID=
OSS_ACCESS_KEY_SECRET=
OSS_BUCKET=
OSS_REGION=

# API 配置
API_EXTERNAL_URL=http://localhost:8000
SUPABASE_PUBLIC_URL=http://localhost:8000

# Studio 配置
STUDIO_DEFAULT_ORGANIZATION=Default Organization
STUDIO_DEFAULT_PROJECT=Default Project
EOF

# 8. 设置系统优化
echo "⚡ 系统性能优化..."
# 增加文件句柄限制
echo "* soft nofile 65535" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65535" | sudo tee -a /etc/security/limits.conf

# 配置内核参数
cat << 'EOF' | sudo tee -a /etc/sysctl.conf
# GroupUp 性能优化
vm.max_map_count=262144
vm.swappiness=10
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
EOF

sudo sysctl -p

# 9. 创建备份目录
echo "💾 创建备份目录..."
sudo mkdir -p /backup/groupup
sudo chown $USER:$USER /backup/groupup

echo "✅ 服务器初始化完成！"
echo ""
echo "📝 下一步:"
echo "1. 注销并重新登录以应用 Docker 组权限"
echo "2. 验证 Docker 安装: docker --version"
echo "3. 验证 Docker Compose: docker-compose --version"
echo ""
echo "🔄 请执行: logout 然后重新连接服务器"