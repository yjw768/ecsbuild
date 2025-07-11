# GroupUp ECS 部署脚本

## 🚀 快速部署

一键部署GroupUp到阿里云ECS服务器的完整脚本和配置文件。

### 📋 支持的配置

- **2核2GB** (轻量版) - 适合测试环境
- **2核4GB** (推荐) - 适合1000-2000用户
- **4核8GB** (生产版) - 适合5000+用户

### 🛠️ 部署步骤

1. **服务器初始化**
   ```bash
   wget https://raw.githubusercontent.com/yjw768/ecsbuild/main/server_setup.sh
   chmod +x server_setup.sh
   ./server_setup.sh
   ```

2. **下载配置文件**
   ```bash
   git clone https://github.com/yjw768/ecsbuild.git
   cd ecsbuild
   ```

3. **选择配置并启动**
   ```bash
   # 2核4GB配置（推荐）
   docker-compose up -d
   
   # 或轻量版
   docker-compose -f docker-compose.lite.yml up -d
   
   # 或生产版
   docker-compose -f docker-compose.production.yml up -d
   ```

### 📁 文件说明

| 文件 | 说明 |
|------|------|
| `server_setup.sh` | 服务器初始化脚本 |
| `docker-compose.yml` | 2核4GB标准配置 |
| `docker-compose.lite.yml` | 2核2GB轻量配置 |
| `docker-compose.production.yml` | 4核8GB生产配置 |
| `init_database.sql` | 数据库初始化脚本 |

### 📚 文档指南

- [管理后台功能指南](ADMIN_FEATURES_GUIDE.md)
- [照片审核实现指南](PHOTO_REVIEW_GUIDE.md)
- [免费推送和统计方案](FREE_PUSH_ANALYTICS_GUIDE.md)
- [CDN头像加速指南](CDN_AVATAR_GUIDE.md)
- [购买需求指南](PURCHASE_GUIDE.md)

### 💰 成本预算

**2核4GB配置（推荐）:**
- ECS: ¥114/月
- OSS: ¥10/月
- 带宽: ¥20-30/月
- **总计: ~¥130/月**

### 🔧 技术栈

- **前端**: React Native + Expo + TypeScript
- **后端**: Supabase (自托管)
- **数据库**: PostgreSQL
- **存储**: 阿里云OSS
- **容器**: Docker + Docker Compose
- **反向代理**: Nginx

### 📞 支持

遇到问题请查看相关文档或提交Issue。

---

🤖 Generated with [Claude Code](https://claude.ai/code)