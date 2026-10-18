// 訪問確認フローのモデル。

/// 訪問確認が成立した後、カード作成画面へ引き継ぐコンテキスト。
class VisitContext {
  final String storeId;
  final String storeName;
  final String verificationId;
  final String capturedPhotoPath; // アプリ内カメラで撮影した現地写真
  final double latitude;
  final double longitude;

  const VisitContext({
    required this.storeId,
    required this.storeName,
    required this.verificationId,
    required this.capturedPhotoPath,
    required this.latitude,
    required this.longitude,
  });
}
