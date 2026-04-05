import 'dart:typed_data';
import 'package:exif/exif.dart';

class ExifUtils {
  /// 画像バイト列からGPS情報を抽出し、緯度・経度のマップを返す
  /// 抽出できなかった場合は null を返す
  static Future<Map<String, double>?> getLocationFromImage(Uint8List bytes) async {
    try {
      final tags = await readExifFromBytes(bytes);

      if (tags.containsKey('GPS GPSLatitude') && tags.containsKey('GPS GPSLongitude')) {
        final latValue = tags['GPS GPSLatitude']!.values.toList();
        final latRef = tags['GPS GPSLatitudeRef']?.printable ?? 'N';

        final lonValue = tags['GPS GPSLongitude']!.values.toList();
        final lonRef = tags['GPS GPSLongitudeRef']?.printable ?? 'E';

        final lat = _convertToDecimal(latValue, latRef);
        final lon = _convertToDecimal(lonValue, lonRef);

        if (lat != null && lon != null) {
          return {'latitude': lat, 'longitude': lon};
        }
      }
    } catch (e) {
      // エラー時はフォールバックとしてnullを返す
      return null;
    }
    return null;
  }

  /// DMS (度分秒) の配列と東西南北の方角を Decimal Degrees に変換
  static double? _convertToDecimal(List<dynamic> dms, String ref) {
    if (dms.length != 3) return null;

    double d = _rationalToDouble(dms[0]);
    double m = _rationalToDouble(dms[1]);
    double s = _rationalToDouble(dms[2]);

    double decimal = d + (m / 60.0) + (s / 3600.0);
    if (ref == 'S' || ref == 'W') {
      decimal = decimal * -1;
    }
    return decimal;
  }

  /// exif の Ratio フォーマット (例: "139/1") や数値を double に変換する
  static double _rationalToDouble(dynamic val) {
    final s = val.toString();
    if (s.contains('/')) {
      final parts = s.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0]) ?? 0.0;
        final den = double.tryParse(parts[1]) ?? 1.0;
        if (den == 0) return 0.0;
        return num / den;
      }
    }
    return double.tryParse(s) ?? 0.0;
  }
}
