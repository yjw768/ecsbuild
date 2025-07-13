#!/bin/bash

# 完成Supabase设置脚本
ECS_HOST="8.148.211.17"
ECS_USER="root"
ECS_PASSWORD="Yjw202202@"

echo "=== 完成Supabase部署 ==="

# 创建远程脚本
cat > /tmp/complete_supabase.sh << 'EOF'
#!/bin/bash
cd /opt/groupup

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo_info "检查Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    echo_info "重新安装Docker Compose..."
    curl -SL https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi
docker-compose --version

echo_info "创建必要的环境变量文件..."
cat > .env << 'EOL'
# 数据库配置
POSTGRES_PASSWORD=groupup2024secure
POSTGRES_USER=postgres
POSTGRES_DB=postgres

# JWT配置
JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long
ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU

# API URLs - 关键配置
API_EXTERNAL_URL=http://8.148.211.17:8000
SUPABASE_PUBLIC_URL=http://8.148.211.17:8000

# 站点配置
SITE_URL=http://8.148.211.17
PUBLIC_REST_URL=http://8.148.211.17:8000/rest/v1
PUBLIC_REALTIME_URL=ws://8.148.211.17:8000/realtime/v1
PUBLIC_STORAGE_URL=http://8.148.211.17:8000/storage/v1
PUBLIC_AUTH_URL=http://8.148.211.17:8000/auth/v1

# Kong配置
KONG_HTTP_PORT=8000
KONG_HTTPS_PORT=8443

# Studio配置  
STUDIO_PORT=3000
EOL

echo_info "创建docker-compose.yml..."
cat > docker-compose.yml << 'YAML'
version: "3.8"

services:
  # 数据库服务 - 已经运行，跳过
  # postgres:
  #   已经作为单独容器运行

  # Kong API网关
  kong:
    image: kong:2.8.1
    container_name: groupup-kong
    restart: unless-stopped
    ports:
      - "${KONG_HTTP_PORT}:8000"
      - "${KONG_HTTPS_PORT}:8443"
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /home/kong/kong.yml
      KONG_DNS_RESOLVER: 8.8.8.8
      KONG_PLUGINS: request-transformer,cors,key-auth,acl
    volumes:
      - ./kong.yml:/home/kong/kong.yml
    extra_hosts:
      - "host.docker.internal:host-gateway"

  # GoTrue认证服务
  auth:
    image: supabase/gotrue:v2.132.3
    container_name: groupup-auth
    restart: unless-stopped
    ports:
      - "9999:9999"
    environment:
      GOTRUE_API_HOST: 0.0.0.0
      GOTRUE_API_PORT: 9999
      API_EXTERNAL_URL: ${API_EXTERNAL_URL}
      GOTRUE_DB_DRIVER: postgres
      GOTRUE_DB_DATABASE_URL: postgres://postgres:${POSTGRES_PASSWORD}@host.docker.internal:5432/postgres?search_path=auth
      GOTRUE_SITE_URL: ${SITE_URL}
      GOTRUE_URI_ALLOW_LIST: ${SITE_URL},http://localhost:*
      GOTRUE_DISABLE_SIGNUP: false
      GOTRUE_JWT_SECRET: ${JWT_SECRET}
      GOTRUE_JWT_EXP: 3600
      GOTRUE_JWT_DEFAULT_GROUP_NAME: authenticated
      GOTRUE_EXTERNAL_EMAIL_ENABLED: false
      GOTRUE_MAILER_AUTOCONFIRM: true
    extra_hosts:
      - "host.docker.internal:host-gateway"

  # PostgREST API
  rest:
    image: postgrest/postgrest:v11.2.0
    container_name: groupup-rest
    restart: unless-stopped
    ports:
      - "3001:3000"
    environment:
      PGRST_DB_URI: postgres://postgres:${POSTGRES_PASSWORD}@host.docker.internal:5432/postgres
      PGRST_DB_SCHEMAS: public,storage,auth
      PGRST_DB_ANON_ROLE: anon
      PGRST_JWT_SECRET: ${JWT_SECRET}
      PGRST_DB_USE_LEGACY_GUCS: "false"
    extra_hosts:
      - "host.docker.internal:host-gateway"

  # Realtime服务
  realtime:
    image: supabase/realtime:v2.25.35
    container_name: groupup-realtime
    restart: unless-stopped
    ports:
      - "4000:4000"
    environment:
      DB_HOST: host.docker.internal
      DB_PORT: 5432
      DB_NAME: ${POSTGRES_DB}
      DB_USER: ${POSTGRES_USER}
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      SECURE_CHANNELS: "true"
      JWT_SECRET: ${JWT_SECRET}
    extra_hosts:
      - "host.docker.internal:host-gateway"

  # Storage服务
  storage:
    image: supabase/storage-api:v0.43.11
    container_name: groupup-storage
    restart: unless-stopped
    ports:
      - "5000:5000"
    environment:
      ANON_KEY: ${ANON_KEY}
      SERVICE_KEY: ${SERVICE_ROLE_KEY}
      JWT_SECRET: ${JWT_SECRET}
      DATABASE_URL: postgres://postgres:${POSTGRES_PASSWORD}@host.docker.internal:5432/postgres
      STORAGE_BACKEND: file
      FILE_SIZE_LIMIT: 52428800
      TENANT_ID: stub
      REGION: stub
      GLOBAL_S3_BUCKET: stub
    volumes:
      - ./storage:/var/lib/storage
    extra_hosts:
      - "host.docker.internal:host-gateway"

volumes:
  storage-data:

networks:
  default:
    name: groupup-network
YAML

echo_info "创建Kong配置..."
cat > kong.yml << 'YAML'
_format_version: "3.0"
_transform: false

services:
  - name: auth-v1
    url: http://auth:9999
    routes:
      - name: auth-v1-all
        strip_path: true
        paths:
          - /auth/v1
    plugins:
      - name: cors

  - name: rest-v1  
    url: http://rest:3000
    routes:
      - name: rest-v1-all
        strip_path: true
        paths:
          - /rest/v1
    plugins:
      - name: cors

  - name: realtime-v1
    url: http://realtime:4000
    routes:
      - name: realtime-v1-all
        strip_path: true
        paths:
          - /realtime/v1
    plugins:
      - name: cors

  - name: storage-v1
    url: http://storage:5000  
    routes:
      - name: storage-v1-all
        strip_path: false
        paths:
          - /storage/v1
    plugins:
      - name: cors

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
        - Accept-Version
        - Content-Length
        - Content-MD5
        - Content-Type
        - Date
        - X-Auth-Token
        - Authorization
        - apikey
      exposed_headers:
        - X-Auth-Token
        - apikey
      credentials: true
      max_age: 3600
YAML

echo_info "初始化数据库..."
docker exec groupup-postgres psql -U postgres << 'SQL'
-- 创建必要的schema
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS storage;

-- 创建角色
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN  
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN;
  END IF;
END $$;

-- 授权
GRANT USAGE ON SCHEMA public, auth, storage TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
SQL

echo_info "启动Supabase服务..."
docker-compose up -d

echo_info "等待服务启动..."
sleep 20

echo_info "检查服务状态..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo_info "测试API端点..."
echo -e "\n测试Kong网关:"
curl -s http://localhost:8000 || echo "Kong可能还在启动中"

echo -e "\n测试Auth服务:"
curl -s http://localhost:8000/auth/v1/health || echo "Auth服务可能还在启动中"

echo ""
echo_info "================================"
echo_info "Supabase部署完成！"
echo_info "================================"
echo_info "访问地址："
echo_info "- Supabase Studio: http://8.148.211.17:3000"
echo_info "- API网关: http://8.148.211.17:8000"
echo_info "- Auth API: http://8.148.211.17:8000/auth/v1"
echo_info "- REST API: http://8.148.211.17:8000/rest/v1"
echo_info "================================"
EOF

# 执行脚本
echo "执行部署..."
sshpass -p "${ECS_PASSWORD}" scp -o StrictHostKeyChecking=no /tmp/complete_supabase.sh ${ECS_USER}@${ECS_HOST}:/tmp/
sshpass -p "${ECS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${ECS_USER}@${ECS_HOST} "cd /opt/groupup && bash /tmp/complete_supabase.sh"

# 清理
rm -f /tmp/complete_supabase.sh

echo ""
echo "部署完成！"