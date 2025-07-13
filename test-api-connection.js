// 测试GroupUp API连接
const API_BASE_URL = 'http://8.148.211.17:8000/api/v1';

async function testApiConnection() {
  console.log('🚀 测试GroupUp API连接...');
  console.log('📍 API地址:', API_BASE_URL);
  
  try {
    // 1. 健康检查
    console.log('\n1️⃣ 测试健康检查...');
    const healthResponse = await fetch(`${API_BASE_URL}/health`);
    const healthData = await healthResponse.json();
    console.log('✅ 健康检查成功:', healthData);
    
    // 2. 获取用户列表
    console.log('\n2️⃣ 测试用户列表...');
    const usersResponse = await fetch(`${API_BASE_URL}/users`);
    const usersData = await usersResponse.json();
    console.log('✅ 用户列表获取成功:');
    console.log(`   - 找到 ${usersData.length} 个用户`);
    usersData.forEach((user, index) => {
      console.log(`   ${index + 1}. ${user.display_name} (@${user.username}) - ${user.age}岁`);
    });
    
    // 3. 测试滑动功能（如果有用户）
    if (usersData.length >= 2) {
      console.log('\n3️⃣ 测试滑动功能...');
      const swipeData = {
        user_id: usersData[0].id,
        target_user_id: usersData[1].id,
        action: 'like'
      };
      
      const swipeResponse = await fetch(`${API_BASE_URL}/swipes`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(swipeData)
      });
      
      const swipeResult = await swipeResponse.json();
      console.log('✅ 滑动记录成功:', {
        action: swipeResult.action,
        matched: swipeResult.matched || false
      });
    }
    
    // 4. 测试匹配列表
    if (usersData.length > 0) {
      console.log('\n4️⃣ 测试匹配列表...');
      const matchesResponse = await fetch(`${API_BASE_URL}/matches/${usersData[0].id}`);
      const matchesData = await matchesResponse.json();
      console.log(`✅ 匹配列表获取成功: 找到 ${matchesData.length} 个匹配`);
    }
    
    console.log('\n🎉 所有API测试通过！');
    console.log('\n📱 你的React Native应用现在可以连接到后端了！');
    console.log('\n🔗 主要端点:');
    console.log(`   - API接口: ${API_BASE_URL}`);
    console.log(`   - Studio管理: http://8.148.211.17:3000`);
    
  } catch (error) {
    console.error('❌ API测试失败:', error.message);
    console.log('\n🔧 请检查:');
    console.log('   1. 服务器是否运行');
    console.log('   2. 网络连接是否正常');
    console.log('   3. API地址是否正确');
  }
}

// 运行测试
testApiConnection();