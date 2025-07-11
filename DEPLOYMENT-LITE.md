# GroupUp 轻量级部署指南 (2核2G)

## 优化说明

针对2核2G的服务器，我们做了以下优化：

### 1. 移除的服务
- **Supabase Studio** - 管理界面（可通过SQL直接管理）
- **Kong API Gateway** - 使用Nginx直接代理
- **Realtime** - 实时通信（可后期按需添加）
- **图片处理服务** - 节省内存

### 2. 内存优化
- PostgreSQL: 限制到512MB
- 每个服务: 限制到256MB
- Nginx: 限制到128MB
- 总内存使用: 约1.5GB

### 3. 性能优化
- 启用Gzip压缩
- Nginx缓存
- 连接池优化
- Swap空间

## 部署步骤

### 1. 准备服务器
```bash
# 最低配置
- CPU: 2核
- 内存: 2GB
- 存储: 20GB
- 系统: Ubuntu 20.04+
```

### 2. 运行轻量级部署
```bash
./deploy-lite.sh
```

### 3. 后续优化

#### 添加CDN
```nginx
# 在nginx.conf中添加
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 30d;
    add_header Cache-Control "public, immutable";
}
```

#### 添加Redis缓存
```yaml
# 在docker-compose.yml中添加
redis:
  image: redis:alpine
  container_name: groupup-redis
  restart: unless-stopped
  command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
  deploy:
    resources:
      limits:
        memory: 256M
```

## 监控建议

### 1. 资源监控
```bash
# 监控内存使用
docker stats

# 查看系统资源
htop

# 检查磁盘空间
df -h
```

### 2. 日志管理
```bash
# 限制日志大小
docker-compose logs --tail=100

# 清理老日志
find /var/lib/docker/containers -name "*.log" -size +100M -delete
```

## 扩展方案

当业务增长时，可以：

### 1. 垂直扩展
- 升级到4核4G
- 添加更多服务

### 2. 水平扩展
```yaml
# 使用Docker Swarm
docker swarm init
docker service create --replicas 3 groupup-api
```

### 3. 分离服务
- 数据库独立服务器
- 静态资源使用OSS
- API使用负载均衡

## 故障处理

### 内存不足
```bash
# 检查内存使用
free -m

# 重启占用高的服务
docker-compose restart postgres

# 清理缓存
sync && echo 3 > /proc/sys/vm/drop_caches
```

### 响应缓慢
```bash
# 检查慢查询
docker-compose exec postgres psql -U postgres -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"

# 优化索引
docker-compose exec postgres psql -U postgres -d postgres -f optimize_indexes.sql
```

## 备份策略

### 自动备份脚本
```bash
#!/bin/bash
# backup.sh
DATE=$(date +%Y%m%d_%H%M%S)
docker-compose exec postgres pg_dump -U postgres postgres | gzip > backup_$DATE.sql.gz

# 保留最近7天的备份
find . -name "backup_*.sql.gz" -mtime +7 -delete
```

### 恢复数据
```bash
gunzip < backup_20240101_120000.sql.gz | docker-compose exec -T postgres psql -U postgres postgres
```

## 安全建议

1. **使用防火墙**
```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

2. **定期更新**
```bash
apt update && apt upgrade -y
docker-compose pull
docker-compose up -d
```

3. **监控异常**
```bash
# 安装fail2ban
apt install fail2ban -y
```

## 性能基准

在2核2G配置下的预期性能：
- 并发用户: 100-200
- QPS: 500-1000
- 响应时间: <200ms
- 日活用户: 1000-5000

超过此范围建议升级配置。