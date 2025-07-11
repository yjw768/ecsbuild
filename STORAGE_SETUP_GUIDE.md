# Supabase Storage 设置指南

## 📚 官方文档链接

### 主要文档
- **Storage 概览**: https://supabase.com/docs/guides/storage
- **文件上传**: https://supabase.com/docs/guides/storage/uploads  
- **安全策略**: https://supabase.com/docs/guides/storage/security
- **JavaScript SDK**: https://supabase.com/docs/reference/javascript/storage-from-upload

### React Native 相关
- **Expo 集成**: https://supabase.com/docs/guides/getting-started/tutorials/with-expo-react-native
- **移动端最佳实践**: https://supabase.com/docs/guides/storage/uploads#uploading-files

## 🛠️ 设置步骤

### 1. 创建 Storage Bucket

在 Supabase Dashboard 中：

1. 访问你的项目: https://supabase.com/dashboard/project/awuojdpmhqsbnlpydmek
2. 左侧菜单点击 "Storage"
3. 点击 "Create bucket"
4. 设置以下参数：
   ```
   Bucket name: avatars
   ✅ Public bucket (勾选)
   File size limit: 5MB (5242880 bytes)
   Allowed MIME types: image/jpeg,image/png,image/gif,image/webp
   ```
5. 点击 "Create bucket"

### 2. 设置 RLS 策略

在 SQL Editor 中运行以下脚本:

```sql
-- 创建 avatars bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars', 
  'avatars', 
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp'];

-- 删除现有策略
DROP POLICY IF EXISTS "Users can upload avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users can view avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own avatars" ON storage.objects;

-- 创建新的 RLS 策略
CREATE POLICY "Users can upload avatars" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'avatars' AND 
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can view avatars" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'avatars');

CREATE POLICY "Users can delete own avatars" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'avatars' AND 
  (storage.foldername(name))[1] = auth.uid()::text
);

-- 启用 RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
```

### 3. 验证设置

在应用中使用调试功能：

1. 登录应用（非测试模式）
2. 进入 Profile 页面
3. 点击 "Debug Storage" 按钮
4. 查看控制台输出

期望的输出应该包括：
- ✅ 用户已认证
- ✅ avatars bucket 存在且为 public
- ✅ 可以列出文件
- ✅ 测试上传成功

## 🔧 常见问题解决

### 问题 1: "Bucket not found"
**解决方案**: 
- 确保在 Supabase Dashboard 中创建了 `avatars` bucket
- 检查 bucket 名称拼写正确

### 问题 2: "Permission denied" / RLS 错误
**解决方案**:
- 运行上面的 RLS 策略 SQL 脚本
- 确保用户已登录（`auth.uid()` 不为空）
- 检查文件路径格式：应该是 `{userId}/{filename}`

### 问题 3: "Invalid file format"
**解决方案**:
- 确保上传的是支持的图片格式
- 检查 `allowed_mime_types` 设置

### 问题 4: 文件上传成功但无法显示
**解决方案**:
- 检查 bucket 是否设置为 public
- 验证生成的 public URL 是否正确
- 检查网络连接

## 📱 测试步骤

1. **基础功能测试**:
   - 点击 "Debug Storage" - 应该显示所有检查通过
   - 上传照片 - 应该显示成功消息
   - 照片应该立即在 profile 中显示

2. **高级功能测试**:
   - 删除照片 - 应该从界面和存储中删除
   - 上传多张照片 - 应该都能成功显示
   - 退出重新登录 - 照片应该依然存在

## 🌐 在线检查工具

访问以下 URL 检查你的设置：
- Storage 概览: https://supabase.com/dashboard/project/awuojdpmhqsbnlpydmek/storage
- 策略设置: https://supabase.com/dashboard/project/awuojdpmhqsbnlpydmek/auth/policies
- SQL Editor: https://supabase.com/dashboard/project/awuojdpmhqsbnlpydmek/sql

如果仍有问题，请：
1. 运行调试功能并提供控制台输出
2. 检查 Supabase Dashboard 中的 Storage 设置
3. 确认 RLS 策略已正确应用