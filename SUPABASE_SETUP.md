# Supabase Setup Instructions

## Creating the Avatars Storage Bucket

To enable photo uploads in the app, you need to create a storage bucket in Supabase:

### Option 1: Using SQL Editor (Recommended)
1. Go to your Supabase Dashboard: https://supabase.com/dashboard/project/awuojdpmhqsbnlpydmek
2. Navigate to SQL Editor in the left sidebar
3. Copy and paste the contents of `create_storage_bucket.sql`
4. Click "Run" to execute the SQL

### Option 2: Using Storage UI
1. Go to Storage in your Supabase Dashboard
2. Click "Create bucket"
3. Set the following:
   - Bucket name: `avatars`
   - Public bucket: ✓ (checked)
   - File size limit: 5MB
   - Allowed MIME types: image/jpeg, image/jpg, image/png, image/gif, image/webp
4. Click "Create bucket"

## Testing the App

### Test Mode (No Login Required)
1. Run the app: `npx expo start`
2. On the login screen, click "Skip Login (Test Mode)"
3. You'll see 5 test users you can swipe through
4. All features work locally without needing Supabase

### Real Mode (Supabase Required)
1. Ensure you've created test users in your Supabase database
2. Login with one of the test accounts (e.g., alice@test.com / test123)
3. Photo uploads will attempt to use Supabase Storage

## Troubleshooting

### "Bucket not found" error
- Run the SQL script in `create_storage_bucket.sql` to create the bucket

### Photos not displaying after upload
- Check if the bucket is set to public
- Verify the storage policies are correctly set

### No users showing up
- In test mode: This shouldn't happen, check console for errors
- In real mode: Ensure you have users in your database

### Email confirmation issues
- Supabase requires email confirmation by default
- You can disable this in Authentication settings or manually confirm users