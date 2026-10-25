-- ==============================================================
-- SPICYREEL: Automatic Reel Views Counter RPC Function
-- Run this script in your Supabase Project -> SQL Editor
-- ==============================================================

-- 1. Ensure 'views' column exists in public.reels table
ALTER TABLE public.reels ADD COLUMN IF NOT EXISTS views BIGINT DEFAULT 0;

-- 2. Primary RPC Function: increment_views(reel_id)
-- Matches: await supabase.rpc('increment_views', { reel_id: currentReelId });
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

-- 3. Alias RPC Function: increment_reel_views(reel_id) (for backward compatibility)
CREATE OR REPLACE FUNCTION public.increment_reel_views(reel_id TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.increment_views(reel_id);
END;
$$;

-- 4. Grant execution permissions to anon, authenticated and service_role
GRANT EXECUTE ON FUNCTION public.increment_views(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.increment_reel_views(TEXT) TO anon, authenticated, service_role;
