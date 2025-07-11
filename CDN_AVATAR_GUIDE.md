# 用户头像CDN加速实现指南

## 🤔 什么是CDN域名？

### 传统方式（慢）
```
用户 → 你的服务器 → 返回图片
     ↑_____延迟高_____↑
```

### CDN方式（快）
```
用户 → 最近的CDN节点 → 返回图片
     ↑__延迟低__↑
```

**CDN（内容分发网络）** 会把你的图片缓存到全国各地的服务器上，用户访问时自动连接最近的服务器，大大提升加载速度。

## 📝 实现原理

### 1. 原始URL vs CDN URL
```javascript
// ❌ 原始方式：直接访问你的服务器
const avatarUrl = "https://your-server.com/avatars/user123.jpg"

// ✅ CDN方式：通过CDN域名访问
const avatarUrl = "https://cdn.your-domain.com/avatars/user123.jpg"
```

### 2. 实际存储位置
- 图片实际存储在：阿里云OSS
- CDN自动从OSS获取并缓存
- 用户访问CDN，不直接访问OSS

## 🚀 具体实现步骤

### Step 1: 配置OSS存储

```javascript
// src/services/ossService.ts
import OSS from 'ali-oss';

const client = new OSS({
  region: 'oss-cn-hangzhou',
  accessKeyId: process.env.OSS_ACCESS_KEY_ID,
  accessKeySecret: process.env.OSS_ACCESS_KEY_SECRET,
  bucket: 'groupup-avatars'
});

// 上传头像到OSS
export const uploadAvatar = async (userId: string, file: File) => {
  const fileName = `avatars/${userId}/${Date.now()}.jpg`;
  const result = await client.put(fileName, file);
  
  // 返回OSS地址
  return result.url; // https://groupup-avatars.oss-cn-hangzhou.aliyuncs.com/avatars/user123/1234567890.jpg
};
```

### Step 2: 配置CDN加速

在阿里云控制台：
1. 进入CDN控制台
2. 添加加速域名：`cdn.your-domain.com`
3. 源站类型选择：OSS域名
4. 源站地址：`groupup-avatars.oss-cn-hangzhou.aliyuncs.com`

### Step 3: 代码中使用CDN域名

```javascript
// src/utils/imageHelper.ts

// 将OSS地址转换为CDN地址
export const getCDNUrl = (ossUrl: string): string => {
  // 替换域名
  return ossUrl.replace(
    'groupup-avatars.oss-cn-hangzhou.aliyuncs.com',
    'cdn.your-domain.com'
  );
};

// 使用示例
const avatar = await uploadAvatar(userId, file);
const cdnUrl = getCDNUrl(avatar);
// 结果：https://cdn.your-domain.com/avatars/user123/1234567890.jpg
```

### Step 4: 在应用中使用

```typescript
// src/components/UserAvatar.tsx
import React from 'react';
import { getCDNUrl } from '../utils/imageHelper';

interface UserAvatarProps {
  avatarUrl: string;
  size?: number;
}

export const UserAvatar: React.FC<UserAvatarProps> = ({ avatarUrl, size = 100 }) => {
  // 自动使用CDN地址
  const cdnUrl = getCDNUrl(avatarUrl);
  
  // 添加图片处理参数（阿里云OSS支持）
  const optimizedUrl = `${cdnUrl}?x-oss-process=image/resize,w_${size},h_${size}/format,webp`;
  
  return (
    <img 
      src={optimizedUrl} 
      alt="User Avatar"
      style={{ width: size, height: size, borderRadius: '50%' }}
    />
  );
};
```

## 💡 高级优化技巧

### 1. 自动图片优化
```javascript
// 根据设备自动选择图片质量
const getOptimizedAvatarUrl = (url: string, options: {
  width: number;
  quality?: number;
  format?: 'webp' | 'jpg';
}) => {
  const { width, quality = 80, format = 'webp' } = options;
  
  // 阿里云OSS图片处理
  const params = [
    `image/resize,w_${width}`,
    `image/quality,q_${quality}`,
    `image/format,${format}`
  ].join('/');
  
  return `${getCDNUrl(url)}?x-oss-process=${params}`;
};
```

### 2. 缓存策略
```javascript
// 设置长期缓存
const avatarWithCache = (url: string) => {
  // 添加版本号实现缓存更新
  const version = new Date().getTime();
  return `${url}?v=${version}`;
};
```

### 3. 懒加载实现
```typescript
// src/components/LazyAvatar.tsx
import { useState, useEffect } from 'react';

export const LazyAvatar = ({ src, placeholder }: { src: string; placeholder: string }) => {
  const [imageSrc, setImageSrc] = useState(placeholder);
  
  useEffect(() => {
    const img = new Image();
    img.src = getCDNUrl(src);
    img.onload = () => {
      setImageSrc(getCDNUrl(src));
    };
  }, [src]);
  
  return <img src={imageSrc} alt="Avatar" />;
};
```

## 📊 性能对比

| 指标 | 不用CDN | 使用CDN | 提升 |
|------|---------|---------|------|
| 首次加载 | 2-3秒 | 0.3-0.5秒 | 80% |
| 重复访问 | 1-2秒 | <0.1秒 | 95% |
| 服务器带宽 | 100% | 20% | 节省80% |
| 用户体验 | 卡顿 | 流畅 | 显著提升 |

## 🛠️ 实际配置示例

### 1. 环境变量配置
```bash
# .env.production
OSS_ACCESS_KEY_ID=your_access_key
OSS_ACCESS_KEY_SECRET=your_secret_key
OSS_BUCKET=groupup-avatars
CDN_DOMAIN=https://cdn.your-domain.com
```

### 2. 统一处理服务
```typescript
// src/services/imageService.ts
class ImageService {
  private cdnDomain = process.env.CDN_DOMAIN;
  
  // 上传并返回CDN地址
  async uploadUserAvatar(userId: string, file: File): Promise<string> {
    // 1. 上传到OSS
    const ossUrl = await uploadToOSS(file);
    
    // 2. 转换为CDN地址
    const cdnUrl = this.convertToCDN(ossUrl);
    
    // 3. 保存到数据库
    await updateUserAvatar(userId, cdnUrl);
    
    return cdnUrl;
  }
  
  // 获取优化后的头像URL
  getAvatarUrl(url: string, size: 'small' | 'medium' | 'large' = 'medium'): string {
    const sizes = {
      small: 50,
      medium: 100,
      large: 200
    };
    
    return `${url}?x-oss-process=image/resize,w_${sizes[size]}/format,webp`;
  }
  
  private convertToCDN(ossUrl: string): string {
    const ossPattern = /https:\/\/[\w-]+\.oss-[\w-]+\.aliyuncs\.com/;
    return ossUrl.replace(ossPattern, this.cdnDomain);
  }
}

export const imageService = new ImageService();
```

### 3. 在React Native中使用
```typescript
// src/screens/ProfileScreen.tsx
import { imageService } from '../services/imageService';

const ProfileScreen = () => {
  const [avatar, setAvatar] = useState('');
  
  const handleAvatarUpload = async (file: File) => {
    try {
      // 上传并获取CDN地址
      const cdnUrl = await imageService.uploadUserAvatar(user.id, file);
      setAvatar(cdnUrl);
    } catch (error) {
      console.error('Upload failed:', error);
    }
  };
  
  return (
    <View>
      <Image 
        source={{ uri: imageService.getAvatarUrl(avatar, 'large') }}
        style={styles.avatar}
      />
    </View>
  );
};
```

## ⚠️ 注意事项

1. **CDN刷新延迟**
   - 更新头像后可能有5-10分钟延迟
   - 可以通过添加时间戳参数强制刷新

2. **跨域问题**
   - 需要在CDN配置CORS headers
   - 允许你的应用域名访问

3. **成本控制**
   - CDN按流量计费
   - 设置合理的缓存时间（建议30天）
   - 使用WebP格式减少流量

4. **备用方案**
   ```javascript
   // CDN失败时的降级处理
   const getImageUrl = (url: string) => {
     return new Promise((resolve) => {
       const img = new Image();
       img.onload = () => resolve(getCDNUrl(url));
       img.onerror = () => resolve(url); // 降级到原始URL
       img.src = getCDNUrl(url);
     });
   };
   ```

这样实现后，用户头像加载速度会提升80%以上，同时节省大量服务器带宽！