# 免费实现推送通知和数据统计

## 📊 免费数据统计方案

### 1. 基础统计（纯SQL实现）

```typescript
// src/services/freeAnalytics.ts
export class FreeAnalyticsService {
  // 获取今日统计
  async getTodayStats() {
    const today = new Date().toISOString().split('T')[0];
    
    // 使用一个SQL查询获取所有数据
    const { data } = await supabase.rpc('get_today_stats', { 
      target_date: today 
    });
    
    return data;
  }
  
  // 获取趋势数据
  async getTrendData(days = 7) {
    const { data } = await supabase.rpc('get_trend_data', { 
      days_count: days 
    });
    
    return data;
  }
}
```

### SQL函数（在Supabase SQL编辑器中运行）
```sql
-- 创建统计函数
CREATE OR REPLACE FUNCTION get_today_stats(target_date DATE)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'total_users', (SELECT COUNT(*) FROM profiles),
    'new_users_today', (
      SELECT COUNT(*) FROM profiles 
      WHERE DATE(created_at) = target_date
    ),
    'active_users_today', (
      SELECT COUNT(DISTINCT user_id) FROM user_activities 
      WHERE DATE(created_at) = target_date
    ),
    'matches_today', (
      SELECT COUNT(*) FROM matches 
      WHERE DATE(created_at) = target_date
    ),
    'messages_today', (
      SELECT COUNT(*) FROM messages 
      WHERE DATE(sent_at) = target_date
    )
  ) INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 获取趋势数据
CREATE OR REPLACE FUNCTION get_trend_data(days_count INTEGER)
RETURNS TABLE(
  date DATE,
  new_users INTEGER,
  active_users INTEGER,
  matches INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.date,
    COALESCE(u.count, 0) as new_users,
    COALESCE(a.count, 0) as active_users,
    COALESCE(m.count, 0) as matches
  FROM (
    SELECT generate_series(
      CURRENT_DATE - INTERVAL '1 day' * days_count,
      CURRENT_DATE,
      '1 day'::interval
    )::date as date
  ) d
  LEFT JOIN (
    SELECT DATE(created_at) as date, COUNT(*) as count
    FROM profiles
    GROUP BY DATE(created_at)
  ) u ON d.date = u.date
  LEFT JOIN (
    SELECT DATE(created_at) as date, COUNT(DISTINCT user_id) as count
    FROM user_activities
    GROUP BY DATE(created_at)
  ) a ON d.date = a.date
  LEFT JOIN (
    SELECT DATE(created_at) as date, COUNT(*) as count
    FROM matches
    GROUP BY DATE(created_at)
  ) m ON d.date = m.date
  ORDER BY d.date;
END;
$$ LANGUAGE plpgsql;
```

### 2. 简单的图表展示（使用免费的Chart.js）

```tsx
// app/admin/analytics/page.tsx
import { Line } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
} from 'chart.js';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
);

export default function FreeAnalytics() {
  const [stats, setStats] = useState(null);
  const [trendData, setTrendData] = useState([]);

  useEffect(() => {
    loadStats();
  }, []);

  const loadStats = async () => {
    // 获取今日统计
    const todayStats = await analyticsService.getTodayStats();
    setStats(todayStats);
    
    // 获取趋势数据
    const trend = await analyticsService.getTrendData(30);
    setTrendData(trend);
  };

  // 图表配置
  const chartData = {
    labels: trendData.map(d => d.date),
    datasets: [
      {
        label: '新增用户',
        data: trendData.map(d => d.new_users),
        borderColor: 'rgb(75, 192, 192)',
        backgroundColor: 'rgba(75, 192, 192, 0.5)',
      },
      {
        label: '活跃用户',
        data: trendData.map(d => d.active_users),
        borderColor: 'rgb(255, 99, 132)',
        backgroundColor: 'rgba(255, 99, 132, 0.5)',
      },
      {
        label: '匹配数',
        data: trendData.map(d => d.matches),
        borderColor: 'rgb(53, 162, 235)',
        backgroundColor: 'rgba(53, 162, 235, 0.5)',
      }
    ],
  };

  return (
    <div className="p-6">
      {/* 关键指标 */}
      <div className="grid grid-cols-5 gap-4 mb-8">
        <div className="bg-white p-4 rounded-lg shadow">
          <div className="text-gray-500 text-sm">总用户</div>
          <div className="text-2xl font-bold">{stats?.total_users || 0}</div>
        </div>
        <div className="bg-white p-4 rounded-lg shadow">
          <div className="text-gray-500 text-sm">今日新增</div>
          <div className="text-2xl font-bold text-green-600">
            +{stats?.new_users_today || 0}
          </div>
        </div>
        <div className="bg-white p-4 rounded-lg shadow">
          <div className="text-gray-500 text-sm">今日活跃</div>
          <div className="text-2xl font-bold">{stats?.active_users_today || 0}</div>
        </div>
        <div className="bg-white p-4 rounded-lg shadow">
          <div className="text-gray-500 text-sm">今日匹配</div>
          <div className="text-2xl font-bold">{stats?.matches_today || 0}</div>
        </div>
        <div className="bg-white p-4 rounded-lg shadow">
          <div className="text-gray-500 text-sm">今日消息</div>
          <div className="text-2xl font-bold">{stats?.messages_today || 0}</div>
        </div>
      </div>

      {/* 趋势图表 */}
      <div className="bg-white p-6 rounded-lg shadow">
        <h3 className="text-lg font-semibold mb-4">30天趋势</h3>
        <Line data={chartData} height={100} />
      </div>
    </div>
  );
}
```

### 3. 记录用户活动（免费方案）

```typescript
// 在客户端记录用户活动
export const trackUserActivity = async (action: string, details?: any) => {
  await supabase.from('user_activities').insert({
    user_id: currentUser.id,
    action,
    details,
    created_at: new Date()
  });
};

// 使用示例
trackUserActivity('view_profile', { viewed_user_id: userId });
trackUserActivity('send_message', { match_id: matchId });
trackUserActivity('swipe', { target_user_id: userId, action: 'like' });
```

## 📨 免费推送通知方案

### 1. 应用内通知（完全免费）

```typescript
// 数据库表
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);

// 创建索引
CREATE INDEX idx_notifications_user_unread 
ON notifications(user_id, is_read) 
WHERE is_read = false;
```

### 2. 发送通知服务

```typescript
// src/services/freeNotification.ts
export class FreeNotificationService {
  // 发送通知给单个用户
  async sendToUser(userId: string, notification: {
    type: 'match' | 'message' | 'like' | 'system';
    title: string;
    body: string;
    data?: any;
  }) {
    await supabase.from('notifications').insert({
      user_id: userId,
      ...notification
    });
    
    // 如果用户在线，通过WebSocket实时推送
    await this.pushRealtime(userId, notification);
  }
  
  // 批量发送
  async sendBulk(userIds: string[], notification: any) {
    const notifications = userIds.map(userId => ({
      user_id: userId,
      ...notification
    }));
    
    await supabase.from('notifications').insert(notifications);
  }
  
  // 实时推送（使用Supabase Realtime）
  private async pushRealtime(userId: string, notification: any) {
    // 通过Supabase的broadcast功能推送
    const channel = supabase.channel(`user:${userId}`);
    await channel.send({
      type: 'broadcast',
      event: 'notification',
      payload: notification
    });
  }
}
```

### 3. 客户端接收通知

```typescript
// React Native 客户端
export const useNotifications = () => {
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  
  useEffect(() => {
    // 1. 获取未读通知
    fetchUnreadNotifications();
    
    // 2. 订阅实时通知
    const channel = supabase
      .channel(`user:${currentUser.id}`)
      .on('broadcast', { event: 'notification' }, (payload) => {
        // 收到新通知
        showLocalNotification(payload);
        setUnreadCount(prev => prev + 1);
      })
      .subscribe();
    
    return () => {
      channel.unsubscribe();
    };
  }, []);
  
  // 显示本地通知
  const showLocalNotification = async (notification) => {
    // 使用expo-notifications显示本地通知
    await Notifications.scheduleNotificationAsync({
      content: {
        title: notification.title,
        body: notification.body,
        data: notification.data,
      },
      trigger: null, // 立即显示
    });
  };
  
  // 标记已读
  const markAsRead = async (notificationId: string) => {
    await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('id', notificationId);
  };
  
  return { notifications, unreadCount, markAsRead };
};
```

### 4. 通知中心UI

```tsx
// components/NotificationCenter.tsx
export const NotificationCenter = () => {
  const { notifications, unreadCount, markAsRead } = useNotifications();
  const [visible, setVisible] = useState(false);
  
  return (
    <>
      {/* 通知图标 */}
      <TouchableOpacity onPress={() => setVisible(true)}>
        <View>
          <Icon name="bell" size={24} />
          {unreadCount > 0 && (
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{unreadCount}</Text>
            </View>
          )}
        </View>
      </TouchableOpacity>
      
      {/* 通知列表 */}
      <Modal visible={visible} animationType="slide">
        <View style={styles.container}>
          <Text style={styles.title}>通知中心</Text>
          
          <FlatList
            data={notifications}
            renderItem={({ item }) => (
              <TouchableOpacity
                style={[
                  styles.notificationItem,
                  !item.is_read && styles.unread
                ]}
                onPress={() => {
                  markAsRead(item.id);
                  handleNotificationClick(item);
                }}
              >
                <View style={styles.notificationIcon}>
                  {getNotificationIcon(item.type)}
                </View>
                
                <View style={styles.notificationContent}>
                  <Text style={styles.notificationTitle}>{item.title}</Text>
                  <Text style={styles.notificationBody}>{item.body}</Text>
                  <Text style={styles.notificationTime}>
                    {formatTime(item.created_at)}
                  </Text>
                </View>
              </TouchableOpacity>
            )}
            keyExtractor={item => item.id}
          />
        </View>
      </Modal>
    </>
  );
};
```

### 5. 定时任务（使用Supabase Edge Functions）

```typescript
// supabase/functions/daily-notifications/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )
  
  // 每天提醒不活跃用户
  const { data: inactiveUsers } = await supabase
    .from('profiles')
    .select('id, username')
    .lt('last_active_at', new Date(Date.now() - 3 * 24 * 60 * 60 * 1000))
    .limit(100);
  
  // 发送通知
  for (const user of inactiveUsers) {
    await supabase.from('notifications').insert({
      user_id: user.id,
      type: 'system',
      title: '我们想念你！',
      body: '已经3天没有使用GroupUp了，快来看看新的匹配吧！'
    });
  }
  
  return new Response('Notifications sent', { status: 200 });
});
```

### 6. 管理后台推送界面（简化版）

```tsx
// app/admin/notifications/page.tsx
export default function NotificationAdmin() {
  const [message, setMessage] = useState('');
  const [target, setTarget] = useState('all');
  const [sending, setSending] = useState(false);
  
  const sendNotification = async () => {
    setSending(true);
    
    try {
      let userIds = [];
      
      if (target === 'all') {
        const { data } = await supabase
          .from('profiles')
          .select('id');
        userIds = data.map(u => u.id);
      } else if (target === 'active') {
        const { data } = await supabase
          .from('profiles')
          .select('id')
          .gte('last_active_at', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000));
        userIds = data.map(u => u.id);
      }
      
      // 分批发送（每批100个）
      const chunks = [];
      for (let i = 0; i < userIds.length; i += 100) {
        chunks.push(userIds.slice(i, i + 100));
      }
      
      for (const chunk of chunks) {
        await notificationService.sendBulk(chunk, {
          type: 'system',
          title: '系统通知',
          body: message
        });
      }
      
      alert(`成功发送给 ${userIds.length} 个用户`);
    } catch (error) {
      alert('发送失败');
    } finally {
      setSending(false);
    }
  };
  
  return (
    <div className="p-6">
      <h2 className="text-xl font-bold mb-4">发送通知</h2>
      
      <div className="space-y-4">
        <div>
          <label className="block mb-2">通知内容</label>
          <textarea
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            className="w-full p-2 border rounded"
            rows={4}
            placeholder="输入通知内容..."
          />
        </div>
        
        <div>
          <label className="block mb-2">目标用户</label>
          <select
            value={target}
            onChange={(e) => setTarget(e.target.value)}
            className="w-full p-2 border rounded"
          >
            <option value="all">所有用户</option>
            <option value="active">活跃用户（7天内）</option>
            <option value="new">新用户（3天内）</option>
          </select>
        </div>
        
        <button
          onClick={sendNotification}
          disabled={!message || sending}
          className={`px-4 py-2 rounded text-white ${
            sending ? 'bg-gray-400' : 'bg-blue-500 hover:bg-blue-600'
          }`}
        >
          {sending ? '发送中...' : '发送通知'}
        </button>
      </div>
    </div>
  );
}
```

## 💰 成本对比

| 方案 | 第三方服务 | 自己实现 |
|------|------------|----------|
| 数据统计 | ¥200-500/月 | ¥0 |
| 推送通知 | ¥100-300/月 | ¥0 |
| 开发时间 | 1天 | 2-3天 |
| 维护成本 | 低 | 中 |

## 🎯 总结

### 数据统计
- 使用SQL函数计算
- Chart.js免费图表
- 成本：¥0

### 推送通知
- 应用内通知中心
- Supabase实时推送
- 本地通知显示
- 成本：¥0

### 优点
- 完全免费
- 数据自主可控
- 功能足够用

### 缺点
- 没有真正的推送（需要打开APP）
- 统计功能相对简单
- 需要自己维护

但对于1000-2000用户完全够用了！