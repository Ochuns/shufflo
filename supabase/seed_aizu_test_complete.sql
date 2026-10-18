-- ==========================================
-- 【テスト専用】GPS+QRを使わずに「会津ラーメン巡り」を完成状態にする
--   本来はアプリの訪問確認フロー(GPS+店舗QR)でのみ進捗が付く。
--   これは動作確認のため SQL Editor から直接進捗を入れる抜け道。
--   ※ 先に seed_aizu_test.sql を実行しておくこと。
--
--   使い方: 下の 'あなたのユーザー名' を自分の登録ユーザー名に書き換えて実行。
-- ==========================================

DO $$
DECLARE
  v_user   uuid;
  v_theme  uuid := 'b2220000-0000-4000-8000-000000000001';
  v_cycle  int;
  v_store  uuid;
BEGIN
  -- ★ここを自分のユーザー名に変更★
  SELECT id INTO v_user FROM users WHERE username = 'あなたのユーザー名';
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'ユーザーが見つかりません。username を正しく指定してください。';
  END IF;

  -- 現在サイクルを用意
  INSERT INTO theme_cycles (user_id, theme_id, cycle_number)
  VALUES (v_user, v_theme, 1)
  ON CONFLICT (user_id, theme_id) DO NOTHING;
  SELECT cycle_number INTO v_cycle FROM theme_cycles WHERE user_id = v_user AND theme_id = v_theme;

  -- 対象3店舗すべてに進捗を付与（テストのため visited_record は NULL）
  FOR v_store IN SELECT store_id FROM theme_stores WHERE theme_id = v_theme LOOP
    INSERT INTO theme_progress (user_id, theme_id, cycle_number, store_id, visited_record_id)
    VALUES (v_user, v_theme, v_cycle, v_store, NULL)
    ON CONFLICT (user_id, theme_id, cycle_number, store_id) DO NOTHING;
  END LOOP;

  RAISE NOTICE 'テスト完了: 会津ラーメン巡りが 3/3 になりました。アプリで「報酬を受け取る」を押せます。';
END $$;
