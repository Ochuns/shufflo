-- ==========================================
-- v2: get_nearby_public_cards にカテゴリ絞り込みを追加 (A案)
--   既存の 4引数版は残し、任意の p_category を受ける 5引数版を追加する
--   (オーバーロード)。p_category が NULL の場合は全カテゴリ。
--   サーバー側で絞ってから近い順・件数制限するため、10件制限と両立する。
-- 依存: 既存 get_nearby_public_cards / public_cards
-- 冪等。再実行可能。
-- ==========================================

CREATE OR REPLACE FUNCTION get_nearby_public_cards(
  target_lat float,
  target_lon float,
  max_dist_meters float,
  limit_num int,
  p_category text
) RETURNS SETOF public_cards AS $$
BEGIN
  max_dist_meters := LEAST(COALESCE(max_dist_meters, 5000), 50000);
  limit_num       := LEAST(GREATEST(COALESCE(limit_num, 10), 1), 50);

  RETURN QUERY
  SELECT *
  FROM public_cards
  WHERE deleted_at IS NULL
    AND (p_category IS NULL OR category = p_category)
    AND ST_DWithin(
          location_coords::geography,
          ST_Point(target_lon, target_lat)::geography,
          max_dist_meters
        )
  ORDER BY ST_Distance(
             location_coords::geography,
             ST_Point(target_lon, target_lat)::geography
           ) ASC
  LIMIT limit_num;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

GRANT EXECUTE ON FUNCTION get_nearby_public_cards(float, float, float, int, text)
  TO anon, authenticated;
