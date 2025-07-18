# 带宽选择指南

## 推荐配置

### 🎯 标准方案：5Mbps固定带宽
- **价格**: ¥100/月
- **适合**: 1000-2000用户日常使用
- **优势**: 
  - 价格固定，成本可控
  - 支持40-50人同时在线
  - 配合CDN够用

### 💡 省钱方案：1Mbps + 按量付费
- **基础带宽**: 1Mbps (¥23/月)
- **弹性流量**: ¥0.8/GB
- **适合**: 
  - 用户活跃时间集中
  - 初期用户较少
  - 想要灵活控制成本

## 配置示例

### 阿里云ECS购买时选择：
```
网络类型: 专有网络
公网IP: 分配
带宽计费: 按固定带宽
带宽值: 5 Mbps
```

### 配合OSS设置：
```javascript
// 客户端直传OSS，减少服务器压力
const config = {
  region: 'oss-cn-hangzhou',
  bucket: 'groupup-photos',
  // 图片自动压缩
  process: 'image/resize,w_800/quality,q_80'
};
```

## 监控和升级

### 带宽监控指标
```bash
# 查看实时带宽使用
iftop -i eth0

# 查看网络统计
vnstat -l

# 阿里云控制台查看
# ECS实例 > 监控 > 网络带宽
```

### 升级时机
- 带宽使用率持续 > 80%
- 用户反馈加载缓慢
- 并发用户超过50人

### 升级方式
1. 阿里云控制台 > ECS实例
2. 更多 > 资源变配 > 升级带宽
3. 立即生效，无需重启

## 费用优化技巧

1. **使用CDN分流**
   - 图片/视频走CDN
   - 可节省70%带宽

2. **启用压缩**
   ```nginx
   gzip on;
   gzip_types text/plain application/json;
   gzip_comp_level 6;
   ```

3. **限制上传大小**
   ```javascript
   const MAX_UPLOAD_SIZE = 5 * 1024 * 1024; // 5MB
   ```

4. **使用WebP格式**
   - 图片体积减少30%
   - 自动转换用户上传图片

## 不同阶段带宽需求

| 用户规模 | 推荐带宽 | 月费用 | 备注 |
|----------|----------|--------|------|
| 0-500 | 3Mbps | ¥71 | 测试阶段 |
| 500-2000 | 5Mbps | ¥100 | 初期运营 |
| 2000-5000 | 10Mbps | ¥200 | 配合CDN |
| 5000+ | 20Mbps+ | ¥400+ | 考虑负载均衡 |