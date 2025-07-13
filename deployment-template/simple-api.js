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
