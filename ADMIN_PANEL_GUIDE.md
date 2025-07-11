# GroupUp 管理后台搭建指南

## 🤔 为什么需要管理后台？

### Supabase提供的功能
```
✅ 数据库管理 (Supabase Studio)
✅ 用户认证管理
✅ 存储文件管理
✅ SQL查询工具

❌ 但缺少业务功能：
- 用户审核
- 内容管理
- 数据统计
- 运营工具
```

## 📊 管理后台需要的功能

### 1. 用户管理
- 查看所有用户列表
- 禁用/启用账号
- 审核用户照片
- 查看用户举报

### 2. 内容管理
- 审核不当内容
- 删除违规照片
- 管理举报信息
- 敏感词过滤

### 3. 数据统计
- 日活跃用户
- 匹配成功率
- 用户增长趋势
- 收入统计

### 4. 运营工具
- 推送通知
- 活动管理
- 用户反馈
- 系统配置

## 🚀 搭建方案

### 方案1：使用现成的管理框架（推荐）

#### 使用 Ant Design Pro
```bash
# 创建管理后台项目
npx create-umi@latest admin --typescript

# 选择 ant-design-pro
# 选择 simple 模板
```

```typescript
// src/pages/UserList/index.tsx
import { PageContainer } from '@ant-design/pro-components';
import { Table, Button, Tag, Modal } from 'antd';
import { useState, useEffect } from 'react';
import { supabase } from '@/services/supabase';

export default function UserList() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);

  // 获取用户列表
  const fetchUsers = async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (!error) {
      setUsers(data);
    }
    setLoading(false);
  };

  // 禁用用户
  const handleBanUser = async (userId: string) => {
    Modal.confirm({
      title: '确认禁用该用户？',
      onOk: async () => {
        await supabase
          .from('profiles')
          .update({ is_banned: true })
          .eq('id', userId);
        
        fetchUsers();
      }
    });
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  const columns = [
    {
      title: '头像',
      dataIndex: 'avatar',
      render: (url: string) => (
        <img src={url} alt="avatar" style={{ width: 50, height: 50, borderRadius: '50%' }} />
      )
    },
    {
      title: '用户名',
      dataIndex: 'username',
    },
    {
      title: '年龄',
      dataIndex: 'age',
    },
    {
      title: '状态',
      dataIndex: 'is_banned',
      render: (banned: boolean) => (
        <Tag color={banned ? 'red' : 'green'}>
          {banned ? '已禁用' : '正常'}
        </Tag>
      )
    },
    {
      title: '注册时间',
      dataIndex: 'created_at',
      render: (date: string) => new Date(date).toLocaleDateString()
    },
    {
      title: '操作',
      render: (_, record) => (
        <Button 
          danger 
          size="small"
          onClick={() => handleBanUser(record.id)}
        >
          禁用
        </Button>
      )
    }
  ];

  return (
    <PageContainer title="用户管理">
      <Table 
        columns={columns}
        dataSource={users}
        loading={loading}
        rowKey="id"
      />
    </PageContainer>
  );
}
```

### 方案2：使用Supabase + Next.js快速搭建

```bash
# 创建Next.js项目
npx create-next-app@latest groupup-admin --typescript --tailwind

cd groupup-admin
npm install @supabase/supabase-js recharts antd
```

```typescript
// app/dashboard/page.tsx
'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@supabase/supabase-js';
import { Card, Statistic, Row, Col } from 'antd';
import { UserOutlined, HeartOutlined, MessageOutlined } from '@ant-design/icons';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_SERVICE_KEY! // 使用service key
);

export default function Dashboard() {
  const [stats, setStats] = useState({
    totalUsers: 0,
    todayUsers: 0,
    totalMatches: 0,
    totalMessages: 0
  });

  useEffect(() => {
    fetchStats();
  }, []);

  const fetchStats = async () => {
    // 获取总用户数
    const { count: totalUsers } = await supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true });

    // 获取今日新增用户
    const today = new Date().toISOString().split('T')[0];
    const { count: todayUsers } = await supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .gte('created_at', today);

    // 获取总匹配数
    const { count: totalMatches } = await supabase
      .from('matches')
      .select('*', { count: 'exact', head: true });

    // 获取总消息数
    const { count: totalMessages } = await supabase
      .from('messages')
      .select('*', { count: 'exact', head: true });

    setStats({
      totalUsers: totalUsers || 0,
      todayUsers: todayUsers || 0,
      totalMatches: totalMatches || 0,
      totalMessages: totalMessages || 0
    });
  };

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-6">数据概览</h1>
      
      <Row gutter={16}>
        <Col span={6}>
          <Card>
            <Statistic
              title="总用户数"
              value={stats.totalUsers}
              prefix={<UserOutlined />}
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card>
            <Statistic
              title="今日新增"
              value={stats.todayUsers}
              valueStyle={{ color: '#3f8600' }}
              prefix={<UserOutlined />}
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card>
            <Statistic
              title="总匹配数"
              value={stats.totalMatches}
              prefix={<HeartOutlined />}
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card>
            <Statistic
              title="消息总数"
              value={stats.totalMessages}
              prefix={<MessageOutlined />}
            />
          </Card>
        </Col>
      </Row>
    </div>
  );
}
```

### 方案3：使用现成的低代码平台

#### 1. Retool (推荐)
```javascript
// 在Retool中连接Supabase
// 1. 添加Resource -> PostgreSQL
// 2. 填入Supabase数据库连接信息
// 3. 拖拽组件创建界面

// 查询示例
SELECT 
  id,
  username,
  email,
  age,
  created_at,
  CASE WHEN is_banned THEN '已禁用' ELSE '正常' END as status
FROM profiles
ORDER BY created_at DESC
```

#### 2. Appsmith
- 开源免费
- 可视化拖拽
- 支持自部署

## 🛠️ 完整的管理后台功能实现

```typescript
// src/services/adminService.ts
import { supabase } from './supabase';

export class AdminService {
  // 用户管理
  async getUsers(page = 1, pageSize = 20) {
    const start = (page - 1) * pageSize;
    const end = start + pageSize - 1;

    return await supabase
      .from('profiles')
      .select('*', { count: 'exact' })
      .range(start, end)
      .order('created_at', { ascending: false });
  }

  // 审核照片
  async reviewPhoto(photoId: string, approved: boolean) {
    return await supabase
      .from('photos')
      .update({ 
        is_approved: approved,
        reviewed_at: new Date().toISOString()
      })
      .eq('id', photoId);
  }

  // 处理举报
  async handleReport(reportId: string, action: 'dismiss' | 'ban_user' | 'delete_content') {
    const { data: report } = await supabase
      .from('reports')
      .select('*')
      .eq('id', reportId)
      .single();

    switch (action) {
      case 'ban_user':
        await supabase
          .from('profiles')
          .update({ is_banned: true })
          .eq('id', report.reported_user_id);
        break;
      
      case 'delete_content':
        await supabase
          .from('messages')
          .delete()
          .eq('id', report.content_id);
        break;
    }

    // 更新举报状态
    return await supabase
      .from('reports')
      .update({ 
        status: 'resolved',
        action_taken: action,
        resolved_at: new Date().toISOString()
      })
      .eq('id', reportId);
  }

  // 数据统计
  async getStatistics(dateRange: { start: Date; end: Date }) {
    // 日活跃用户
    const { data: dau } = await supabase
      .rpc('get_daily_active_users', {
        start_date: dateRange.start,
        end_date: dateRange.end
      });

    // 新增用户
    const { data: newUsers } = await supabase
      .from('profiles')
      .select('created_at')
      .gte('created_at', dateRange.start)
      .lte('created_at', dateRange.end);

    // 匹配成功率
    const { data: matches } = await supabase
      .from('matches')
      .select('created_at')
      .gte('created_at', dateRange.start)
      .lte('created_at', dateRange.end);

    return {
      dau,
      newUsers: newUsers?.length || 0,
      matches: matches?.length || 0
    };
  }
}
```

## 📱 移动端管理

```typescript
// 使用React Native创建移动管理端
// screens/AdminScreen.tsx
import React from 'react';
import { View, Text, FlatList, TouchableOpacity } from 'react-native';
import { supabase } from '../services/supabase';

export const AdminReportsScreen = () => {
  const [reports, setReports] = useState([]);

  useEffect(() => {
    fetchPendingReports();
  }, []);

  const fetchPendingReports = async () => {
    const { data } = await supabase
      .from('reports')
      .select(`
        *,
        reporter:reporter_id(username),
        reported:reported_user_id(username)
      `)
      .eq('status', 'pending')
      .order('created_at', { ascending: false });
    
    setReports(data || []);
  };

  const handleReport = async (reportId: string, action: string) => {
    await adminService.handleReport(reportId, action);
    fetchPendingReports();
  };

  return (
    <FlatList
      data={reports}
      renderItem={({ item }) => (
        <View style={styles.reportCard}>
          <Text>举报人: {item.reporter.username}</Text>
          <Text>被举报: {item.reported.username}</Text>
          <Text>原因: {item.reason}</Text>
          
          <View style={styles.actions}>
            <TouchableOpacity 
              onPress={() => handleReport(item.id, 'dismiss')}
              style={[styles.button, styles.dismissButton]}
            >
              <Text>忽略</Text>
            </TouchableOpacity>
            
            <TouchableOpacity 
              onPress={() => handleReport(item.id, 'ban_user')}
              style={[styles.button, styles.banButton]}
            >
              <Text>封禁用户</Text>
            </TouchableOpacity>
          </View>
        </View>
      )}
    />
  );
};
```

## 🔒 安全注意事项

### 1. 权限控制
```typescript
// 创建管理员表
CREATE TABLE admins (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  role TEXT CHECK (role IN ('admin', 'moderator')),
  created_at TIMESTAMP DEFAULT NOW()
);

// RLS策略
CREATE POLICY "Only admins can view all users" ON profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM admins 
      WHERE admins.user_id = auth.uid()
    )
  );
```

### 2. 操作日志
```typescript
// 记录所有管理操作
CREATE TABLE admin_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES admins(id),
  action TEXT NOT NULL,
  target_type TEXT,
  target_id UUID,
  details JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);
```

## 📋 总结

### Supabase提供的：
- ✅ 数据库
- ✅ 认证系统
- ✅ 存储服务
- ✅ 实时订阅
- ✅ Studio（基础管理）

### 你需要额外搭建的：
- 🔧 业务管理后台
- 📊 数据统计面板
- 👮 内容审核系统
- 📱 运营工具

### 推荐方案：
1. **初期**: 使用Retool快速搭建
2. **中期**: Next.js + Ant Design Pro
3. **后期**: 定制化管理系统

成本：管理后台可以部署在同一台ECS上，不需要额外服务器！