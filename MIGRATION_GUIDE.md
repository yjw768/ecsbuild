# GroupUp 主机迁移指南

## 🚨 我们遇到的主要问题回顾

### 部署过程中的挑战：
1. **Docker Compose版本兼容性问题** - 段错误
2. **Auth服务数据库连接失败** - 密码和schema问题  
3. **环境变量配置错误** - API_EXTERNAL_URL缺失
4. **网络连接问题** - 容器间通信失败
5. **镜像下载超时** - 网络限制
6. **数据库迁移失败** - 缺少必要的表结构

## 📦 完整迁移包

### 1. 备份脚本
```bash
#!/bin/bash
# backup.sh - 备份所有数据和配置

echo "=== GroupUp 数据备份 ==="

# 创建备份目录
BACKUP_DIR="groupup-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR

# 备份数据库
echo "备份数据库..."
docker exec groupup-postgres pg_dump -U postgres postgres > $BACKUP_DIR/database.sql

# 备份配置文件
echo "备份配置文件..."
cp /opt/groupup/.env $BACKUP_DIR/
cp /opt/groupup/kong.yml $BACKUP_DIR/
cp /opt/groupup/docker-compose.yml $BACKUP_DIR/
cp /opt/groupup/simple-api.js $BACKUP_DIR/
cp /opt/groupup/package.json $BACKUP_DIR/
cp /opt/groupup/Dockerfile $BACKUP_DIR/

# 备份存储文件（如果有）
if [ -d "/opt/groupup/storage" ]; then
    echo "备份存储文件..."
    cp -r /opt/groupup/storage $BACKUP_DIR/
fi

# 压缩备份
tar -czf $BACKUP_DIR.tar.gz $BACKUP_DIR
rm -rf $BACKUP_DIR

echo "备份完成: $BACKUP_DIR.tar.gz"
```

### 2. 一键部署脚本（改进版）
```bash
#!/bin/bash
# deploy-new-host.sh - 新主机一键部署

set -e

# 配置
NEW_HOST_IP="新主机IP"
SSH_USER="root"
SSH_PASSWORD="密码"

echo "=== GroupUp 新主机部署 ==="

# 1. 上传部署包
echo "上传部署文件..."
sshpass -p "$SSH_PASSWORD" scp -r ./deployment-package $SSH_USER@$NEW_HOST_IP:/opt/

# 2. 执行远程部署
sshpass -p "$SSH_PASSWORD" ssh $SSH_USER@$NEW_HOST_IP << 'EOF'
cd /opt/deployment-package

# 更新系统
apt-get update -y
apt-get install -y docker.io curl wget

# 安装Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 启动Docker
systemctl start docker
systemctl enable docker

# 创建工作目录
mkdir -p /opt/groupup
cp -r * /opt/groupup/
cd /opt/groupup

# 更新IP配置
sed -i "s/8\.148\.211\.17/$NEW_HOST_IP/g" .env
sed -i "s/8\.148\.211\.17/$NEW_HOST_IP/g" kong.yml
sed -i "s/8\.148\.211\.17/$NEW_HOST_IP/g" simple-api.js

# 启动服务
docker network create groupup-network 2>/dev/null || true

# 启动PostgreSQL
docker run -d --name groupup-postgres \
  --network groupup-network \
  -e POSTGRES_PASSWORD=groupup2024 \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=postgres \
  -p 5432:5432 \
  postgres:15-alpine

# 等待数据库启动
sleep 20

# 恢复数据库
if [ -f database.sql ]; then
    docker exec -i groupup-postgres psql -U postgres < database.sql
fi

# 构建并启动API
docker build -t groupup-api .
docker run -d --name groupup-api \
  --network groupup-network \
  -p 3001:3001 \
  --add-host=groupup-postgres:172.17.0.1 \
  groupup-api

# 启动Kong
docker run -d --name groupup-kong \
  --network groupup-network \
  -p 8000:8000 -p 8443:8443 \
  -e KONG_DATABASE=off \
  -e KONG_DECLARATIVE_CONFIG=/home/kong/kong.yml \
  -v /opt/groupup/kong.yml:/home/kong/kong.yml \
  kong:2.8.1

# 启动Studio
docker run -d --name groupup-studio \
  --network groupup-network \
  -p 3000:3000 \
  -e SUPABASE_URL=http://$NEW_HOST_IP:8000 \
  -e POSTGRES_PASSWORD=groupup2024 \
  supabase/studio:latest

echo "部署完成！"
echo "访问地址："
echo "- API: http://$NEW_HOST_IP:8000/api/v1"
echo "- Studio: http://$NEW_HOST_IP:3000"
EOF

echo "新主机部署完成！"
```

### 3. 部署包结构
```
deployment-package/
├── .env                    # 环境变量配置
├── kong.yml               # Kong API网关配置
├── docker-compose.yml     # Docker编排文件
├── simple-api.js          # API服务代码
├── package.json           # Node.js依赖
├── Dockerfile             # API镜像构建
├── database.sql           # 数据库备份
├── deploy.sh              # 部署脚本
└── README.md              # 部署说明
```

## 🔄 迁移步骤

### 准备阶段
1. **在旧主机上运行备份脚本**
   ```bash
   ./backup.sh
   ```

2. **下载备份文件到本地**
   ```bash
   scp root@8.148.211.17:/opt/groupup/groupup-backup-*.tar.gz ./
   ```

3. **解压并准备部署包**
   ```bash
   tar -xzf groupup-backup-*.tar.gz
   # 整理成deployment-package目录
   ```

### 迁移阶段
1. **准备新主机**
   - 开通新的ECS实例
   - 配置安全组（开放端口：22, 80, 3000, 3001, 5432, 8000）

2. **运行一键部署**
   ```bash
   ./deploy-new-host.sh
   ```

3. **更新DNS/应用配置**
   - 更新你的React Native应用中的API地址
   - 测试所有功能

### 验证阶段
1. **健康检查**
   ```bash
   curl http://新主机IP:8000/api/v1/health
   curl http://新主机IP:8000/api/v1/users
   ```

2. **功能测试**
   - 访问Studio: http://新主机IP:3000
   - 测试API各个端点
   - 验证数据完整性

## 🛠 故障排除手册

### 常见问题及解决方案

1. **Docker Compose段错误**
   ```bash
   # 重新下载Docker Compose
   curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   chmod +x /usr/local/bin/docker-compose
   ```

2. **容器启动失败**
   ```bash
   # 检查日志
   docker logs 容器名称
   
   # 重启容器
   docker restart 容器名称
   ```

3. **数据库连接失败**
   ```bash
   # 检查密码
   docker exec groupup-postgres printenv POSTGRES_PASSWORD
   
   # 测试连接
   docker exec -it groupup-postgres psql -U postgres
   ```

4. **网络问题**
   ```bash
   # 重建网络
   docker network rm groupup-network
   docker network create groupup-network
   
   # 重新启动所有容器
   ```

## 📋 检查清单

### 迁移前检查
- [ ] 备份完成
- [ ] 新主机准备就绪
- [ ] 安全组配置正确
- [ ] 部署脚本已更新IP地址

### 迁移后检查
- [ ] 所有容器运行正常
- [ ] API健康检查通过
- [ ] Studio可以访问
- [ ] 数据库数据完整
- [ ] React Native应用连接正常

## 💡 优化建议

### 为了简化未来迁移：

1. **使用Docker Compose**
   - 虽然遇到了问题，但修复后会更稳定
   - 统一管理所有服务

2. **环境变量外部化**
   - 所有IP地址使用环境变量
   - 配置文件模板化

3. **自动化脚本**
   - 一键备份
   - 一键部署
   - 一键恢复

4. **监控告警**
   - 服务健康检查
   - 磁盘空间监控
   - 性能监控

记住：虽然第一次部署很复杂，但有了这套完整的迁移方案，下次迁移就会变得非常简单！🚀