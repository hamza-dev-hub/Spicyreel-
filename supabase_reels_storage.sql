-- ==============================================================
-- SPICYREEL: Supabase Storage Bucket ('reels-videos') & Reels Schema
-- Run this in your Supabase Project -> SQL Editor
-- ==============================================================

-- 1. Create 'reels-videos' Public Storage Bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'reels-videos',
    'reels-videos',
    true,
    104857600, -- 100MB limit
    ARRAY['video/mp4', 'video/webm', 'video/quicktime', 'image/jpeg', 'image/png']
)
ON CONFLICT (id) DO UPDATE 
SET public = true,
    allowed_mime_types = ARRAY['video/mp4', 'video/webm', 'video/quicktime', 'image/jpeg', 'image/png'];

-- 2. Storage RLS Policies for 'reels-videos'
-- Anyone can view uploaded videos publicly:
CREATE POLICY "Public Access to reels-videos"
ON storage.objects FOR SELECT
USING (bucket_id = 'reels-videos');

-- Anyone or authenticated users can upload reels videos:
CREATE POLICY "Allow Uploads to reels-videos"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'reels-videos');

-- Users can update or delete their own video files:
CREATE POLICY "Allow User Manage reels-videos"
ON storage.objects FOR UPDATE
USING (bucket_id = 'reels-videos');

CREATE POLICY "Allow User Delete reels-videos"
ON storage.objects FOR DELETE
USING (bucket_id = 'reels-videos');


-- ==============================================================
-- 3. Upgrade REELS Table Schema with Post Details Fields
-- ==============================================================
-- Ensure reels table exists
CREATE TABLE IF NOT EXISTS public.reels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    video_url TEXT NOT NULL,
    title TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Safely add missing columns if they don't exist yet:
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS caption TEXT;
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS hashtags TEXT[];
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS privacy TEXT DEFAULT 'public';
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS sound_title TEXT DEFAULT 'Original Audio';
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS sound_url TEXT;
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS sound_id TEXT;
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT true;
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS is_flagged BOOLEAN DEFAULT false;

-- Enable RLS on reels table
ALTER TABLE public.reels ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read approved reels
CREATE POLICY "Allow anyone to view reels"
ON public.reels FOR SELECT
USING (true);

-- Allow inserting reels
CREATE POLICY "Allow inserting reels"
ON public.reels FOR INSERT
WITH CHECK (true);

-- Allow updating own reels
CREATE POLICY "Allow updating own reels"
ON public.reels FOR UPDATE
USING (auth.uid()::text = user_id OR user_id IS NOT NULL);
