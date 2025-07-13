#!/bin/bash

# GroupUp 最新版本部署脚本
# 更新时间: 2024-07-12

echo "🚀 GroupUp 最新版本部署脚本"
echo "================================"
echo ""

# 检查是否在正确目录
if [ ! -f ".env" ]; then
    echo "❌ 错误: 请在包含 .env 文件的目录中运行此脚本"
    exit 1
fi

echo "📥 下载最新的Supabase官方docker-compose.yml..."
echo "来源: https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml"
echo ""

# 备份现有文件
if [ -f "docker-compose.yml" ]; then
    cp docker-compose.yml docker-compose.yml.backup
    echo "✅ 已备份现有配置到 docker-compose.yml.backup"
fi

# 下载最新版本
wget -O docker-compose.yml https://raw.githubusercontent.com/supabase/supabase/master/docker/docker-compose.yml

if [ $? -ne 0 ]; then
    echo "❌ 下载失败，尝试使用备用地址..."
    curl -o docker-compose.yml https://raw.githubusercontent.com/supabase/supabase/master/docker/docker-compose.yml
fi

echo ""
echo "📋 当前使用的版本信息："
echo "========================"
grep -E "image:|version:" docker-compose.yml | head -20

echo ""
echo "🔧 配置Docker使用国内镜像加速..."
# 为中国用户优化
if [ -f "/etc/docker/daemon.json" ]; then
    echo "Docker已配置镜像加速"
else
    sudo tee /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://docker.mirrors.ustc.edu.cn"
  ]
}
EOF
    sudo systemctl restart docker
fi

echo ""
echo "🚀 开始部署..."
echo "1. 拉取最新镜像"
docker compose pull

echo ""
echo "2. 停止旧容器（如果存在）"
docker compose down

echo ""
echo "3. 启动新容器"
docker compose up -d

echo ""
echo "4. 检查状态"
sleep 5
docker compose ps

echo ""
echo "✅ 部署完成！"
echo ""
echo "访问地址："
echo "- API: http://$(curl -s ifconfig.me):8000"
echo "- Studio: http://$(curl -s ifconfig.me):3000"
echo ""
echo "查看日志: docker compose logs -f"