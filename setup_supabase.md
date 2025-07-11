# Supabase 设置指南

## 1. 数据库设置

请在 Supabase Dashboard 的 SQL Editor 中运行以下脚本：

### 步骤 1: 运行主要的数据库架构
1. 访问: https://supabase.com/dashboard/project/awuojdpmhqsbnlpydmek/sql/new
2. 复制并运行 `supabase_schema.sql` 文件的内容

### 步骤 2: 创建存储桶
1. 在 SQL Editor 中运行 `create_storage_bucket.sql`

### 步骤 3: 设置 RLS 策略
1. 运行 `fix_rls_policies.sql`
2. 运行 `secure_storage_policies.sql`

### 步骤 4: 创建测试用户（可选）
1. 运行 `simple_test_users.sql` 创建测试用户

## 2. 环境配置

项目已配置以下环境变量：
- SUPABASE_URL: https://awuojdpmhqsbnlpydmek.supabase.co
- SUPABASE_ANON_KEY: 已在 `.env.local` 中配置

## 3. 验证设置

运行以下命令测试连接：
```bash
npm start
```

然后选择 "Skip Login (Test Mode)" 进行测试。

## 4. 注意事项

- 确保在 Supabase Dashboard 中启用了 Email Auth
- 检查 Storage 设置中的 avatars bucket 是否为 public
- 如需使用真实登录，请在 Authentication 设置中配置邮箱验证