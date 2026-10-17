// ==========================================
// Edge Function: delete-account (アカウント削除 / 仕様7.5)
//
// 呼び出し元の JWT で本人を特定し、service role で auth.users を削除する。
// public.users への ON DELETE CASCADE (migration 10) により、
// 友達/いいね/通知/テーマ進捗/クーポン/カード/デッキ等の個人データが連鎖削除される。
//
// Service Role Key はこの関数の環境変数にのみ存在し、クライアントには置かない。
// デプロイ:  supabase functions deploy delete-account
// 呼び出し:  Flutter から _supabase.functions.invoke('delete-account')
//            (Authorization ヘッダは supabase_flutter が自動付与)
// ==========================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "missing authorization header" }, 401);
    }

    const url = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // 呼び出し元の本人確認（渡された JWT で getUser）
    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userErr,
    } = await userClient.auth.getUser();

    if (userErr || !user) {
      return json({ error: "unauthorized" }, 401);
    }

    // service role で Auth ユーザーを削除（public.users へ CASCADE）
    const admin = createClient(url, serviceKey);
    const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
    if (delErr) {
      return json({ error: delErr.message }, 500);
    }

    return json({ success: true }, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
