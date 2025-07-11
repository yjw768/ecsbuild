#!/bin/bash

# 检查各个组件的最新版本
echo "🔍 正在查询最新版本..."
echo ""

# PostgreSQL
echo "📦 PostgreSQL:"
echo "官方网站: https://www.postgresql.org/"
echo "最新稳定版: 16.1 (2023年11月发布)"
echo "Supabase使用: 15.x (为了稳定性)"
echo ""

# Supabase组件
echo "📦 Supabase组件版本:"
echo "查看地址: https://github.com/supabase/supabase/releases"
echo "- Studio: https://github.com/supabase/supabase/tree/master/studio"
echo "- GoTrue: https://github.com/supabase/gotrue/releases"
echo "- PostgREST: https://github.com/PostgREST/postgrest/releases"
echo "- Realtime: https://github.com/supabase/realtime/releases"
echo "- Storage: https://github.com/supabase/storage-api/releases"
echo "- Kong: https://github.com/Kong/kong/releases"
echo ""

# 获取实际最新版本
echo "🔄 获取GitHub最新发布版本..."
echo ""

# 检查Supabase最新版本
SUPABASE_VERSION=$(curl -s https://api.github.com/repos/supabase/supabase/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
echo "Supabase最新版本: $SUPABASE_VERSION"

# 检查PostgREST最新版本
POSTGREST_VERSION=$(curl -s https://api.github.com/repos/PostgREST/postgrest/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
echo "PostgREST最新版本: $POSTGREST_VERSION"

# 检查Kong最新版本
KONG_VERSION=$(curl -s https://api.github.com/repos/Kong/kong/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
echo "Kong最新版本: $KONG_VERSION"

echo ""
echo "📝 建议使用Supabase官方docker-compose.yml:"
echo "https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml"
echo ""
echo "这个文件总是包含最新稳定版本的配置。"