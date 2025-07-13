#!/bin/bash

# GroupUp 自动化部署脚本
# 适用于: Ubuntu 22.04 + 2核4GB + 阿里云ECS
# 维护者: Claude + yjw768

set -e  # 遇到错误立即退出

echo "🚀 GroupUp 自动化部署开始"
echo "=========================="
echo "时间: $(date)"
echo "服务器: $(hostname)"
echo "用户: $(whoami)"
echo ""

# 检查运行环境
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 root 用户运行此脚本"
    exit 1
fi

if [ ! -f "/opt/groupup/.env" ]; then
    echo "❌ 环境配置文件不存在: /opt/groupup/.env"
    echo "请先运行初始化脚本创建环境配置"
    exit 1
fi

# 进入项目目录
cd /opt/groupup

echo "📋 当前目录内容:"
ls -la

echo ""
echo "🔧 检查 Docker 服务..."
if ! systemctl is-active --quiet docker; then
    echo "启动 Docker 服务..."
    systemctl start docker
fi

echo "✅ Docker 版本: $(docker --version)"
echo "✅ Docker Compose 版本: $(docker compose version)"

echo ""
echo "🌐 配置 Docker 镜像加速..."
if [ ! -f "/etc/docker/daemon.json" ]; then
    tee /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ],
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    systemctl restart docker
    echo "✅ Docker 镜像加速配置完成"
fi

echo ""
echo "📥 下载最新部署配置..."
# 使用国内适配的 docker-compose 配置
cat > docker-compose.yml <<'EOF'
version: "3.8"

services:
  # PostgreSQL 数据库
  db:
    image: postgres:15-alpine
    container_name: groupup-db
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_USER: postgres
      POSTGRES_DB: postgres
      POSTGRES_HOST_AUTH_METHOD: trust
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init_database.sql:/docker-entrypoint-initdb.d/init_database.sql:ro
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  # Kong API 网关
  kong:
    image: kong:3.5-alpine
    container_name: groupup-kong
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /kong/kong.yml
      KONG_PROXY_ACCESS_LOG: /dev/stdout
      KONG_ADMIN_ACCESS_LOG: /dev/stdout
      KONG_PROXY_ERROR_LOG: /dev/stderr
      KONG_ADMIN_ERROR_LOG: /dev/stderr
      KONG_ADMIN_LISTEN: 0.0.0.0:8001
    volumes:
      - ./kong.yml:/kong/kong.yml:ro
    ports:
      - "8000:8000"
      - "8001:8001"
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  # Supabase Studio
  studio:
    image: supabase/studio:20240101-ce42139
    container_name: groupup-studio
    environment:
      SUPABASE_URL: http://kong:8000
      SUPABASE_ANON_KEY: ${ANON_KEY}
      SUPABASE_SERVICE_KEY: ${SERVICE_ROLE_KEY}
      STUDIO_PG_META_URL: http://meta:8080
    ports:
      - "3000:3000"
    depends_on:
      - kong
      - meta
    restart: unless-stopped

  # PostgREST API
  rest:
    image: postgrest/postgrest:v12.0.2
    container_name: groupup-rest
    environment:
      PGRST_DB_URI: postgres://postgres:${POSTGRES_PASSWORD}@db:5432/postgres
      PGRST_DB_SCHEMAS: public
      PGRST_DB_ANON_ROLE: anon
      PGRST_JWT_SECRET: ${JWT_SECRET}
      PGRST_DB_USE_LEGACY_GUCS: "false"
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  # Meta API
  meta:
    image: supabase/postgres-meta:v0.75.0
    container_name: groupup-meta
    environment:
      PG_META_PORT: 8080
      PG_META_DB_HOST: db
      PG_META_DB_PORT: 5432
      PG_META_DB_NAME: postgres
      PG_META_DB_USER: postgres
      PG_META_DB_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "8080:8080"
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

volumes:
  postgres_data:

networks:
  default:
    name: groupup_network
EOF

echo "✅ Docker Compose 配置已创建"

echo ""
echo "🔧 创建 Kong 配置..."
cat > kong.yml <<'EOF'
_format_version: "3.0"

services:
  - name: rest
    url: http://rest:3000
    routes:
      - name: rest-route
        strip_path: true
        paths:
          - /rest/v1/

  - name: meta
    url: http://meta:8080
    routes:
      - name: meta-route
        strip_path: true
        paths:
          - /pg/

plugins:
  - name: cors
    config:
      origins:
        - "*"
      methods:
        - GET
        - POST
        - PUT
        - PATCH
        - DELETE
        - OPTIONS
      headers:
        - Accept
        - Accept-Version
        - Content-Length
        - Content-MD5
        - Content-Type
        - Date
        - X-Auth-Token
        - Authorization
        - X-Client-Info
      exposed_headers:
        - X-Auth-Token
      credentials: true
      max_age: 3600
EOF

echo "✅ Kong 配置已创建"

echo ""
echo "📦 拉取 Docker 镜像..."
docker compose pull

echo ""
echo "🚀 启动服务..."
docker compose up -d

echo ""
echo "⏳ 等待服务启动..."
sleep 30

echo ""
echo "📊 检查服务状态..."
docker compose ps

echo ""
echo "🔍 服务健康检查..."
echo "数据库连接测试:"
if docker compose exec -T db pg_isready -U postgres; then
    echo "✅ 数据库连接正常"
else
    echo "❌ 数据库连接失败"
fi

echo ""
echo "🌐 访问地址:"
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "8.148.211.17")
echo "- API 网关: http://${PUBLIC_IP}:8000"
echo "- Supabase Studio: http://${PUBLIC_IP}:3000"
echo "- Kong 管理: http://${PUBLIC_IP}:8001"

echo ""
echo "📝 常用命令:"
echo "- 查看日志: docker compose logs -f"
echo "- 重启服务: docker compose restart"
echo "- 停止服务: docker compose down"
echo "- 数据库连接: docker compose exec db psql -U postgres"

echo ""
echo "✅ 部署完成!"
echo "如遇问题，请查看日志: docker compose logs -f"