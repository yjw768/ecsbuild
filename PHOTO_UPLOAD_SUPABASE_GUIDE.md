# 📸 Supabase 照片上传和实时消息配置指南

## 1. 照片上传配置

### Step 1: 在 Supabase 创建 Storage Bucket

1. 登录 Supabase Dashboard
2. 进入你的项目
3. 左侧菜单选择 **Storage**
4. 点击 **New bucket** 创建存储桶：
   ```
   名称: avatars
   Public bucket: ✅ (勾选，使照片可公开访问)
   ```

### Step 2: 配置 Bucket 策略

在 SQL Editor 中运行以下命令：

```sql
-- 1. 允许用户上传自己的照片
CREATE POLICY "Users can upload their own avatar" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- 2. 允许用户更新自己的照片
CREATE POLICY "Users can update their own avatar" ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- 3. 允许用户删除自己的照片
CREATE POLICY "Users can delete their own avatar" ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- 4. 允许所有人查看照片（因为是 public bucket）
CREATE POLICY "Avatar images are publicly accessible" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'avatars');
```

### Step 3: 修复上传代码

在 `src/services/supabase.ts` 中确保上传函数正确：

```typescript
async uploadImage(uri: string, userId: string): Promise<string> {
  try {
    // 1. 获取文件扩展名
    const ext = uri.split('.').pop() || 'jpg';
    const fileName = `${userId}/${Date.now()}.${ext}`;
    
    // 2. 将图片转换为 blob
    const response = await fetch(uri);
    const blob = await response.blob();
    
    // 3. 上传到 Supabase Storage
    const { data, error } = await supabase.storage
      .from('avatars')
      .upload(fileName, blob, {
        contentType: `image/${ext}`,
        upsert: false
      });

    if (error) throw error;

    // 4. 获取公开 URL
    const { data: { publicUrl } } = supabase.storage
      .from('avatars')
      .getPublicUrl(fileName);

    return publicUrl;
  } catch (error) {
    console.error('Upload error:', error);
    throw error;
  }
}
```

## 2. 实时消息配置

### Step 1: 创建消息表

在 SQL Editor 中运行：

```sql
-- 创建消息表
CREATE TABLE IF NOT EXISTS messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  match_id UUID NOT NULL,
  sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  text TEXT,
  image_url TEXT,
  is_read BOOLEAN DEFAULT false,
  sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建索引
CREATE INDEX idx_messages_match_id ON messages(match_id);
CREATE INDEX idx_messages_sender_id ON messages(sender_id);
CREATE INDEX idx_messages_sent_at ON messages(sent_at);

-- 启用 RLS
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- RLS 策略
CREATE POLICY "Users can view messages in their matches" ON messages
  FOR SELECT TO authenticated
  USING (
    match_id IN (
      SELECT id FROM matches 
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

CREATE POLICY "Users can send messages to their matches" ON messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid() AND
    match_id IN (
      SELECT id FROM matches 
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );
```

### Step 2: 启用实时功能

```sql
-- 为 messages 表启用实时功能
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
```

### Step 3: 创建匹配表（如果还没有）

```sql
-- 创建匹配表
CREATE TABLE IF NOT EXISTS matches (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user1_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  user2_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user1_id, user2_id)
);

-- 启用 RLS
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;

-- RLS 策略
CREATE POLICY "Users can view their own matches" ON matches
  FOR SELECT TO authenticated
  USING (user1_id = auth.uid() OR user2_id = auth.uid());
```

## 3. 测试步骤

### 测试照片上传：

1. 在 ProfileScreen 中点击添加照片
2. 选择一张图片
3. 检查 Supabase Storage 中是否出现文件
4. 检查控制台日志

### 测试实时消息：

1. 创建两个用户账号
2. 让他们互相匹配
3. 进入聊天界面
4. 发送消息，检查是否实时显示

## 4. 常见问题解决

### 照片上传失败：

1. **检查 Bucket 是否存在**
   ```javascript
   // 在控制台运行
   const { data, error } = await supabase.storage.listBuckets()
   console.log('Buckets:', data)
   ```

2. **检查权限**
   - 确保 bucket 是 public
   - 确保 RLS 策略正确

3. **检查文件大小**
   - Supabase 免费版限制 50MB

### 实时消息不工作：

1. **检查 Realtime 是否启用**
   ```sql
   -- 查看已启用实时的表
   SELECT * FROM pg_publication_tables 
   WHERE pubname = 'supabase_realtime';
   ```

2. **检查 WebSocket 连接**
   ```javascript
   // 在控制台查看
   console.log(supabase.getChannels())
   ```

## 5. 环境变量配置

确保 `.env.local` 文件包含：

```env
EXPO_PUBLIC_SUPABASE_URL=你的项目URL
EXPO_PUBLIC_SUPABASE_ANON_KEY=你的匿名密钥
```

## 6. 调试工具

创建测试文件 `test_upload.js`：

```javascript
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const supabase = createClient(
  '你的项目URL',
  '你的匿名密钥'
);

async function testUpload() {
  // 测试 bucket 访问
  const { data: buckets, error: bucketsError } = await supabase.storage.listBuckets();
  console.log('Buckets:', buckets, 'Error:', bucketsError);

  // 测试上传
  const file = fs.readFileSync('./test-image.jpg');
  const { data, error } = await supabase.storage
    .from('avatars')
    .upload('test/test.jpg', file);
    
  console.log('Upload result:', data, 'Error:', error);
}

testUpload();
```

## 重要提示：

1. 确保 Supabase 项目是活跃的（免费版 7 天不活动会暂停）
2. 检查 Storage 配额（免费版 1GB）
3. 使用 Chrome DevTools 查看网络请求
4. 查看 Supabase Dashboard 的 Logs 部分

如果还有问题，请提供：
- 具体的错误信息
- Supabase Dashboard 截图
- 网络请求的响应