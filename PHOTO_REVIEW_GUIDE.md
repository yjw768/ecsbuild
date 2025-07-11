# 用户照片审核实现指南

## 🤖 审核方式对比

### 1. 纯人工审核
```
优点：
- 准确率高
- 能理解上下文

缺点：
- 成本高（需要审核员）
- 速度慢（24小时工作）
- 无法应对大量上传
```

### 2. 纯机器审核
```
优点：
- 速度快（毫秒级）
- 成本低
- 24/7自动化

缺点：
- 可能误判
- 无法理解特殊情况
```

### 3. 机器+人工（推荐）
```
最佳实践：
机器审核 → 过滤90%正常图片 → 人工复审10%可疑图片
```

## 🚀 实现方案

### 方案1：使用阿里云内容安全（推荐）

#### 价格
- 图片审核：¥0.0028/张
- 1000用户×10张 = ¥28/月

#### 实现代码
```typescript
// src/services/contentReview.ts
import { createHmac } from 'crypto';
import axios from 'axios';

export class ContentReviewService {
  private accessKeyId = process.env.ALIYUN_ACCESS_KEY_ID;
  private accessKeySecret = process.env.ALIYUN_ACCESS_KEY_SECRET;

  // 审核单张图片
  async reviewImage(imageUrl: string) {
    const params = {
      url: imageUrl,
      scenes: ['porn', 'terrorism', 'ad', 'qrcode', 'live', 'logo']
    };

    try {
      const response = await axios.post(
        'https://green.cn-shanghai.aliyuncs.com/green/image/scan',
        {
          scenes: params.scenes,
          tasks: [{
            url: imageUrl
          }]
        },
        {
          headers: this.getHeaders()
        }
      );

      const result = response.data.data[0];
      
      return {
        safe: result.results.every(r => r.suggestion === 'pass'),
        details: result.results,
        suggestion: result.suggestion // pass, review, block
      };
    } catch (error) {
      console.error('图片审核失败:', error);
      // 审核失败时，默认需要人工审核
      return {
        safe: false,
        needManualReview: true
      };
    }
  }

  // 批量审核
  async reviewBatch(imageUrls: string[]) {
    const tasks = imageUrls.map(url => ({ url }));
    
    const response = await axios.post(
      'https://green.cn-shanghai.aliyuncs.com/green/image/scan',
      {
        scenes: ['porn', 'terrorism', 'ad'],
        tasks
      },
      {
        headers: this.getHeaders()
      }
    );

    return response.data.data;
  }

  private getHeaders() {
    // 阿里云签名认证
    const date = new Date().toUTCString();
    const signature = this.createSignature(date);
    
    return {
      'Date': date,
      'Authorization': `acs ${this.accessKeyId}:${signature}`,
      'Content-Type': 'application/json'
    };
  }
}
```

### 方案2：使用开源方案（NSFW.js）

#### 免费但准确率较低
```bash
npm install nsfwjs @tensorflow/tfjs-node
```

```typescript
// src/services/nsfwDetection.ts
import * as tf from '@tensorflow/tfjs-node';
import * as nsfwjs from 'nsfwjs';

export class NSFWDetectionService {
  private model: nsfwjs.NSFWJS;

  async initialize() {
    this.model = await nsfwjs.load();
  }

  async checkImage(imagePath: string) {
    const image = await tf.node.decodeImage(
      await fs.readFile(imagePath),
      3
    );

    const predictions = await this.model.classify(image);
    image.dispose();

    // 分析结果
    const nsfwScore = predictions
      .filter(p => ['Porn', 'Sexy'].includes(p.className))
      .reduce((sum, p) => sum + p.probability, 0);

    return {
      safe: nsfwScore < 0.5,
      score: nsfwScore,
      predictions
    };
  }
}
```

## 📱 完整的审核流程实现

### 1. 用户上传时立即审核
```typescript
// src/services/photoUploadService.ts
export class PhotoUploadService {
  constructor(
    private ossService: OSSService,
    private reviewService: ContentReviewService,
    private supabase: SupabaseClient
  ) {}

  async uploadUserPhoto(userId: string, file: File) {
    // 1. 上传到OSS
    const ossUrl = await this.ossService.upload(file);
    
    // 2. 保存记录（标记为待审核）
    const { data: photo } = await this.supabase
      .from('user_photos')
      .insert({
        user_id: userId,
        url: ossUrl,
        status: 'pending', // pending, approved, rejected
        uploaded_at: new Date()
      })
      .select()
      .single();

    // 3. 异步审核
    this.reviewPhoto(photo.id, ossUrl);

    return {
      photoId: photo.id,
      status: 'pending',
      message: '照片上传成功，正在审核中...'
    };
  }

  private async reviewPhoto(photoId: string, imageUrl: string) {
    try {
      // 机器审核
      const reviewResult = await this.reviewService.reviewImage(imageUrl);
      
      if (reviewResult.safe) {
        // 自动通过
        await this.approvePhoto(photoId);
      } else if (reviewResult.suggestion === 'block') {
        // 自动拒绝
        await this.rejectPhoto(photoId, '图片包含违规内容');
      } else {
        // 需要人工审核
        await this.markForManualReview(photoId, reviewResult.details);
      }
    } catch (error) {
      // 审核失败，标记为需要人工审核
      await this.markForManualReview(photoId);
    }
  }

  private async approvePhoto(photoId: string) {
    await this.supabase
      .from('user_photos')
      .update({
        status: 'approved',
        reviewed_at: new Date(),
        review_type: 'auto'
      })
      .eq('id', photoId);

    // 通知用户
    await this.notifyUser(photoId, 'approved');
  }

  private async rejectPhoto(photoId: string, reason: string) {
    await this.supabase
      .from('user_photos')
      .update({
        status: 'rejected',
        reject_reason: reason,
        reviewed_at: new Date(),
        review_type: 'auto'
      })
      .eq('id', photoId);

    // 从OSS删除违规图片
    await this.ossService.delete(photoId);

    // 通知用户
    await this.notifyUser(photoId, 'rejected', reason);
  }
}
```

### 2. 数据库设计
```sql
-- 照片表
CREATE TABLE user_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  url TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'manual_review')),
  uploaded_at TIMESTAMP DEFAULT NOW(),
  reviewed_at TIMESTAMP,
  review_type TEXT CHECK (review_type IN ('auto', 'manual')),
  reject_reason TEXT,
  ai_review_result JSONB, -- 存储AI审核详情
  manual_reviewer_id UUID REFERENCES admins(id)
);

-- 创建索引
CREATE INDEX idx_photos_status ON user_photos(status);
CREATE INDEX idx_photos_user_status ON user_photos(user_id, status);
```

### 3. 人工审核后台
```typescript
// app/admin/photo-review/page.tsx
export default function PhotoReviewPage() {
  const [photos, setPhotos] = useState([]);
  const [currentPhoto, setCurrentPhoto] = useState(null);

  // 获取待审核照片
  const fetchPendingPhotos = async () => {
    const { data } = await supabase
      .from('user_photos')
      .select(`
        *,
        user:user_id(username, age)
      `)
      .eq('status', 'manual_review')
      .order('uploaded_at', { ascending: true })
      .limit(20);
    
    setPhotos(data || []);
    setCurrentPhoto(data?.[0] || null);
  };

  // 审核操作
  const reviewPhoto = async (photoId: string, approved: boolean, reason?: string) => {
    await supabase
      .from('user_photos')
      .update({
        status: approved ? 'approved' : 'rejected',
        reject_reason: reason,
        reviewed_at: new Date(),
        review_type: 'manual',
        manual_reviewer_id: currentAdmin.id
      })
      .eq('id', photoId);

    // 记录审核日志
    await supabase
      .from('review_logs')
      .insert({
        reviewer_id: currentAdmin.id,
        photo_id: photoId,
        action: approved ? 'approve' : 'reject',
        reason
      });

    // 移到下一张
    const nextIndex = photos.findIndex(p => p.id === photoId) + 1;
    setCurrentPhoto(photos[nextIndex] || null);
  };

  return (
    <div className="flex h-screen">
      {/* 左侧：图片预览 */}
      <div className="flex-1 p-8 bg-gray-100">
        {currentPhoto && (
          <div className="max-w-2xl mx-auto">
            <img 
              src={currentPhoto.url} 
              alt="Review"
              className="w-full rounded-lg shadow-lg"
            />
            
            {/* AI审核结果参考 */}
            {currentPhoto.ai_review_result && (
              <div className="mt-4 p-4 bg-white rounded-lg">
                <h3 className="font-bold">AI审核结果：</h3>
                <pre>{JSON.stringify(currentPhoto.ai_review_result, null, 2)}</pre>
              </div>
            )}
          </div>
        )}
      </div>

      {/* 右侧：操作面板 */}
      <div className="w-96 p-8 bg-white shadow-lg">
        {currentPhoto && (
          <>
            <h2 className="text-xl font-bold mb-4">用户信息</h2>
            <div className="mb-6">
              <p>用户名：{currentPhoto.user.username}</p>
              <p>年龄：{currentPhoto.user.age}</p>
              <p>上传时间：{new Date(currentPhoto.uploaded_at).toLocaleString()}</p>
            </div>

            <h3 className="font-bold mb-2">快速操作</h3>
            <div className="space-y-2">
              <button
                onClick={() => reviewPhoto(currentPhoto.id, true)}
                className="w-full p-3 bg-green-500 text-white rounded hover:bg-green-600"
              >
                ✓ 通过 (快捷键: A)
              </button>
              
              <button
                onClick={() => {
                  const reason = prompt('拒绝原因：');
                  if (reason) reviewPhoto(currentPhoto.id, false, reason);
                }}
                className="w-full p-3 bg-red-500 text-white rounded hover:bg-red-600"
              >
                ✗ 拒绝 (快捷键: D)
              </button>

              <button
                onClick={() => setCurrentPhoto(photos[photos.indexOf(currentPhoto) + 1])}
                className="w-full p-3 bg-gray-500 text-white rounded hover:bg-gray-600"
              >
                → 跳过 (快捷键: S)
              </button>
            </div>

            {/* 常用拒绝原因 */}
            <div className="mt-6">
              <h3 className="font-bold mb-2">常用拒绝原因</h3>
              <div className="space-y-1">
                {['涉黄内容', '广告信息', '非真人照片', '模糊不清', '包含他人'].map(reason => (
                  <button
                    key={reason}
                    onClick={() => reviewPhoto(currentPhoto.id, false, reason)}
                    className="w-full p-2 text-left bg-gray-100 hover:bg-gray-200 rounded"
                  >
                    {reason}
                  </button>
                ))}
              </div>
            </div>

            {/* 统计信息 */}
            <div className="mt-6 p-4 bg-gray-100 rounded">
              <h3 className="font-bold mb-2">今日统计</h3>
              <p>已审核：{todayStats.reviewed}</p>
              <p>通过率：{todayStats.approvalRate}%</p>
              <p>待审核：{photos.length}</p>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
```

## 💰 成本对比

| 方案 | 成本 | 准确率 | 速度 |
|------|------|--------|------|
| 纯人工 | ¥3000+/月 | 95% | 慢 |
| 阿里云AI | ¥30-50/月 | 90% | 毫秒级 |
| 开源AI | ¥0 | 70% | 秒级 |
| AI+人工 | ¥100/月 | 98% | 快 |

## 🎯 推荐方案

### 初期（<1000用户）
```
使用开源NSFW.js + 人工抽查
成本：免费
```

### 中期（1000-5000用户）
```
使用阿里云内容安全 + 人工复审
成本：¥50-100/月
```

### 后期（>5000用户）
```
自建审核团队 + AI辅助
成本：按需增长
```

## ⚡ 优化技巧

### 1. 预审核
```typescript
// 客户端预检查
const preCheck = (file: File) => {
  // 检查文件大小
  if (file.size > 5 * 1024 * 1024) {
    return { valid: false, reason: '图片不能超过5MB' };
  }
  
  // 检查图片尺寸
  // 检查图片格式
  
  return { valid: true };
};
```

### 2. 缓存审核结果
```typescript
// 相同图片不重复审核
const imageHash = await calculateHash(imageBuffer);
const cached = await redis.get(`review:${imageHash}`);
if (cached) return cached;
```

### 3. 分级审核
```
低风险用户（信用好）→ 宽松审核
高风险用户（新注册）→ 严格审核
```

这样既保证了安全，又控制了成本！