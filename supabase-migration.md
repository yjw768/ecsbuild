# Supabase 迁移指南

## 🚀 迁移步骤

### 1. 准备新的 Supabase 项目
在新的 Claude 对话中部署 Supabase 后，获取以下信息：
- **项目 URL**: `https://your-project-id.supabase.co`
- **匿名密钥**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
- **服务角色密钥**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (仅用于数据迁移)

### 2. 更新配置文件
修改 `src/services/supabase.ts`:

```typescript
// 新的 Supabase 配置
const SUPABASE_URL = 'https://your-new-project-id.supabase.co';
const SUPABASE_ANON_KEY = 'your-new-anon-key';
```

### 3. 数据库模式迁移
在新项目中执行以下 SQL 文件：
- `supabase_schema.sql` - 基本表结构
- `create_storage_bucket.sql` - 存储桶配置
- `final_storage_policies.sql` - 存储权限策略

### 4. 数据迁移（可选）
如果需要迁移现有数据：

#### 4.1 导出现有数据
```bash
# 使用 pg_dump 导出数据
pg_dump "postgresql://postgres:password@db.awuojdpmhqsbnlpydmek.supabase.co:5432/postgres" \
  --data-only \
  --table=profiles \
  --table=matches \
  --table=messages \
  --table=swipe_actions \
  > data_export.sql
```

#### 4.2 导入到新项目
```bash
# 导入数据到新项目
psql "postgresql://postgres:password@db.your-new-project-id.supabase.co:5432/postgres" \
  -f data_export.sql
```

### 5. 存储迁移
如果有用户上传的照片需要迁移：

#### 5.1 下载现有照片
```bash
# 使用 Supabase CLI 下载
supabase storage download --project-ref awuojdpmhqsbnlpydmek avatars ./photos_backup
```

#### 5.2 上传到新项目
```bash
# 上传到新项目
supabase storage upload --project-ref your-new-project-id avatars ./photos_backup
```

### 6. 环境变量更新
如果使用环境变量，更新 `.env` 文件：
```env
SUPABASE_URL=https://your-new-project-id.supabase.co
SUPABASE_ANON_KEY=your-new-anon-key
```

### 7. 测试迁移
1. 运行应用
2. 测试用户注册/登录
3. 测试照片上传
4. 测试匹配功能
5. 测试聊天功能

## 🔄 快速替换方法

### 方法1: 只更新配置（推荐）
如果只是想使用新的 Supabase 项目，最简单的方法：

1. 更新 `src/services/supabase.ts` 中的 URL 和密钥
2. 在新项目中运行数据库迁移 SQL
3. 重新启动应用

### 方法2: 使用环境变量
创建 `.env` 文件来管理配置：

```typescript
// src/services/supabase.ts
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://your-default-project.supabase.co';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || 'your-default-key';
```

## ⚠️ 注意事项

1. **数据备份**: 迁移前务必备份现有数据
2. **测试环境**: 先在测试环境验证迁移
3. **用户通知**: 如果有现有用户，需要通知他们重新登录
4. **存储URL**: 照片URL会改变，需要更新profile中的照片链接
5. **API限制**: 新项目可能有不同的API限制

## 🎯 迁移后验证清单

- [ ] 用户注册功能正常
- [ ] 用户登录功能正常  
- [ ] 照片上传功能正常
- [ ] 用户资料更新正常
- [ ] 滑动匹配功能正常
- [ ] 聊天功能正常
- [ ] 存储权限策略正确
- [ ] 所有 SQL 策略已应用

## 📞 如果遇到问题

1. 检查 Supabase 项目控制台的日志
2. 检查应用的控制台日志
3. 使用 `Debug Storage` 按钮检查存储配置
4. 使用 `Test Photo Upload` 按钮测试上传功能