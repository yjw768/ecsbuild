# ⭐ Super Like 功能测试指南

## ✅ 功能2：Super Like 系统

### 新增功能：
1. **每日限制** 
   - 免费用户：1个/天
   - Premium用户：5个/天
   
2. **特殊通知**
   - 被 Super Like 的用户会收到特殊通知
   - 通知包含发送者信息
   
3. **视觉标记**
   - Super Like 计数器显示在顶部
   - 卡片上显示"Super Liked You!"标记
   
4. **限制提醒**
   - 用完后提示升级到 Premium
   - 显示剩余次数

### 测试步骤：

#### 1. 在 Supabase 中创建表
```sql
-- 运行 create_super_likes_table.sql 文件的内容
```

#### 2. 测试 Super Like 功能
1. 登录应用
2. 在主页查看顶部的 Super Like 计数器（星星图标）
3. 向上滑动卡片使用 Super Like
4. 观察：
   - 计数器减少
   - 弹出提示显示剩余次数
   - 用完后显示升级提示

#### 3. 在 Profile 页面测试
添加测试按钮（可选）：

```typescript
// 在 ProfileScreen 中添加
<TouchableOpacity 
  style={[styles.logoutButton, { backgroundColor: '#fff3cd', marginTop: 10 }]} 
  onPress={async () => {
    const success = await testSuperLikeFeature();
    Alert.alert('Super Like Test', success ? 'Test completed' : 'Test failed');
  }}
>
  <Text style={[styles.logoutButtonText, { color: '#ffc107' }]}>Test Super Like</Text>
</TouchableOpacity>
```

### 🎯 验证要点：

#### 每日限制
- [ ] 免费用户只能使用1次
- [ ] 使用后计数器显示0
- [ ] 再次使用显示限制提示
- [ ] 提供升级选项

#### 特殊标记
- [ ] 被 Super Like 的用户看到蓝色星星标记
- [ ] 标记显示"Super Liked You!"
- [ ] 匹配后有特殊提示

#### 通知系统
- [ ] 创建通知记录
- [ ] 包含发送者信息
- [ ] 可在通知中心查看

#### 重置机制
- [ ] 每日凌晨自动重置
- [ ] 计数器恢复到初始值

### 📊 控制台日志示例：
```
=== Super Like 功能测试 ===
✅ 当前用户: Test User
⭐ 今日剩余 Super Like: 1
✅ 找到用户数: 5
🎯 目标用户: Emma
📤 Super Like 结果: {
  success: true,
  remaining: 0,
  message: "Super Like 发送成功！⭐"
}
⭐ 更新后剩余: 0
📜 Super Like 历史: 1 条记录
🧪 测试每日限制...
🚫 限制测试结果: 今日 Super Like 已用完！明天再来吧 💫

=== 测试结果 ===
✅ Super Like 功能正常
✅ 每日限制工作正常
✅ 历史记录保存正常
✅ 重置功能正常
```

### 🐛 可能的问题：

1. **表不存在**
   - 解决：运行 SQL 创建脚本

2. **计数器不更新**
   - 检查：状态管理
   - 刷新：重新获取剩余次数

3. **通知未创建**
   - 检查：notifications 表是否存在
   - 验证：触发器是否正确创建

### 💎 Premium 功能（预留）

```typescript
// 升级到 Premium
const upgradeToPremium = async () => {
  // 实现应用内购买
  // 更新用户状态
  // 刷新 Super Like 限制
};
```

## 🎉 功能完成度：100%

Super Like 功能已完全实现，包括：
- ✅ 每日限制机制
- ✅ 特殊通知系统
- ✅ 视觉反馈
- ✅ Premium 升级提示