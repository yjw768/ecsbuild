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
