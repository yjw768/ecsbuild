// GroupUp API Service
const API_BASE_URL = process.env.EXPO_PUBLIC_API_URL || 'http://8.148.211.17:8000/api/v1';

export interface User {
  id: string;
  username: string;
  display_name: string;
  age: number;
  bio: string;
  avatar_url?: string;
  location_lat?: number;
  location_lng?: number;
  interests: string[];
  created_at: string;
  updated_at: string;
}

export interface SwipeAction {
  id: string;
  user_id: string;
  target_user_id: string;
  action: 'like' | 'pass';
  created_at: string;
  matched?: boolean;
}

export interface Match {
  id: string;
  user1_id: string;
  user2_id: string;
  matched_at: string;
  last_message_at?: string;
  user1_username?: string;
  user1_display_name?: string;
  user1_avatar?: string;
  user2_username?: string;
  user2_display_name?: string;
  user2_avatar?: string;
}

export interface Message {
  id: string;
  match_id: string;
  sender_id: string;
  content: string;
  image_url?: string;
  read: boolean;
  created_at: string;
}

class ApiService {
  private async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${API_BASE_URL}${endpoint}`;
    
    const response = await fetch(url, {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
      ...options,
    });

    if (!response.ok) {
      throw new Error(`API Error: ${response.status} ${response.statusText}`);
    }

    return response.json();
  }

  // 健康检查
  async healthCheck() {
    return this.request('/health');
  }

  // 用户相关
  async getUsers(): Promise<User[]> {
    return this.request('/users');
  }

  async getUser(id: string): Promise<User> {
    return this.request(`/users/${id}`);
  }

  async createUser(user: Omit<User, 'id' | 'created_at' | 'updated_at'>): Promise<User> {
    return this.request('/users', {
      method: 'POST',
      body: JSON.stringify(user),
    });
  }

  // 滑动相关
  async recordSwipe(swipe: {
    user_id: string;
    target_user_id: string;
    action: 'like' | 'pass';
  }): Promise<SwipeAction> {
    return this.request('/swipes', {
      method: 'POST',
      body: JSON.stringify(swipe),
    });
  }

  // 匹配相关
  async getMatches(userId: string): Promise<Match[]> {
    return this.request(`/matches/${userId}`);
  }

  // 消息相关
  async getMessages(matchId: string): Promise<Message[]> {
    return this.request(`/messages/${matchId}`);
  }

  async sendMessage(message: {
    match_id: string;
    sender_id: string;
    content: string;
  }): Promise<Message> {
    return this.request('/messages', {
      method: 'POST',
      body: JSON.stringify(message),
    });
  }
}

export const apiService = new ApiService();
export default apiService;