# GroupUp ECS 部署脚本

## 🚀 快速部署

一键部署GroupUp到阿里云ECS服务器的完整脚本和配置文件。

**✨ 新增功能：完整的迁移和备份系统！**

### 📋 支持的配置

- **2核2GB** (轻量版) - 适合测试环境
- **2核4GB** (推荐) - 适合1000-2000用户
- **4核8GB** (生产版) - 适合5000+用户

### 🛠️ 部署方式

#### 方式一：标准部署（原有功能）
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

#### 方式二：完整自托管部署（新增）
使用我们改进的自托管Supabase方案：

```bash
# 1. 克隆项目
git clone https://github.com/yjw768/ecsbuild.git
cd ecsbuild

# 2. 执行完整部署
./complete_supabase_setup.sh

# 3. 健康检查
./test-api-connection.js
```

### 🔄 主机迁移（新功能）

现在支持一键备份和迁移：

```bash
# 1. 备份当前部署
./backup_current_deployment.sh

# 2. 迁移到新主机
cd backup-folder
./deploy_to_new_host.sh 新主机IP 用户名 密码

# 3. 验证部署
./quick_health_check.sh 新主机IP
```

### 📁 文件说明

#### 基础部署文件
| 文件 | 说明 |
|------|------|
| `server_setup.sh` | 服务器初始化脚本 |
| `docker-compose.yml` | 2核4GB标准配置 |
| `docker-compose.lite.yml` | 2核2GB轻量配置 |
| `docker-compose.production.yml` | 4核8GB生产配置 |
| `init_database.sql` | 数据库初始化脚本 |

#### 新增部署和迁移工具
| 文件 | 说明 |
|------|------|
| `complete_supabase_setup.sh` | 完整自托管Supabase部署脚本 |
| `backup_current_deployment.sh` | 一键备份当前部署 |
| `diagnose_ecs.sh` | 系统诊断工具 |
| `fix_auth_and_rest.sh` | Auth和REST服务修复工具 |
| `create_minimal_api.sh` | 创建最小API服务 |
| `test-api-connection.js` | API连接测试工具 |
| `apiService.ts` | TypeScript API服务客户端 |
| `deployment-template/` | 完整部署模板目录 |

#### 文档指南
| 文件 | 说明 |
|------|------|
| `MIGRATION_GUIDE.md` | 详细的迁移指南 |
| `MIGRATION_BEST_PRACTICES.md` | 迁移最佳实践 |

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