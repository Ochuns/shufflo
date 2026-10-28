/// 「たった今 / 〇分前 / 〇時間前 / 〇日前」の相対表記。7日以上前は日付。
String relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'たった今';
  if (d.inHours < 1) return '${d.inMinutes}分前';
  if (d.inDays < 1) return '${d.inHours}時間前';
  if (d.inDays < 7) return '${d.inDays}日前';
  return '${t.year}/${t.month}/${t.day}';
}
