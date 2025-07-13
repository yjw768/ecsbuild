#!/bin/bash

# GroupUp 当前部署备份脚本
ECS_HOST="8.148.211.17"
ECS_USER="root"
ECS_PASSWORD="Yjw202202@"

echo "=== 开始备份 GroupUp 部署 ==="

# 创建本地备份目录
BACKUP_DIR="groupup-deployment-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR

echo "📁 备份目录: $BACKUP_DIR"

# 创建远程备份脚本
cat > /tmp/remote_backup.sh << 'EOF'
#!/bin/bash
cd /opt/groupup

echo "🗄️ 备份数据库..."
docker exec groupup-postgres pg_dump -U postgres postgres > database_backup.sql

echo "📋 备份配置文件..."
# 确保所有配置文件存在
if [ ! -f .env ]; then
    echo "EXPO_PUBLIC_API_URL=http://8.148.211.17:8000/api/v1" > .env
fi

if [ ! -f kong.yml ]; then
    cat > kong.yml << 'KONG'
_format_version: "2.1"

services:
  - name: api-v1
    url: http://172.17.0.1:3001
    routes:
      - name: api-v1-all
        strip_path: true
        paths:
          - /api/v1

plugins:
  - name: cors
    config:
      origins:
        - "*"
      methods:
        - GET
        - POST
        - PUT
        - DELETE
        - OPTIONS
        - HEAD
        - PATCH
      headers:
        - Accept
        - Content-Type
        - Authorization
        - apikey
      credentials: true
      max_age: 3600
KONG
fi

echo "📦 创建部署包..."
tar -czf deployment-package.tar.gz \
  database_backup.sql \
  .env \
  kong.yml \
  simple-api.js \
  package.json \
  Dockerfile

echo "✅ 备份完成: deployment-package.tar.gz"
ls -lh deployment-package.tar.gz
EOF

# 执行远程备份
echo "🔗 连接到服务器执行备份..."
sshpass -p "${ECS_PASSWORD}" scp -o StrictHostKeyChecking=no /tmp/remote_backup.sh ${ECS_USER}@${ECS_HOST}:/tmp/
sshpass -p "${ECS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${ECS_USER}@${ECS_HOST} "cd /opt/groupup && bash /tmp/remote_backup.sh"

# 下载备份文件
echo "⬇️ 下载备份文件..."
sshpass -p "${ECS_PASSWORD}" scp -o StrictHostKeyChecking=no ${ECS_USER}@${ECS_HOST}:/opt/groupup/deployment-package.tar.gz ${BACKUP_DIR}/

# 解压备份查看内容
echo "📂 解压备份文件..."
cd ${BACKUP_DIR}
tar -xzf deployment-package.tar.gz
ls -la

# 创建部署脚本模板
echo "📝 创建部署脚本模板..."
cat > deploy_to_new_host.sh << 'DEPLOY'
#!/bin/bash

# GroupUp 新主机部署脚本
# 使用方法: ./deploy_to_new_host.sh 新主机IP 用户名 密码

set -e

if [ $# -ne 3 ]; then
    echo "使用方法: $0 <新主机IP> <用户名> <密码>"
    echo "示例: $0 1.2.3.4 root mypassword"
    exit 1
fi

NEW_HOST_IP="$1"
SSH_USER="$2"
SSH_PASSWORD="$3"

echo "=== GroupUp 新主机部署 ==="
echo "目标主机: $NEW_HOST_IP"

# 创建远程部署脚本
cat > /tmp/deploy_script.sh << 'EOF'
#!/bin/bash
set -e

echo "🔧 安装必要软件..."
apt-get update -y
apt-get install -y docker.io curl wget

# 安装Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 启动Docker
systemctl start docker
systemctl enable docker

echo "📁 创建工作目录..."
mkdir -p /opt/groupup
cd /opt/groupup

echo "📝 更新配置文件IP地址..."
# 更新.env文件
sed -i "s/8\.148\.211\.17/${NEW_HOST_IP}/g" .env

# 更新kong.yml文件
sed -i "s/8\.148\.211\.17/${NEW_HOST_IP}/g" kong.yml

# 更新API文件
sed -i "s/8\.148\.211\.17/${NEW_HOST_IP}/g" simple-api.js

echo "🌐 创建Docker网络..."
docker network create groupup-network 2>/dev/null || true

echo "🗄️ 启动PostgreSQL..."
docker run -d --name groupup-postgres \
  --network groupup-network \
  -e POSTGRES_PASSWORD=groupup2024 \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=postgres \
  -p 5432:5432 \
  postgres:15-alpine

echo "⏳ 等待数据库启动..."
sleep 30

echo "📊 恢复数据库..."
if [ -f database_backup.sql ]; then
    docker exec -i groupup-postgres psql -U postgres < database_backup.sql
    echo "✅ 数据库恢复完成"
else
    echo "⚠️ 没有找到数据库备份文件"
fi

echo "🔨 构建API镜像..."
docker build -t groupup-api .

echo "🚀 启动API服务..."
docker run -d --name groupup-api \
  --network groupup-network \
  -p 3001:3001 \
  --add-host=groupup-postgres:172.17.0.1 \
  groupup-api

echo "🌉 启动Kong网关..."
docker run -d --name groupup-kong \
  --network groupup-network \
  -p 8000:8000 -p 8443:8443 \
  -e KONG_DATABASE=off \
  -e KONG_DECLARATIVE_CONFIG=/home/kong/kong.yml \
  -v /opt/groupup/kong.yml:/home/kong/kong.yml \
  kong:2.8.1

echo "🎨 启动Studio管理界面..."
docker run -d --name groupup-studio \
  --network groupup-network \
  -p 3000:3000 \
  -e SUPABASE_URL=http://${NEW_HOST_IP}:8000 \
  -e POSTGRES_PASSWORD=groupup2024 \
  supabase/studio:latest

echo "⏳ 等待服务启动..."
sleep 20

echo "🔍 检查服务状态..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🎉 部署完成！"
echo "========================"
echo "访问地址："
echo "- API接口: http://${NEW_HOST_IP}:8000/api/v1"
echo "- Studio管理: http://${NEW_HOST_IP}:3000"
echo "- 健康检查: http://${NEW_HOST_IP}:8000/api/v1/health"
echo "========================"
EOF

# 上传文件并执行部署
echo "📤 上传文件到新主机..."
sshpass -p "$SSH_PASSWORD" scp -r . $SSH_USER@$NEW_HOST_IP:/opt/groupup/

echo "🚀 执行部署脚本..."
sshpass -p "$SSH_PASSWORD" scp /tmp/deploy_script.sh $SSH_USER@$NEW_HOST_IP:/tmp/
sshpass -p "$SSH_PASSWORD" ssh $SSH_USER@$NEW_HOST_IP "cd /opt/groupup && bash /tmp/deploy_script.sh"

echo ""
echo "🎯 部署完成！请更新你的React Native应用配置："
echo "EXPO_PUBLIC_API_URL=http://$NEW_HOST_IP:8000/api/v1"
DEPLOY

chmod +x deploy_to_new_host.sh

# 创建快速检查脚本
cat > quick_health_check.sh << 'CHECK'
#!/bin/bash
# 快速健康检查脚本
# 使用方法: ./quick_health_check.sh 主机IP

HOST_IP="${1:-8.148.211.17}"

echo "🔍 检查 GroupUp 服务状态..."
echo "主机: $HOST_IP"
echo ""

echo "1️⃣ API健康检查:"
curl -s http://$HOST_IP:8000/api/v1/health | jq . 2>/dev/null || echo "❌ API服务异常"

echo -e "\n2️⃣ 用户列表检查:"
USERS=$(curl -s http://$HOST_IP:8000/api/v1/users | jq length 2>/dev/null)
if [ "$USERS" ]; then
    echo "✅ 找到 $USERS 个用户"
else
    echo "❌ 用户数据异常"
fi

echo -e "\n3️⃣ Studio界面检查:"
STUDIO=$(curl -s -I http://$HOST_IP:3000 | head -n1)
if [[ $STUDIO == *"200"* ]] || [[ $STUDIO == *"307"* ]]; then
    echo "✅ Studio界面正常"
else
    echo "❌ Studio界面异常"
fi

echo -e "\n🏁 检查完成"
CHECK

chmod +x quick_health_check.sh

cd ..

# 清理
rm -f /tmp/remote_backup.sh

echo ""
echo "🎉 备份完成！"
echo "=========================="
echo "📁 备份位置: $BACKUP_DIR"
echo "📦 包含文件:"
ls -la $BACKUP_DIR
echo ""
echo "🚀 使用方法："
echo "1. 迁移到新主机:"
echo "   cd $BACKUP_DIR"
echo "   ./deploy_to_new_host.sh 新主机IP 用户名 密码"
echo ""
echo "2. 健康检查:"
echo "   ./quick_health_check.sh 主机IP"
echo "=========================="