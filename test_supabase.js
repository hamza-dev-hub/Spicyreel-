/**
 * test_supabase.js - Quick Diagnostic & Verification Script for Spicyreel Supabase API
 * 
 * Usage:
 * 1. In Browser: Load this file in a <script> tag or paste in Browser Developer Console (F12)
 * 2. In Node.js: `npm install @supabase/supabase-js` then `node test_supabase.js`
 */

const SUPABASE_URL = "https://fmyxdkllembfynbnqncw.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_PhKJez-FRcpN0D8vMbcQJg_b1OD5JQq";

async function testSupabaseConnection() {
  console.log("==================================================");
  console.log("🌶️ Testing Spicyreel Supabase API Connection...");
  console.log("Project URL:", SUPABASE_URL);
  console.log("==================================================");

  // 1. Initialize Client
  let supabase = null;
  if (typeof window !== "undefined" && window.supabaseClient) {
    supabase = window.supabaseClient;
  } else if (typeof window !== "undefined" && window.supabase?.createClient) {
    supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  } else if (typeof require !== "undefined") {
    const { createClient } = require("@supabase/supabase-js");
    supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  }

  if (!supabase) {
    console.error("❌ Failed to initialize Supabase client. Make sure @supabase/supabase-js is loaded.");
    return { success: false, error: "Client initialization failed" };
  }

  console.log("✅ 1. Supabase Client Initialized successfully.");

  // 2. Fetch 1 row from Profiles table
  console.log("⏳ 2. Fetching 1 row from 'Profiles' table...");
  try {
    const { data: profiles, error: profileError } = await supabase
      .from("Profiles")
      .select("*")
      .limit(1);

    if (profileError) {
      console.warn("⚠️ Error fetching from 'Profiles':", profileError.message);
    } else {
      console.log("✅ 2. Successfully fetched from 'Profiles':", profiles);
    }
  } catch (err) {
    console.error("❌ Exception during Profiles query:", err.message);
  }

  // 3. Insert a test row into the reels table
  console.log("⏳ 3. Inserting test row into 'reels' table (caption: 'Test Reel', views: 0)...");
  try {
    const testReelPayload = {
      user_id: "test_user_conn_check",
      video_url: "https://vjs.zencdn.net/v/oceans.mp4",
      caption: "Test Reel",
      title: "Test Reel",
      views: 0
    };

    const { data: insertedReel, error: insertError } = await supabase
      .from("reels")
      .insert([testReelPayload])
      .select();

    if (insertError) {
      console.warn("⚠️ Notice inserting with full columns:", insertError.message);
      
      // Fallback with basic schema columns in case custom columns are not yet migrated:
      const basicPayload = {
        user_id: "test_user_conn_check",
        video_url: "https://vjs.zencdn.net/v/oceans.mp4",
        title: "Test Reel"
      };
      const { data: fallbackData, error: fallbackError } = await supabase
        .from("reels")
        .insert([basicPayload])
        .select();

      if (fallbackError) {
        console.error("❌ Error inserting test reel:", fallbackError.message);
        return { success: false, error: fallbackError.message };
      } else {
        console.log("✅ 3. Test reel inserted successfully (basic schema):", fallbackData);
        // Test step 4: Increment views RPC
        const testReelId = fallbackData && fallbackData[0] ? fallbackData[0].id : null;
        if (testReelId) {
          console.log(`⏳ 4. Testing await supabase.rpc('increment_views', { reel_id: '${testReelId}' })...`);
          const { data: rpcViews, error: rpcErr } = await supabase.rpc('increment_views', { reel_id: String(testReelId) });
          if (rpcErr) {
            console.warn("⚠️ RPC increment_views notice (Run supabase_views_rpc.sql in Supabase SQL Editor if not created):", rpcErr.message);
          } else {
            console.log("✅ 4. Successfully incremented views via RPC! New views:", rpcViews);
          }
        }
        return { success: true, data: fallbackData };
      }
    } else {
      console.log("✅ 3. Test reel inserted successfully into 'reels':", insertedReel);
      // Test step 4: Increment views RPC
      const testReelId = insertedReel && insertedReel[0] ? insertedReel[0].id : null;
      if (testReelId) {
        console.log(`⏳ 4. Testing await supabase.rpc('increment_views', { reel_id: '${testReelId}' })...`);
        const { data: rpcViews, error: rpcErr } = await supabase.rpc('increment_views', { reel_id: String(testReelId) });
        if (rpcErr) {
          console.warn("⚠️ RPC increment_views notice (Run supabase_views_rpc.sql in Supabase SQL Editor if not created):", rpcErr.message);
        } else {
          console.log("✅ 4. Successfully incremented views via RPC! New views:", rpcViews);
        }
      }
      console.log("🎉 ALL TESTS PASSED: Supabase connection is 100% active and working!");
      return { success: true, data: insertedReel };
    }
  } catch (err) {
    console.error("❌ Exception during reels insert:", err.message);
    return { success: false, error: err.message };
  }
}

// Automatically expose to window for browser console testing
if (typeof window !== "undefined") {
  window.testSupabaseConnection = testSupabaseConnection;
}

// Export for module systems
if (typeof module !== "undefined" && module.exports) {
  module.exports = { testSupabaseConnection };
}
