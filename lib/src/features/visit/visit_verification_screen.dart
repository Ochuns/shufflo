import 'package:flutter/material.dart';
import '../../theme/aizu_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/visit_models.dart';
import '../../models/visit_repository.dart';
import '../explore/location_provider.dart';

/// 訪問確認フロー（§11）。
/// GPS取得 → 店舗QRスキャン → verify_visit(サーバー判定) → 現地カメラ撮影 →
/// カード作成画面へ引き継ぎ。進捗はカード保存成功後に更新される。
class VisitVerificationScreen extends ConsumerStatefulWidget {
  const VisitVerificationScreen({super.key, required this.storeId, required this.storeName});
  final String storeId;
  final String storeName;

  @override
  ConsumerState<VisitVerificationScreen> createState() => _VisitVerificationScreenState();
}

enum _Step { locating, scanning, verifying, capture }

class _VisitVerificationScreenState extends ConsumerState<VisitVerificationScreen> {
  _Step _step = _Step.locating;
  String? _error;
  double? _lat;
  double? _lon;
  String? _verificationId;
  bool _handled = false; // QR二重処理防止
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _acquireLocation();
  }

  Future<void> _acquireLocation() async {
    setState(() {
      _step = _Step.locating;
      _error = null;
    });
    final loc = await ref.read(locationProvider).getCurrentLocation();
    if (!mounted) return;
    if (loc == null) {
      setState(() => _error = '位置情報を取得できませんでした。設定で位置情報を許可してけさい。');
      return;
    }
    setState(() {
      _lat = loc.latitude;
      _lon = loc.longitude;
      _step = _Step.scanning;
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || _step != _Step.scanning) return;
    final raw = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    setState(() => _step = _Step.verifying);
    try {
      final vid = await ref.read(visitRepositoryProvider).verifyVisit(
            storeId: widget.storeId,
            lat: _lat!,
            lon: _lon!,
            qrToken: raw,
          );
      if (!mounted) return;
      setState(() {
        _verificationId = vid;
        _step = _Step.capture;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _jpVerifyError(e.toString());
        _step = _Step.scanning;
        _handled = false;
      });
    }
  }

  Future<void> _capturePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return; // 撮り直し可
    if (!mounted) return;
    final ctx = VisitContext(
      storeId: widget.storeId,
      storeName: widget.storeName,
      verificationId: _verificationId!,
      capturedPhotoPath: photo.path,
      latitude: _lat!,
      longitude: _lon!,
    );
    // 既存のカード作成画面へ引き継ぐ
    context.pushReplacement('/create_card', extra: ctx);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.storeName} で記録')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null && _step != _Step.scanning) {
      return _ErrorView(message: _error!, onRetry: _acquireLocation);
    }
    switch (_step) {
      case _Step.locating:
        return const _Centered(icon: Icons.my_location, text: '現在地を確認してるがらちょっと待ってけさい…', spinner: true);
      case _Step.verifying:
        return const _Centered(icon: Icons.verified_user, text: '訪問を確認してるよ…', spinner: true);
      case _Step.scanning:
        return _buildScanner();
      case _Step.capture:
        return _buildCapture();
    }
  }

  Widget _buildScanner() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              MobileScanner(onDetect: _onDetect),
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: AizuColors.textPrimary, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('お店のQRコードを読み取ってけさい',
                  style: Theme.of(context).textTheme.titleMedium),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCapture() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 64),
          const SizedBox(height: 16),
          Text('訪問を確認したぞ！', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            '現地の写真を撮ってカードにしよう。\n（ギャラリーの写真ではテーマの達成にならねぇよ）',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _capturePhoto,
            icon: const Icon(Icons.camera_alt),
            label: const Text('写真を撮る'),
          ),
        ],
      ),
    );
  }
}

String _jpVerifyError(String raw) {
  if (raw.contains('GPS')) return 'お店から離れすぎてるみたいだ。お店の近くで試してけさい。';
  if (raw.contains('QR')) return 'このお店のQRコードでねぇようだ。もう一度読み取ってけさい。';
  if (raw.contains('rate limit')) return '少し待ってからもう一度試してけさい。';
  return '訪問確認に失敗しました。もう一度試してけさい。';
}

class _Centered extends StatelessWidget {
  const _Centered({required this.icon, required this.text, this.spinner = false});
  final IconData icon;
  final String text;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center),
          if (spinner) ...[
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('もう一度')),
          ],
        ),
      ),
    );
  }
}
