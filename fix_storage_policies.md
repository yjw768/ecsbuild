# 🔧 修复 Storage 上传问题

根据错误信息 "new row violates row-level security policy"，说明 Storage RLS 策略阻止了上传。

## 快速解决方案（选择其一）：

### 方案 1：暂时禁用 RLS（最快）
1. 在 Supabase Dashboard 中
2. 进入 **Storage** → **Policies**
3. 右上角找到 **"RLS enabled"** 开关
4. 点击关闭（变成 "RLS disabled"）
5. 测试上传功能
6. 测试完成后记得重新启用

### 方案 2：创建正确的策略
在 SQL Editor 中运行：

```sql
-- 1. 删除可能存在的旧策略
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Avatar images are publicly accessible" ON storage.objects;

-- 2. 创建新的宽松策略（用于测试）
-- 允许所有认证用户上传
CREATE POLICY "Allow authenticated uploads" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'avatars');

-- 允许所有认证用户更新
CREATE POLICY "Allow authenticated updates" ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id = 'avatars');

-- 允许所有人查看
CREATE POLICY "Allow public viewing" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'avatars');

-- 允许认证用户删除自己的文件
CREATE POLICY "Allow users to delete own files" ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
```

### 方案 3：使用 Service Role Key（绕过 RLS）
1. 在 Dashboard → Settings → API
2. 复制 **service_role** key（不是 anon key）
3. 在代码中使用：

```javascript
// 注意：service_role key 有完全权限，仅在服务器端使用！
const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
```

## 创建测试用户

由于网络问题，在 Dashboard 中手动创建用户：

1. Authentication → Users
2. 点击 **"Add user"** → **"Create new user"**
3. 填写：
   - Email: `test@example.com`
   - Password: `test123456`
   - 勾选 "Auto Confirm User"
4. 点击 "Create User"

## 测试代码（使用已创建的用户）：

```javascript
// 登录测试用户
const { data: { user }, error } = await supabase.auth.signInWithPassword({
  email: 'test@example.com',
  password: 'test123456'
});

if (user) {
  // 上传照片
  const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
  const { data, error } = await supabase.storage
    .from('avatars')
    .upload(`${user.id}/avatar.jpg`, file);
}
```

## 检查项目状态

确保你的 Supabase 项目是活跃的：
- 免费版项目 7 天不活动会自动暂停
- 如果暂停了，在 Dashboard 中点击 "Restore project"

## 推荐步骤：

1. **先禁用 RLS** 测试基本功能是否正常
2. **创建测试用户** 在 Dashboard 中手动创建
3. **测试上传** 确认可以上传后
4. **重新启用 RLS** 并设置正确的策略

这样可以快速定位问题是在 RLS 策略还是其他地方。