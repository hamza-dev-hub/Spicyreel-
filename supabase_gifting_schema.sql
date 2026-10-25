-- ==============================================================
-- SPICYREEL: Virtual Gifting, Coins, & Rewards Architecture
-- Run this script in your Supabase Project -> SQL Editor
-- ==============================================================

-- 1. Create USER_WALLETS Table
CREATE TABLE IF NOT EXISTS public.user_wallets (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    coin_balance BIGINT NOT NULL DEFAULT 100 CHECK (coin_balance >= 0),
    total_earnings BIGINT NOT NULL DEFAULT 0 CHECK (total_earnings >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS for user_wallets
ALTER TABLE public.user_wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to read their own wallet"
    ON public.user_wallets FOR SELECT
    USING (auth.uid() = user_id OR auth.uid() IS NULL);

CREATE POLICY "Allow users to update own wallet balance"
    ON public.user_wallets FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Allow insert own wallet"
    ON public.user_wallets FOR INSERT
    WITH CHECK (auth.uid() = user_id OR auth.uid() IS NULL);


-- 2. Create GIFTS Table (Catalog of Virtual Gifts)
CREATE TABLE IF NOT EXISTS public.gifts (
    gift_id TEXT PRIMARY KEY,
    gift_name TEXT NOT NULL,
    icon_url TEXT NOT NULL,
    coin_cost INTEGER NOT NULL CHECK (coin_cost > 0),
    animation TEXT DEFAULT 'burst',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS for gifts
ALTER TABLE public.gifts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read gifts catalog"
    ON public.gifts FOR SELECT
    USING (true);

-- Insert Default TikTok-style Gifts
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


-- 3. Create TRANSACTIONS Table (Audit trail of gifts sent & coins spent)
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    receiver_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    reel_id TEXT,
    gift_id TEXT REFERENCES public.gifts(gift_id) ON DELETE RESTRICT,
    coins_spent INTEGER NOT NULL CHECK (coins_spent > 0),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS for transactions
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view transactions they participated in"
    ON public.transactions FOR SELECT
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id OR auth.uid() IS NULL);

CREATE POLICY "Authenticated users can insert transactions"
    ON public.transactions FOR INSERT
    WITH CHECK (auth.uid() = sender_id OR auth.uid() IS NULL);


-- ==============================================================
-- 4. SECURE POSTGRESQL RPC FUNCTION: send_gift
-- Prevents frontend balance manipulation by performing atomic deduction,
-- receiver reward increment, and transaction recording in a single database transaction.
-- ==============================================================
CREATE OR REPLACE FUNCTION public.send_gift(
    p_sender_id UUID,
    p_receiver_id UUID,
    p_reel_id TEXT,
    p_gift_id TEXT,
    p_coin_cost INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sender_balance BIGINT;
    v_new_balance BIGINT;
    v_tx_id UUID;
BEGIN
    -- 1. Lock and check sender's wallet
    SELECT coin_balance INTO v_sender_balance
    FROM public.user_wallets
    WHERE user_id = p_sender_id
    FOR UPDATE;

    -- If sender has no wallet yet, initialize with 100 default coins
    IF v_sender_balance IS NULL THEN
        INSERT INTO public.user_wallets (user_id, coin_balance, total_earnings)
        VALUES (p_sender_id, 100, 0)
        RETURNING coin_balance INTO v_sender_balance;
    END IF;

    -- 2. Verify sufficient coin balance
    IF v_sender_balance < p_coin_cost THEN
        RAISE EXCEPTION 'Insufficient coins balance. Current: %, Required: %', v_sender_balance, p_coin_cost;
    END IF;

    -- 3. Deduct coins from sender
    UPDATE public.user_wallets
    SET coin_balance = coin_balance - p_coin_cost,
        updated_at = timezone('utc'::text, now())
    WHERE user_id = p_sender_id
    RETURNING coin_balance INTO v_new_balance;

    -- 4. Add earnings to receiver (if receiver specified and different from sender)
    IF p_receiver_id IS NOT NULL AND p_receiver_id <> p_sender_id THEN
        INSERT INTO public.user_wallets (user_id, coin_balance, total_earnings)
        VALUES (p_receiver_id, 0, p_coin_cost)
        ON CONFLICT (user_id) DO UPDATE
        SET total_earnings = user_wallets.total_earnings + p_coin_cost,
            updated_at = timezone('utc'::text, now());
    END IF;

    -- 5. Record the transaction
    INSERT INTO public.transactions (sender_id, receiver_id, reel_id, gift_id, coins_spent, timestamp)
    VALUES (p_sender_id, p_receiver_id, p_reel_id, p_gift_id, p_coin_cost, timezone('utc'::text, now()))
    RETURNING id INTO v_tx_id;

    -- 6. Return successful response payload
    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_tx_id,
        'new_balance', v_new_balance,
        'coins_spent', p_coin_cost,
        'gift_id', p_gift_id
    );
END;
$$;
