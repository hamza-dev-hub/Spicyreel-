-- ==============================================================================
-- 🌶️ SPICYREEL: COMPLETE MASTER SUPABASE DATABASE & STORAGE SETUP
-- ==============================================================================
-- Run this ENTIRE script in your Supabase Dashboard -> SQL Editor and click "RUN".
-- It sets up:
-- 1. Storage Buckets ('reels-videos', 'avatars', 'reels-photos') with public access
-- 2. Profiles table (with user_id, email, username, avatar_url, display_name, bio)
-- 3. Reels table (with video_url, caption, title, views, counts)
-- 4. Likes & Comments tables
-- 5. Virtual Gifting & Wallets tables
-- 6. Automatic Views Counter RPC ('increment_views')
-- 7. 100% Permissive RLS Policies so all data saves without any permission blocks!
-- ==============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- 1. STORAGE BUCKETS (Videos & Photos)
-- ──────────────────────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('reels-videos', 'reels-videos', true, 104857600, ARRAY['video/mp4', 'video/webm', 'video/quicktime', 'video/*', 'image/*']),
    ('avatars', 'avatars', true, 10485760, ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/*']),
    ('reels-photos', 'reels-photos', true, 20971520, ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/*'])
ON CONFLICT (id) DO UPDATE 
SET public = true,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage RLS Policies (Allow anyone to read, upload, and update objects)
DROP POLICY IF EXISTS "Public Storage Read Access" ON storage.objects;
DROP POLICY IF EXISTS "Public Storage Upload Access" ON storage.objects;
DROP POLICY IF EXISTS "Public Storage Update Access" ON storage.objects;
DROP POLICY IF EXISTS "Public Storage Delete Access" ON storage.objects;

CREATE POLICY "Public Storage Read Access" ON storage.objects FOR SELECT USING (true);
CREATE POLICY "Public Storage Upload Access" ON storage.objects FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Storage Update Access" ON storage.objects FOR UPDATE USING (true);
CREATE POLICY "Public Storage Delete Access" ON storage.objects FOR DELETE USING (true);


-- ──────────────────────────────────────────────────────────────────────────────
-- 2. PROFILES TABLE (User Profile, Gmail/Email, Avatars)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public."Profiles" (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    username TEXT,
    email TEXT,
    display_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Ensure user_id has unique index for upserts
CREATE UNIQUE INDEX IF NOT EXISTS profiles_user_id_idx ON public."Profiles"(user_id);

-- Safely add missing columns to Profiles
ALTER TABLE public."Profiles" ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public."Profiles" ADD COLUMN IF NOT EXISTS display_name TEXT;
ALTER TABLE public."Profiles" ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public."Profiles" ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE public."Profiles" ADD COLUMN IF NOT EXISTS username TEXT;

-- Enable RLS & grant 100% public access
ALTER TABLE public."Profiles" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow Public Read on Profiles" ON public."Profiles";
DROP POLICY IF EXISTS "Allow Public Insert on Profiles" ON public."Profiles";
DROP POLICY IF EXISTS "Allow Public Update on Profiles" ON public."Profiles";

CREATE POLICY "Allow Public Read on Profiles" ON public."Profiles" FOR SELECT USING (true);
CREATE POLICY "Allow Public Insert on Profiles" ON public."Profiles" FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow Public Update on Profiles" ON public."Profiles" FOR UPDATE USING (true);

-- Also create lowercase 'profiles' view for complete compatibility
CREATE OR REPLACE VIEW public.profiles AS SELECT * FROM public."Profiles";


-- ──────────────────────────────────────────────────────────────────────────────
-- 3. REELS TABLE (Uploaded Videos & Metadata)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.reels (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    video_url TEXT NOT NULL,
    title TEXT,
    caption TEXT,
    description TEXT,
    views BIGINT DEFAULT 0,
    like_count BIGINT DEFAULT 0,
    likes_count BIGINT DEFAULT 0,
    comments_count BIGINT DEFAULT 0,
    hashtags TEXT[],
    location TEXT,
    privacy TEXT DEFAULT 'public',
    sound_title TEXT DEFAULT 'Original Audio',
    sound_url TEXT,
    is_approved BOOLEAN DEFAULT true,
    is_flagged BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Safely add missing columns
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS caption TEXT;
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS views BIGINT DEFAULT 0;
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS likes_count BIGINT DEFAULT 0;
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS like_count BIGINT DEFAULT 0;
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS comments_count BIGINT DEFAULT 0;
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS hashtags TEXT[];
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS privacy TEXT DEFAULT 'public';
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS sound_title TEXT DEFAULT 'Original Audio';
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS sound_url TEXT;

-- Enable RLS & grant 100% public access
ALTER TABLE public.reels ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow Public Read on reels" ON public.reels;
DROP POLICY IF EXISTS "Allow Public Insert on reels" ON public.reels;
DROP POLICY IF EXISTS "Allow Public Update on reels" ON public.reels;

CREATE POLICY "Allow Public Read on reels" ON public.reels FOR SELECT USING (true);
CREATE POLICY "Allow Public Insert on reels" ON public.reels FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow Public Update on reels" ON public.reels FOR UPDATE USING (true);


-- ──────────────────────────────────────────────────────────────────────────────
-- 4. LIKES & COMMENTS TABLES
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.likes (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    reel_id TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS likes_user_reel_idx ON public.likes(user_id, reel_id);
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow Public All on likes" ON public.likes;
CREATE POLICY "Allow Public All on likes" ON public.likes FOR ALL USING (true) WITH CHECK (true);

-- Also support reel_likes table/alias
CREATE TABLE IF NOT EXISTS public.reel_likes (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    reel_id TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS reel_likes_user_reel_idx ON public.reel_likes(user_id, reel_id);
ALTER TABLE public.reel_likes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow Public All on reel_likes" ON public.reel_likes;
CREATE POLICY "Allow Public All on reel_likes" ON public.reel_likes FOR ALL USING (true) WITH CHECK (true);

CREATE TABLE IF NOT EXISTS public.comments (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    reel_id TEXT NOT NULL,
    comment_text TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS comments_user_id_idx ON public.comments(user_id);
CREATE INDEX IF NOT EXISTS comments_reel_id_idx ON public.comments(reel_id);

ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow Public All on comments" ON public.comments;
CREATE POLICY "Allow Public All on comments" ON public.comments FOR ALL USING (true) WITH CHECK (true);


-- ──────────────────────────────────────────────────────────────────────────────
-- 5. FAVORITES / BOOKMARKS & FAVORITE SOUNDS TABLES
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.favorites (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    video_id TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS favorites_user_video_idx ON public.favorites(user_id, video_id);
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow Public All on favorites" ON public.favorites;
CREATE POLICY "Allow Public All on favorites" ON public.favorites FOR ALL USING (true) WITH CHECK (true);

-- Also support reel_favorites table/alias
CREATE TABLE IF NOT EXISTS public.reel_favorites (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    reel_id TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS reel_favorites_user_reel_idx ON public.reel_favorites(user_id, reel_id);
ALTER TABLE public.reel_favorites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow Public All on reel_favorites" ON public.reel_favorites;
CREATE POLICY "Allow Public All on reel_favorites" ON public.reel_favorites FOR ALL USING (true) WITH CHECK (true);

-- Favorite Sounds Table
CREATE TABLE IF NOT EXISTS public.user_favorite_sounds (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    sound_id TEXT NOT NULL,
    sound_title TEXT DEFAULT 'Original Audio',
    sound_url TEXT,
    author_name TEXT DEFAULT 'Creator',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS user_favorite_sounds_user_sound_idx ON public.user_favorite_sounds(user_id, sound_id);
ALTER TABLE public.user_favorite_sounds ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow Public All on user_favorite_sounds" ON public.user_favorite_sounds;
CREATE POLICY "Allow Public All on user_favorite_sounds" ON public.user_favorite_sounds FOR ALL USING (true) WITH CHECK (true);


-- ──────────────────────────────────────────────────────────────────────────────
-- 6. VIRTUAL GIFTS & WALLETS TABLES
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_wallets (
    user_id TEXT PRIMARY KEY,
    coin_balance BIGINT DEFAULT 100 NOT NULL,
    total_earnings BIGINT DEFAULT 0 NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.user_wallets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow Public All on wallets" ON public.user_wallets;
CREATE POLICY "Allow Public All on wallets" ON public.user_wallets FOR ALL USING (true) WITH CHECK (true);

CREATE TABLE IF NOT EXISTS public.gifts (
    gift_id TEXT PRIMARY KEY,
    gift_name TEXT NOT NULL,
    icon_url TEXT NOT NULL,
    coin_cost INTEGER NOT NULL,
    animation TEXT DEFAULT 'bounce',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.gifts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow Public All on gifts" ON public.gifts;
CREATE POLICY "Allow Public All on gifts" ON public.gifts FOR ALL USING (true) WITH CHECK (true);

INSERT INTO public.gifts (gift_id, gift_name, icon_url, coin_cost, animation)
VALUES
    ('rose', 'Rose', '🌹', 1, 'float'),
    ('chili', 'Spicy Pepper', '🌶️', 5, 'spin'),
    ('fire_heart', 'Heart on Fire', '❤️‍🔥', 10, 'pulse'),
    ('party', 'Celebration', '🎉', 20, 'confetti'),
    ('diamond', 'Diamond Gem', '💎', 50, 'sparkle'),
    ('lion', 'Golden Lion', '🦁', 100, 'roar'),
    ('rocket', 'Space Rocket', '🚀', 500, 'launch'),
    ('universe', 'Universe Crown', '👑', 1000, 'galaxy')
ON CONFLICT (gift_id) DO UPDATE 
SET gift_name = EXCLUDED.gift_name,
    icon_url = EXCLUDED.icon_url,
    coin_cost = EXCLUDED.coin_cost;

CREATE TABLE IF NOT EXISTS public.transactions (
    id BIGSERIAL PRIMARY KEY,
    sender_id TEXT,
    receiver_id TEXT,
    reel_id TEXT,
    gift_id TEXT,
    coins_spent INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow Public All on transactions" ON public.transactions;
CREATE POLICY "Allow Public All on transactions" ON public.transactions FOR ALL USING (true) WITH CHECK (true);


-- ──────────────────────────────────────────────────────────────────────────────
-- 7. RPC FUNCTION: increment_views (Atomic Views Counter)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.increment_views(reel_id TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_views BIGINT;
BEGIN
    UPDATE public.reels
    SET views = COALESCE(views, 0) + 1
    WHERE id::text = reel_id::text
    RETURNING views INTO new_views;

    RETURN COALESCE(new_views, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.increment_reel_views(reel_id TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.increment_views(reel_id);
END;
$$;

-- Grant permissions to public anon & authenticated users
GRANT EXECUTE ON FUNCTION public.increment_views(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.increment_reel_views(TEXT) TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;


-- ──────────────────────────────────────────────────────────────────────────────
-- 8. AUTH TRIGGER: Auto-save Flutter / Web Auth Metadata to Profiles Table
-- ──────────────────────────────────────────────────────────────────────────────
-- When Flutter supabase.auth.signUp() sends `data: {'full_name': ..., 'avatar_url': ...}`,
-- this trigger immediately inserts the user into public.profiles and public."Profiles".
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_full_name TEXT;
    v_avatar_url TEXT;
    v_username TEXT;
BEGIN
    v_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', NEW.raw_user_meta_data->>'display_name', 'Spicy Creator');
    v_avatar_url := COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'photo_url', '');
    v_username := COALESCE(NEW.raw_user_meta_data->>'username', split_part(COALESCE(NEW.email, 'creator'), '@', 1));

    -- 1. Populate public.profiles (lowercase standard schema) if it exists
    BEGIN
        INSERT INTO public.profiles (
            id,
            email,
            full_name,
            avatar_url,
            username,
            updated_at
        ) VALUES (
            NEW.id,
            NEW.email,
            v_full_name,
            v_avatar_url,
            v_username,
            now()
        )
        ON CONFLICT (id) DO UPDATE SET
            full_name = EXCLUDED.full_name,
            avatar_url = CASE WHEN EXCLUDED.avatar_url <> '' THEN EXCLUDED.avatar_url ELSE public.profiles.avatar_url END,
            updated_at = now();
    EXCEPTION WHEN OTHERS THEN
        NULL; -- Ignore if table or columns differ
    END;

    -- 2. Populate public."Profiles" (Spicyreel app schema)
    BEGIN
        INSERT INTO public."Profiles" (
            user_id,
            email,
            display_name,
            username,
            avatar_url
        ) VALUES (
            NEW.id::text,
            NEW.email,
            v_full_name,
            v_username,
            v_avatar_url
        )
        ON CONFLICT (user_id) DO UPDATE SET
            display_name = EXCLUDED.display_name,
            avatar_url = CASE WHEN EXCLUDED.avatar_url <> '' THEN EXCLUDED.avatar_url ELSE public."Profiles".avatar_url END,
            email = EXCLUDED.email;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Bind trigger to auth.users table
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
