#!/bin/bash

# ECS诊断脚本
ECS_HOST="8.148.211.17"
ECS_USER="root"
ECS_PASSWORD="Yjw202202@"

echo "=== GroupUp ECS 诊断报告 ==="
echo "时间: $(date)"
echo ""

# SSH连接函数
ssh_exec() {
    sshpass -p "${ECS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${ECS_USER}@${ECS_HOST} "$1"
}

echo "1. 检查Docker服务状态:"
ssh_exec "docker --version && docker-compose --version"
echo ""

echo "2. 检查运行中的容器:"
ssh_exec "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
echo ""

echo "3. 检查所有容器（包括停止的）:"
ssh_exec "docker ps -a --format 'table {{.Names}}\t{{.Status}}' | grep groupup"
echo ""

echo "4. 检查Auth服务错误日志:"
ssh_exec "docker logs groupup-auth 2>&1 | tail -10"
echo ""

echo "5. 检查环境变量配置:"
ssh_exec "cd /opt/groupup && [ -f .env ] && echo '.env文件存在' || echo '.env文件不存在'"
echo ""

echo "6. 检查网络端口监听:"
ssh_exec "netstat -tlnp | grep -E ':(80|3000|8000|5432)'"
echo ""

echo "7. 重新启动服务:"
read -p "是否要重新启动所有服务？(y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "停止所有服务..."
    ssh_exec "cd /opt/groupup && docker-compose down"
    
    echo "启动所有服务..."
    ssh_exec "cd /opt/groupup && docker-compose up -d"
    
    echo "等待服务启动..."
    sleep 20
    
    echo "检查新的服务状态:"
    ssh_exec "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
fi

echo ""
echo "=== 诊断完成 ==="