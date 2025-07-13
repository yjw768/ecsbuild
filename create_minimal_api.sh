#!/bin/bash

# 创建最小可行API服务
ECS_HOST="8.148.211.17"
ECS_USER="root"
ECS_PASSWORD="Yjw202202@"

echo "=== 创建最小可行API ==="

# 创建简单的API服务
cat > /tmp/create_api.sh << 'EOF'
#!/bin/bash
cd /opt/groupup

echo "创建简单的Node.js API服务..."

# 创建简单的API server
cat > simple-api.js << 'JS'
const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
const port = 3001;

// 数据库连接
const pool = new Pool({
  user: 'postgres',
  host: 'groupup-postgres',
  database: 'postgres',
  password: 'groupup2024',
  port: 5432,
});

// 中间件
app.use(cors());
app.use(express.json());

// 健康检查
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'GroupUp API' });
});

// 获取用户列表
app.get('/users', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM profiles ORDER BY created_at DESC');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

// 获取单个用户
app.get('/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('SELECT * FROM profiles WHERE id = $1', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

// 创建用户资料
app.post('/users', async (req, res) => {
  try {
    const { username, display_name, age, bio, interests } = req.body;
    const id = require('crypto').randomUUID();
    
    const result = await pool.query(
      'INSERT INTO profiles (id, username, display_name, age, bio, interests) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
      [id, username, display_name, age, bio, interests]
    );
    
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

// 记录滑动操作
app.post('/swipes', async (req, res) => {
  try {
    const { user_id, target_user_id, action } = req.body;
    
    const result = await pool.query(
      'INSERT INTO swipe_actions (user_id, target_user_id, action) VALUES ($1, $2, $3) ON CONFLICT (user_id, target_user_id) DO UPDATE SET action = $3 RETURNING *',
      [user_id, target_user_id, action]
    );
    
    // 检查是否匹配
    if (action === 'like') {
      const matchCheck = await pool.query(
        'SELECT * FROM swipe_actions WHERE user_id = $1 AND target_user_id = $2 AND action = $3',
        [target_user_id, user_id, 'like']
      );
      
      if (matchCheck.rows.length > 0) {
        // 创建匹配
        await pool.query(
          'INSERT INTO matches (user1_id, user2_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
          [user_id, target_user_id]
        );
        res.json({ ...result.rows[0], matched: true });
      } else {
        res.json({ ...result.rows[0], matched: false });
      }
    } else {
      res.json({ ...result.rows[0], matched: false });
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

// 获取匹配列表
app.get('/matches/:user_id', async (req, res) => {
  try {
    const { user_id } = req.params;
    const result = await pool.query(`
      SELECT m.*, 
             p1.username as user1_username, p1.display_name as user1_display_name, p1.avatar_url as user1_avatar,
             p2.username as user2_username, p2.display_name as user2_display_name, p2.avatar_url as user2_avatar
      FROM matches m
      JOIN profiles p1 ON m.user1_id = p1.id
      JOIN profiles p2 ON m.user2_id = p2.id
      WHERE m.user1_id = $1 OR m.user2_id = $1
      ORDER BY m.matched_at DESC
    `, [user_id]);
    
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

// 发送消息
app.post('/messages', async (req, res) => {
  try {
    const { match_id, sender_id, content } = req.body;
    
    const result = await pool.query(
      'INSERT INTO messages (match_id, sender_id, content) VALUES ($1, $2, $3) RETURNING *',
      [match_id, sender_id, content]
    );
    
    // 更新匹配的最后消息时间
    await pool.query(
      'UPDATE matches SET last_message_at = NOW() WHERE id = $1',
      [match_id]
    );
    
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

// 获取消息列表
app.get('/messages/:match_id', async (req, res) => {
  try {
    const { match_id } = req.params;
    const result = await pool.query(
      'SELECT * FROM messages WHERE match_id = $1 ORDER BY created_at ASC',
      [match_id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

app.listen(port, '0.0.0.0', () => {
  console.log(`GroupUp API server running on port ${port}`);
});
JS

# 创建package.json
cat > package.json << 'JSON'
{
  "name": "groupup-api",
  "version": "1.0.0",
  "main": "simple-api.js",
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.8.0",
    "cors": "^2.8.5"
  },
  "scripts": {
    "start": "node simple-api.js"
  }
}
JSON

# 创建Dockerfile
cat > Dockerfile << 'DOCKER'
FROM node:18-alpine

WORKDIR /app

COPY package.json .
RUN npm install

COPY simple-api.js .

EXPOSE 3001

CMD ["npm", "start"]
DOCKER

echo "构建API镜像..."
docker build -t groupup-api .

echo "启动API服务..."
docker run -d \
  --name groupup-api \
  --network groupup-network \
  -p 3001:3001 \
  --add-host=groupup-postgres:172.17.0.1 \
  groupup-api

echo "等待API服务启动..."
sleep 10

echo "测试API服务..."
curl -s http://localhost:3001/health || echo "API可能还在启动"

echo "更新Kong配置..."
cat > kong.yml << 'KONG'
_format_version: "2.1"

services:
  - name: api-v1
    url: http://172.17.0.1:3001
    routes:
      - name: api-v1-all
        strip_path: true
        paths:
          - /api/v1

plugins:
  - name: cors
    config:
      origins:
        - "*"
      methods:
        - GET
        - POST
        - PUT
        - DELETE
        - OPTIONS
        - HEAD
        - PATCH
      headers:
        - Accept
        - Content-Type
        - Authorization
        - apikey
      credentials: true
      max_age: 3600
KONG

echo "重启Kong..."
docker restart groupup-kong

sleep 10

echo "测试Kong路由..."
curl -s http://localhost:8000/api/v1/health || echo "Kong路由可能还在配置"

echo ""
echo "====================================="
echo "最小API部署完成！"
echo "====================================="
echo "API端点："
echo "- 健康检查: http://${ECS_HOST}:8000/api/v1/health"
echo "- 用户列表: http://${ECS_HOST}:8000/api/v1/users"
echo "- Supabase Studio: http://${ECS_HOST}:3000"
echo "====================================="
EOF

# 执行脚本
echo "开始创建API..."
sshpass -p "${ECS_PASSWORD}" scp -o StrictHostKeyChecking=no /tmp/create_api.sh ${ECS_USER}@${ECS_HOST}:/tmp/
sshpass -p "${ECS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${ECS_USER}@${ECS_HOST} "cd /opt/groupup && bash /tmp/create_api.sh"

# 清理
rm -f /tmp/create_api.sh

echo ""
echo "API创建完成！"