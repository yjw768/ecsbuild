# 🚀 GroupUp 自动化部署指南

## 📋 当前部署进度

✅ **已完成**:
- [x] 服务器初始化 (Ubuntu 22.04)
- [x] Docker 和 Docker Compose 安装
- [x] 防火墙配置 (端口 22, 80, 443, 3000, 8000)
- [x] 项目目录创建 (/opt/groupup)
- [x] 环境变量配置 (.env)
- [x] 阿里云 OSS 集成配置
- [x] GitHub 仓库克隆

🔄 **进行中**:
- [ ] Supabase 服务启动
- [ ] 数据库初始化
- [ ] 服务验证测试

## 🎯 自动化部署命令

### 方案1: 一键完整部署
```bash
cd /opt/groupup
wget https://raw.githubusercontent.com/yjw768/ecsbuild/main/auto_deploy.sh
chmod +x auto_deploy.sh
./auto_deploy.sh
```

### 方案2: 分步部署 (推荐)
```bash
# 1. 基础服务部署
wget https://raw.githubusercontent.com/yjw768/ecsbuild/main/deploy_basic.sh
chmod +x deploy_basic.sh
./deploy_basic.sh

# 2. 完整 Supabase 部署
wget https://raw.githubusercontent.com/yjw768/ecsbuild/main/deploy_supabase.sh
chmod +x deploy_supabase.sh
./deploy_supabase.sh
```

## 📊 服务器信息

- **公网IP**: 8.148.211.17
- **配置**: 2核4GB
- **操作系统**: Ubuntu 22.04
- **Docker版本**: 最新稳定版

## 🔧 环境变量检查

确保 `/opt/groupup/.env` 文件包含以下配置:
```bash
# 基础配置
POSTGRES_PASSWORD=UGMx6F07pPkLI78+QNui7kdMSp4VFKT5rpS79YZCSo8=
JWT_SECRET=Rs+0G6t0kEinJU/TPQIc2EIgzAoMwyrwvTgcGyjh2tU=
SITE_URL=http://8.148.211.17:8000

# OSS 配置
OSS_ENDPOINT=oss-cn-guangzhou.aliyuncs.com
OSS_BUCKET=groupup
OSS_REGION=cn-guangzhou
```

## 🌐 访问地址

部署完成后，服务将在以下地址运行:
- **API 网关**: http://8.148.211.17:8000
- **Supabase Studio**: http://8.148.211.17:3000
- **数据库**: 172.21.110.72:5432 (内网)

## 🚨 故障排除

### Docker 镜像拉取失败
```bash
# 配置国内镜像加速
sudo tee /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ]
}
EOF
sudo systemctl restart docker
```

### 服务启动失败
```bash
# 查看日志
docker compose logs -f

# 检查服务状态
docker compose ps

# 重启服务
docker compose restart
```

## 📞 获取帮助

如果部署遇到问题:
1. 查看 `docker compose logs` 输出
2. 检查端口是否被占用: `netstat -tulpn | grep -E "8000|3000|5432"`
3. 确认防火墙规则: `sudo ufw status`
4. 在 GitHub Issues 中报告问题

## ⚡ 快速命令参考

```bash
# 查看运行状态
docker compose ps

# 查看日志
docker compose logs -f

# 重启所有服务
docker compose restart

# 停止所有服务
docker compose down

# 更新服务
git pull && docker compose up -d

# 数据库连接测试
docker compose exec db psql -U postgres -c "SELECT version();"
```

---

**最后更新**: 2024-07-12  
**维护者**: Claude + yjw768