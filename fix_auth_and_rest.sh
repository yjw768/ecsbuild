#!/bin/bash

# 修复Auth和REST服务脚本
ECS_HOST="8.148.211.17"
ECS_USER="root"
ECS_PASSWORD="Yjw202202@"

echo "=== 修复Auth和REST服务 ==="

# 创建远程修复脚本
cat > /tmp/fix_services.sh << 'EOF'
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

echo_info "1. 清理旧容器..."
docker stop groupup-auth groupup-rest 2>/dev/null
docker rm groupup-auth groupup-rest 2>/dev/null

echo_info "2. 确认PostgreSQL密码..."
# 检查实际的PostgreSQL密码
PG_PASSWORD=$(docker exec groupup-postgres printenv POSTGRES_PASSWORD)
echo_info "PostgreSQL密码: $PG_PASSWORD"

echo_info "3. 初始化数据库schema..."
docker exec -i groupup-postgres psql -U postgres << 'SQL'
-- 创建必要的schema
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS storage;
CREATE SCHEMA IF NOT EXISTS realtime;

-- 创建角色
DO $$ 
BEGIN
  -- 创建anon角色
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  
  -- 创建authenticated角色
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  
  -- 创建service_role角色
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN BYPASSRLS;
  END IF;
  
  -- 创建postgrest角色（用于PostgREST连接）
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'supabase123';
  END IF;
END $$;

-- 授权
GRANT anon TO authenticator;
GRANT authenticated TO authenticator;
GRANT service_role TO authenticator;

-- 授权schema权限
GRANT USAGE ON SCHEMA public, auth, storage TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated, service_role;

-- 创建auth.users表（如果不存在）
CREATE TABLE IF NOT EXISTS auth.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id UUID,
    aud VARCHAR(255),
    role VARCHAR(255),
    email VARCHAR(255) UNIQUE,
    encrypted_password VARCHAR(255),
    email_confirmed_at TIMESTAMP WITH TIME ZONE,
    invited_at TIMESTAMP WITH TIME ZONE,
    confirmation_token VARCHAR(255),
    confirmation_sent_at TIMESTAMP WITH TIME ZONE,
    recovery_token VARCHAR(255),
    recovery_sent_at TIMESTAMP WITH TIME ZONE,
    email_change_token_new VARCHAR(255),
    email_change VARCHAR(255),
    email_change_sent_at TIMESTAMP WITH TIME ZONE,
    last_sign_in_at TIMESTAMP WITH TIME ZONE,
    raw_app_meta_data JSONB,
    raw_user_meta_data JSONB,
    is_super_admin BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    phone VARCHAR(15) UNIQUE,
    phone_confirmed_at TIMESTAMP WITH TIME ZONE,
    phone_change VARCHAR(15),
    phone_change_token VARCHAR(255),
    phone_change_sent_at TIMESTAMP WITH TIME ZONE,
    confirmed_at TIMESTAMP WITH TIME ZONE,
    email_change_token_current VARCHAR(255),
    email_change_confirm_status SMALLINT,
    banned_until TIMESTAMP WITH TIME ZONE,
    reauthentication_token VARCHAR(255),
    reauthentication_sent_at TIMESTAMP WITH TIME ZONE
);

-- 创建auth schema的其他必要表
CREATE TABLE IF NOT EXISTS auth.refresh_tokens (
    instance_id UUID,
    id BIGSERIAL PRIMARY KEY,
    token VARCHAR(255) UNIQUE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    parent VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auth.schema_migrations (
    version VARCHAR(255) PRIMARY KEY
);

-- 插入schema版本
INSERT INTO auth.schema_migrations (version) VALUES ('20211122151130') ON CONFLICT DO NOTHING;

-- 确保profiles表存在
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username VARCHAR(50) UNIQUE NOT NULL,
    display_name VARCHAR(100),
    age INTEGER CHECK (age >= 18 AND age <= 100),
    bio TEXT,
    avatar_url TEXT,
    location_lat FLOAT,
    location_lng FLOAT,
    interests TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 授权auth schema权限
GRANT ALL ON ALL TABLES IN SCHEMA auth TO supabase_auth_admin, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO supabase_auth_admin, service_role;

-- 创建supabase_auth_admin角色（如果不存在）
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    CREATE ROLE supabase_auth_admin NOLOGIN BYPASSRLS;
  END IF;
END $$;

GRANT ALL ON SCHEMA auth TO supabase_auth_admin;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO supabase_auth_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO supabase_auth_admin;
SQL

echo_info "4. 启动Auth服务..."
docker run -d \
  --name groupup-auth \
  --network groupup-network \
  -p 9999:9999 \
  -e GOTRUE_API_HOST=0.0.0.0 \
  -e GOTRUE_API_PORT=9999 \
  -e API_EXTERNAL_URL=http://${ECS_HOST}:8000 \
  -e GOTRUE_DB_DRIVER=postgres \
  -e "GOTRUE_DB_DATABASE_URL=postgres://postgres:${PG_PASSWORD}@groupup-postgres:5432/postgres?search_path=auth" \
  -e GOTRUE_SITE_URL=http://${ECS_HOST} \
  -e "GOTRUE_URI_ALLOW_LIST=http://${ECS_HOST},http://localhost:*" \
  -e GOTRUE_DISABLE_SIGNUP=false \
  -e GOTRUE_JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long \
  -e GOTRUE_JWT_EXP=3600 \
  -e GOTRUE_JWT_DEFAULT_GROUP_NAME=authenticated \
  -e GOTRUE_EXTERNAL_EMAIL_ENABLED=false \
  -e GOTRUE_MAILER_AUTOCONFIRM=true \
  -e GOTRUE_SMTP_ADMIN_EMAIL=admin@example.com \
  -e GOTRUE_SMTP_HOST= \
  -e GOTRUE_SMTP_PORT=587 \
  -e GOTRUE_SMTP_USER= \
  -e GOTRUE_SMTP_PASS= \
  --add-host=groupup-postgres:172.17.0.1 \
  supabase/gotrue:v2.132.3

echo_info "5. 等待Auth服务启动..."
sleep 10

echo_info "6. 检查Auth服务状态..."
docker logs groupup-auth --tail 20

echo_info "7. 启动PostgREST服务..."
docker run -d \
  --name groupup-rest \
  --network groupup-network \
  -p 3001:3000 \
  -e "PGRST_DB_URI=postgres://authenticator:supabase123@groupup-postgres:5432/postgres" \
  -e PGRST_DB_SCHEMAS=public,storage \
  -e PGRST_DB_ANON_ROLE=anon \
  -e PGRST_JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long \
  -e PGRST_DB_USE_LEGACY_GUCS=false \
  -e PGRST_APP_SETTINGS_JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long \
  --add-host=groupup-postgres:172.17.0.1 \
  postgrest/postgrest:v11.2.0

echo_info "8. 等待REST服务启动..."
sleep 10

echo_info "9. 更新Kong配置以正确路由..."
cat > /opt/groupup/kong.yml << 'KONG'
_format_version: "2.1"

services:
  - name: auth-v1
    url: http://172.17.0.1:9999
    routes:
      - name: auth-v1-all
        strip_path: true
        paths:
          - /auth/v1

  - name: rest-v1  
    url: http://172.17.0.1:3001
    routes:
      - name: rest-v1-all
        strip_path: true
        paths:
          - /rest/v1

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
        - prefer
        - x-client-info
      exposed_headers:
        - X-Auth-Token
        - apikey
      credentials: true
      max_age: 3600
KONG

echo_info "10. 重启Kong以应用新配置..."
docker restart groupup-kong

echo_info "11. 等待Kong重启..."
sleep 10

echo_info "12. 检查所有服务状态..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo_info "13. 测试API端点..."
echo -e "\n测试Auth健康检查:"
curl -s http://localhost:9999/health || echo "Auth服务可能还在启动"

echo -e "\n测试REST API:"
curl -s http://localhost:3001 || echo "REST API可能还在启动"

echo -e "\n测试Kong路由 - Auth:"
curl -s -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  http://localhost:8000/auth/v1/health || echo "Kong Auth路由可能还在配置"

echo -e "\n测试Kong路由 - REST:"
curl -s -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  http://localhost:8000/rest/v1/ || echo "Kong REST路由可能还在配置"

echo ""
echo_info "====================================="
echo_info "服务修复完成！"
echo_info "====================================="
echo_info "请在浏览器中访问："
echo_info "- Supabase Studio: http://${ECS_HOST}:3000"
echo_info "- Auth API: http://${ECS_HOST}:8000/auth/v1"
echo_info "- REST API: http://${ECS_HOST}:8000/rest/v1"
echo_info "====================================="
EOF

# 执行修复
echo "开始修复..."
sshpass -p "${ECS_PASSWORD}" scp -o StrictHostKeyChecking=no /tmp/fix_services.sh ${ECS_USER}@${ECS_HOST}:/tmp/
sshpass -p "${ECS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${ECS_USER}@${ECS_HOST} "cd /opt/groupup && bash /tmp/fix_services.sh"

# 清理
rm -f /tmp/fix_services.sh

echo ""
echo "修复脚本执行完成！"