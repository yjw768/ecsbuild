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
