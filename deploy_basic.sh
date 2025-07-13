#!/bin/bash

# GroupUp 基础服务部署脚本
# 只部署核心数据库服务，用于测试

echo "🔧 GroupUp 基础服务部署"
echo "======================="

cd /opt/groupup

echo "📦 创建基础服务配置..."
cat > docker-compose-basic.yml <<'EOF'
version: "3.8"

services:
  # PostgreSQL 数据库
  db:
    image: postgres:15-alpine
    container_name: groupup-db-basic
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-test123}
      POSTGRES_USER: postgres
      POSTGRES_DB: postgres
    volumes:
      - postgres_data_basic:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  # 简单 Web 服务器 (测试用)
  web:
    image: nginx:alpine
    container_name: groupup-web-basic
    ports:
      - "8080:80"
    volumes:
      - ./test.html:/usr/share/nginx/html/index.html:ro
    restart: unless-stopped

volumes:
  postgres_data_basic:
EOF

echo "📄 创建测试页面..."
cat > test.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>GroupUp Server</title>
    <style>
        body { font-family: Arial; text-align: center; margin-top: 100px; }
        .status { color: green; font-size: 24px; }
    </style>
</head>
<body>
    <h1>🚀 GroupUp Server</h1>
    <p class="status">✅ 基础服务运行正常</p>
    <p>服务器时间: <script>document.write(new Date())</script></p>
    <hr>
    <p>下一步: 部署完整 Supabase 服务</p>
</body>
</html>
EOF

echo "🚀 启动基础服务..."
docker compose -f docker-compose-basic.yml up -d

echo "⏳ 等待服务启动..."
sleep 10

echo "📊 检查服务状态..."
docker compose -f docker-compose-basic.yml ps

echo ""
echo "🔍 测试数据库连接..."
if docker compose -f docker-compose-basic.yml exec -T db pg_isready -U postgres; then
    echo "✅ 数据库连接正常"
else
    echo "❌ 数据库连接失败"
fi

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "8.148.211.17")
echo ""
echo "🌐 访问地址:"
echo "- 测试页面: http://${PUBLIC_IP}:8080"
echo "- 数据库: ${PUBLIC_IP}:5432"

echo ""
echo "✅ 基础服务部署完成!"
echo "接下来可以运行: ./deploy_supabase.sh"