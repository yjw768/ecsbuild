# 管理后台核心功能实现指南

## 1. 👮 用户审核 - 封禁违规用户

### 数据库设计
```sql
-- 在profiles表添加字段
ALTER TABLE profiles ADD COLUMN 
  is_banned BOOLEAN DEFAULT false,
  ban_reason TEXT,
  banned_at TIMESTAMP,
  banned_by UUID REFERENCES admins(id);

-- 封禁记录表
CREATE TABLE ban_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  admin_id UUID REFERENCES admins(id),
  reason TEXT NOT NULL,
  evidence JSONB, -- 截图、聊天记录等
  duration INTEGER, -- 封禁天数，NULL表示永久
  created_at TIMESTAMP DEFAULT NOW()
);
```

### 实现代码
```typescript
// src/services/userManagement.ts
export class UserManagementService {
  // 封禁用户
  async banUser(userId: string, reason: string, duration?: number) {
    // 1. 更新用户状态
    await supabase
      .from('profiles')
      .update({
        is_banned: true,
        ban_reason: reason,
        banned_at: new Date(),
        banned_by: currentAdmin.id
      })
      .eq('id', userId);

    // 2. 记录封禁历史
    await supabase
      .from('ban_records')
      .insert({
        user_id: userId,
        admin_id: currentAdmin.id,
        reason,
        duration
      });

    // 3. 强制用户下线
    await this.forceLogout(userId);
    
    // 4. 发送通知
    await this.sendBanNotification(userId, reason);
  }

  // 解封用户
  async unbanUser(userId: string) {
    await supabase
      .from('profiles')
      .update({
        is_banned: false,
        ban_reason: null,
        banned_at: null
      })
      .eq('id', userId);
  }

  // 批量操作
  async banMultipleUsers(userIds: string[], reason: string) {
    const promises = userIds.map(id => this.banUser(id, reason));
    await Promise.all(promises);
  }
}
```

### 管理界面
```tsx
// app/admin/users/page.tsx
export default function UserManagement() {
  const [selectedUsers, setSelectedUsers] = useState<string[]>([]);

  const columns = [
    {
      title: '用户信息',
      render: (user) => (
        <div className="flex items-center gap-2">
          <img src={user.avatar} className="w-10 h-10 rounded-full" />
          <div>
            <div>{user.username}</div>
            <div className="text-sm text-gray-500">{user.email}</div>
          </div>
        </div>
      )
    },
    {
      title: '状态',
      render: (user) => (
        <Tag color={user.is_banned ? 'red' : 'green'}>
          {user.is_banned ? '已封禁' : '正常'}
        </Tag>
      )
    },
    {
      title: '举报次数',
      dataIndex: 'report_count',
      sorter: true
    },
    {
      title: '操作',
      render: (user) => (
        <Space>
          <Button onClick={() => viewUserDetail(user.id)}>查看</Button>
          <Button danger onClick={() => handleBan(user.id)}>封禁</Button>
        </Space>
      )
    }
  ];

  // 批量封禁
  const handleBatchBan = () => {
    Modal.confirm({
      title: `确认封禁${selectedUsers.length}个用户？`,
      content: (
        <Form>
          <Form.Item label="封禁原因" name="reason" rules={[{ required: true }]}>
            <Select>
              <Select.Option value="违规内容">发布违规内容</Select.Option>
              <Select.Option value="骚扰他人">骚扰其他用户</Select.Option>
              <Select.Option value="虚假信息">虚假个人信息</Select.Option>
              <Select.Option value="其他">其他原因</Select.Option>
            </Select>
          </Form.Item>
        </Form>
      ),
      onOk: async (values) => {
        await userService.banMultipleUsers(selectedUsers, values.reason);
        message.success('批量封禁成功');
      }
    });
  };

  return (
    <PageContainer>
      <Card>
        <Space className="mb-4">
          <Button 
            danger 
            disabled={selectedUsers.length === 0}
            onClick={handleBatchBan}
          >
            批量封禁 ({selectedUsers.length})
          </Button>
        </Space>
        
        <Table
          rowSelection={{
            selectedRowKeys: selectedUsers,
            onChange: setSelectedUsers
          }}
          columns={columns}
          dataSource={users}
        />
      </Card>
    </PageContainer>
  );
}
```

## 2. 🖼️ 内容管理 - 删除不良照片

### 实现代码
```typescript
// src/services/contentManagement.ts
export class ContentManagementService {
  // 删除违规照片
  async deletePhoto(photoId: string, reason: string) {
    // 1. 获取照片信息
    const { data: photo } = await supabase
      .from('user_photos')
      .select('*')
      .eq('id', photoId)
      .single();

    // 2. 从OSS删除
    await ossService.deleteObject(photo.oss_key);

    // 3. 更新数据库
    await supabase
      .from('user_photos')
      .update({
        status: 'deleted',
        deleted_reason: reason,
        deleted_at: new Date(),
        deleted_by: currentAdmin.id
      })
      .eq('id', photoId);

    // 4. 记录操作日志
    await this.logAction('delete_photo', {
      photo_id: photoId,
      user_id: photo.user_id,
      reason
    });

    // 5. 通知用户
    await this.notifyUser(photo.user_id, {
      type: 'photo_deleted',
      message: `您的照片因${reason}被删除`
    });
  }

  // 批量审核照片
  async reviewPhotoBatch(reviews: Array<{
    photoId: string;
    action: 'approve' | 'reject';
    reason?: string;
  }>) {
    const results = await Promise.allSettled(
      reviews.map(async (review) => {
        if (review.action === 'approve') {
          return this.approvePhoto(review.photoId);
        } else {
          return this.deletePhoto(review.photoId, review.reason!);
        }
      })
    );

    return {
      success: results.filter(r => r.status === 'fulfilled').length,
      failed: results.filter(r => r.status === 'rejected').length
    };
  }
}
```

### 内容审核界面
```tsx
// app/admin/content/photos/page.tsx
export default function PhotoReview() {
  const [photos, setPhotos] = useState([]);
  const [filter, setFilter] = useState('pending'); // pending, approved, rejected

  return (
    <div className="grid grid-cols-4 gap-4">
      {photos.map(photo => (
        <Card
          key={photo.id}
          cover={<img src={photo.url} />}
          actions={[
            <CheckOutlined 
              key="approve" 
              onClick={() => approvePhoto(photo.id)} 
            />,
            <DeleteOutlined 
              key="delete" 
              onClick={() => showDeleteModal(photo.id)} 
            />
          ]}
        >
          <Card.Meta
            title={photo.user.username}
            description={
              <>
                <div>上传时间：{formatDate(photo.created_at)}</div>
                {photo.ai_review_result && (
                  <div>AI评分：{photo.ai_review_result.score}</div>
                )}
              </>
            }
          />
        </Card>
      ))}
    </div>
  );
}
```

## 3. 📊 数据统计 - 看运营数据

### 统计服务
```typescript
// src/services/analytics.ts
export class AnalyticsService {
  // 获取关键指标
  async getKeyMetrics(dateRange: { start: Date; end: Date }) {
    // DAU (日活跃用户)
    const { data: dau } = await supabase
      .rpc('get_daily_active_users', {
        start_date: dateRange.start,
        end_date: dateRange.end
      });

    // 新增用户
    const { count: newUsers } = await supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .gte('created_at', dateRange.start)
      .lte('created_at', dateRange.end);

    // 匹配数据
    const { data: matchStats } = await supabase
      .rpc('get_match_statistics', { 
        start_date: dateRange.start 
      });

    return {
      dau,
      newUsers,
      matchRate: matchStats.match_rate,
      avgMatchesPerUser: matchStats.avg_matches
    };
  }

  // 用户留存率
  async getRetentionRate(cohortDate: Date) {
    const { data } = await supabase.rpc('calculate_retention', {
      cohort_date: cohortDate
    });
    
    return data;
  }

  // 实时数据
  async getRealTimeStats() {
    const now = new Date();
    const today = new Date(now.setHours(0, 0, 0, 0));

    const [onlineUsers, todayMatches, todayMessages] = await Promise.all([
      this.getOnlineUsers(),
      this.getTodayMatches(),
      this.getTodayMessages()
    ]);

    return {
      onlineUsers,
      todayMatches,
      todayMessages,
      timestamp: new Date()
    };
  }
}
```

### 数据可视化界面
```tsx
// app/admin/analytics/page.tsx
import { Line, Column, Pie } from '@ant-design/plots';

export default function Analytics() {
  const [metrics, setMetrics] = useState(null);
  const [dateRange, setDateRange] = useState([moment().subtract(7, 'days'), moment()]);

  // DAU趋势图
  const dauConfig = {
    data: metrics?.dauTrend || [],
    xField: 'date',
    yField: 'value',
    smooth: true,
    point: { size: 3 },
    tooltip: {
      formatter: (datum) => ({
        name: '日活跃用户',
        value: `${datum.value}人`
      })
    }
  };

  // 用户增长图
  const growthConfig = {
    data: metrics?.userGrowth || [],
    xField: 'date',
    yField: 'count',
    seriesField: 'type',
    isStack: true,
    legend: { position: 'top-left' }
  };

  return (
    <PageContainer>
      {/* 关键指标卡片 */}
      <Row gutter={16} className="mb-6">
        <Col span={6}>
          <Card>
            <Statistic
              title="总用户数"
              value={metrics?.totalUsers}
              prefix={<UserOutlined />}
              suffix={
                <span className="text-green-500 text-sm">
                  +{metrics?.userGrowthRate}%
                </span>
              }
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card>
            <Statistic
              title="日活跃用户"
              value={metrics?.dau}
              prefix={<TeamOutlined />}
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card>
            <Statistic
              title="匹配成功率"
              value={metrics?.matchRate}
              suffix="%"
              prefix={<HeartOutlined />}
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card>
            <Statistic
              title="平均在线时长"
              value={metrics?.avgOnlineTime}
              suffix="分钟"
              prefix={<ClockCircleOutlined />}
            />
          </Card>
        </Col>
      </Row>

      {/* 图表 */}
      <Row gutter={16}>
        <Col span={12}>
          <Card title="DAU趋势">
            <Line {...dauConfig} height={300} />
          </Card>
        </Col>
        <Col span={12}>
          <Card title="用户增长">
            <Column {...growthConfig} height={300} />
          </Card>
        </Col>
      </Row>

      {/* 实时监控 */}
      <Card title="实时数据" className="mt-4">
        <Row gutter={16}>
          <Col span={8}>
            <Statistic
              title="当前在线"
              value={realTimeStats?.onlineUsers}
              valueStyle={{ color: '#3f8600' }}
              prefix={<UserOutlined />}
            />
          </Col>
          <Col span={8}>
            <Statistic
              title="今日匹配"
              value={realTimeStats?.todayMatches}
              prefix={<HeartOutlined />}
            />
          </Col>
          <Col span={8}>
            <Statistic
              title="今日消息"
              value={realTimeStats?.todayMessages}
              prefix={<MessageOutlined />}
            />
          </Col>
        </Row>
      </Card>
    </PageContainer>
  );
}
```

### SQL函数示例
```sql
-- 计算DAU
CREATE OR REPLACE FUNCTION get_daily_active_users(
  start_date DATE,
  end_date DATE
) RETURNS TABLE (
  date DATE,
  active_users INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    DATE(created_at) as date,
    COUNT(DISTINCT user_id) as active_users
  FROM user_activities
  WHERE created_at BETWEEN start_date AND end_date
  GROUP BY DATE(created_at)
  ORDER BY date;
END;
$$ LANGUAGE plpgsql;
```

## 4. 📨 推送通知 - 给用户发消息

### 推送服务实现
```typescript
// src/services/pushNotification.ts
import { Expo, ExpoPushMessage } from 'expo-server-sdk';

export class PushNotificationService {
  private expo = new Expo();

  // 发送单个推送
  async sendToUser(userId: string, notification: {
    title: string;
    body: string;
    data?: any;
  }) {
    // 1. 获取用户的推送token
    const { data: user } = await supabase
      .from('profiles')
      .select('push_token')
      .eq('id', userId)
      .single();

    if (!user?.push_token) return;

    // 2. 构建推送消息
    const message: ExpoPushMessage = {
      to: user.push_token,
      sound: 'default',
      title: notification.title,
      body: notification.body,
      data: notification.data,
      badge: 1
    };

    // 3. 发送推送
    try {
      const tickets = await this.expo.sendPushNotificationsAsync([message]);
      
      // 4. 记录推送历史
      await this.logPushNotification(userId, notification, tickets[0]);
    } catch (error) {
      console.error('推送失败:', error);
    }
  }

  // 批量推送
  async sendBulkNotification(filter: {
    userIds?: string[];
    tags?: string[];
    all?: boolean;
  }, notification: {
    title: string;
    body: string;
  }) {
    // 1. 获取目标用户
    let query = supabase
      .from('profiles')
      .select('id, push_token')
      .not('push_token', 'is', null);

    if (filter.userIds) {
      query = query.in('id', filter.userIds);
    }

    const { data: users } = await query;

    // 2. 分批发送（Expo推送限制每批100条）
    const chunks = this.chunkArray(users, 100);
    
    for (const chunk of chunks) {
      const messages = chunk.map(user => ({
        to: user.push_token,
        sound: 'default',
        title: notification.title,
        body: notification.body
      }));

      await this.expo.sendPushNotificationsAsync(messages);
    }

    // 3. 记录推送任务
    await supabase.from('push_campaigns').insert({
      title: notification.title,
      body: notification.body,
      target_count: users.length,
      sent_at: new Date()
    });
  }

  // 定时推送
  async schedulePush(scheduleTime: Date, notification: any) {
    await supabase.from('scheduled_pushes').insert({
      scheduled_at: scheduleTime,
      notification,
      status: 'pending'
    });
  }
}
```

### 推送管理界面
```tsx
// app/admin/push/page.tsx
export default function PushNotifications() {
  const [form] = Form.useForm();
  const [sending, setSending] = useState(false);
  const [targetUsers, setTargetUsers] = useState<number>(0);

  // 预览目标用户数
  const previewTargetUsers = async (values: any) => {
    let count = 0;
    
    if (values.target === 'all') {
      const { count: total } = await supabase
        .from('profiles')
        .select('*', { count: 'exact', head: true });
      count = total || 0;
    } else if (values.target === 'active') {
      // 7天内活跃用户
      const { count: active } = await supabase
        .from('profiles')
        .select('*', { count: 'exact', head: true })
        .gte('last_active_at', moment().subtract(7, 'days').toISOString());
      count = active || 0;
    }
    
    setTargetUsers(count);
  };

  const handleSend = async (values: any) => {
    setSending(true);
    
    try {
      await pushService.sendBulkNotification(
        {
          all: values.target === 'all',
          tags: values.target === 'tagged' ? values.tags : undefined
        },
        {
          title: values.title,
          body: values.body
        }
      );
      
      message.success(`推送已发送给${targetUsers}个用户`);
      form.resetFields();
    } catch (error) {
      message.error('推送失败');
    } finally {
      setSending(false);
    }
  };

  return (
    <PageContainer>
      <Row gutter={24}>
        <Col span={16}>
          <Card title="发送推送">
            <Form
              form={form}
              layout="vertical"
              onFinish={handleSend}
              onValuesChange={previewTargetUsers}
            >
              <Form.Item 
                name="target" 
                label="目标用户" 
                rules={[{ required: true }]}
              >
                <Radio.Group>
                  <Radio value="all">所有用户</Radio>
                  <Radio value="active">活跃用户（7天内）</Radio>
                  <Radio value="new">新用户（3天内）</Radio>
                  <Radio value="custom">自定义</Radio>
                </Radio.Group>
              </Form.Item>

              <Form.Item 
                name="title" 
                label="标题" 
                rules={[{ required: true }]}
              >
                <Input placeholder="输入推送标题" />
              </Form.Item>

              <Form.Item 
                name="body" 
                label="内容" 
                rules={[{ required: true }]}
              >
                <TextArea 
                  rows={4} 
                  placeholder="输入推送内容"
                  showCount
                  maxLength={200}
                />
              </Form.Item>

              <Form.Item name="schedule" label="发送时间">
                <Radio.Group>
                  <Radio value="now">立即发送</Radio>
                  <Radio value="scheduled">定时发送</Radio>
                </Radio.Group>
              </Form.Item>

              <Form.Item>
                <Space>
                  <Button type="primary" htmlType="submit" loading={sending}>
                    发送推送
                  </Button>
                  <span className="text-gray-500">
                    预计发送给 {targetUsers} 个用户
                  </span>
                </Space>
              </Form.Item>
            </Form>
          </Card>
        </Col>

        <Col span={8}>
          {/* 推送预览 */}
          <Card title="推送预览">
            <div className="bg-gray-100 p-4 rounded-lg">
              <div className="bg-white rounded-lg shadow p-3">
                <div className="flex items-center gap-2 mb-2">
                  <img src="/app-icon.png" className="w-8 h-8" />
                  <span className="font-semibold">GroupUp</span>
                  <span className="text-xs text-gray-500">现在</span>
                </div>
                <div className="font-semibold">
                  {form.getFieldValue('title') || '推送标题'}
                </div>
                <div className="text-sm text-gray-600">
                  {form.getFieldValue('body') || '推送内容...'}
                </div>
              </div>
            </div>
          </Card>

          {/* 推送历史 */}
          <Card title="最近推送" className="mt-4">
            <List
              dataSource={recentPushes}
              renderItem={item => (
                <List.Item>
                  <List.Item.Meta
                    title={item.title}
                    description={
                      <div>
                        <div>{item.body}</div>
                        <div className="text-xs text-gray-500">
                          发送给{item.target_count}人 • {formatDate(item.sent_at)}
                        </div>
                      </div>
                    }
                  />
                </List.Item>
              )}
            />
          </Card>
        </Col>
      </Row>
    </PageContainer>
  );
}
```

### 客户端接收推送
```typescript
// App.tsx (React Native)
import * as Notifications from 'expo-notifications';

// 注册推送通知
const registerForPushNotifications = async () => {
  const { status } = await Notifications.requestPermissionsAsync();
  if (status !== 'granted') return;

  const token = (await Notifications.getExpoPushTokenAsync()).data;
  
  // 保存token到服务器
  await supabase
    .from('profiles')
    .update({ push_token: token })
    .eq('id', currentUser.id);
};

// 处理推送
Notifications.addNotificationReceivedListener(notification => {
  console.log('收到推送:', notification);
});
```

## 📝 总结

这4个功能的实现要点：

1. **用户审核** - 数据库字段 + 管理界面
2. **内容管理** - OSS删除 + 批量操作
3. **数据统计** - SQL函数 + 图表展示
4. **推送通知** - Expo推送 + 定时任务

都可以集成在一个管理后台中，部署在同一台服务器上！