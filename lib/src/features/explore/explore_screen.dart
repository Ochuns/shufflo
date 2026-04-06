import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/cards_provider.dart';
import '../../common_widgets/experience_card.dart'; // 互換性のため残す
import '../../common_widgets/tcg_card_view.dart';
import '../../models/experience_card_model.dart';
import 'location_provider.dart';
import 'package:go_router/go_router.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final MapController _mapController = MapController();
  final PageController _pageController = PageController(viewportFraction: 0.65);
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    // アプリ起動時（マップ画面表示時）に現在地へ自動移動
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _goToCurrentLocation(isInitial: true);
    });
  }

  Future<void> _goToCurrentLocation({bool isInitial = false}) async {
    if (_isLoadingLocation) return;
    setState(() => _isLoadingLocation = true);

    final locService = ref.read(locationProvider);
    final loc = await locService.getCurrentLocation();

    if (!mounted) return;

    setState(() => _isLoadingLocation = false);

    if (loc != null) {
      _mapController.move(loc, 16.5); // 地図の縮尺
    } else {
      if (!isInitial) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('位置情報が許可されていません。設定をご確認ください。')),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsProvider);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Full-screen map (flutter_map using Mapbox tiles)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(35.6812, 139.7671), // 初期位置：東京（位置情報待ち）
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}@2x?access_token={accessToken}',
                additionalOptions: {
                  'accessToken': dotenv.env['MAPBOX_TOKEN'] ?? '', // Mapbox API Key
                },
              ),
              MarkerLayer(
                markers: [
                  // 仮の初期マーカー
                  Marker(
                    point: LatLng(35.6812, 139.7671),
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: Color(0xFFFF6B6B), size: 40),
                  ),
                ],
              ),
            ],
          ),
          
          // 2. Category Filter (Top floating)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Icon(Icons.search, size: 20),
                      backgroundColor: Colors.white,
                      side: BorderSide.none,
                      elevation: 2,
                    ),
                  ),
                  ...ExperienceCategory.values.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        onSelected: (val) {},
                        backgroundColor: Colors.white,
                        side: BorderSide.none,
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.1),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // 3. Current Location Button (Floating)
          Positioned(
            bottom: 200, // Bottom Sheet の少し上に配置
            right: 16,
            child: FloatingActionButton(
              heroTag: 'location_fab',
              backgroundColor: Colors.white,
              onPressed: () => _goToCurrentLocation(),
              child: _isLoadingLocation 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, color: Colors.blueAccent),
            ),
          ),
          
          // 4. Bottom Sheet Preview (Floating TCG Cards peeking out)
          Positioned(
            bottom: -260, // さっきよりさらに下げてひょっこり度を調整
            left: 0,
            right: 0,
            height: 480, // TCGカード枠を描画するのに十分な高さ
            child: cardsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error', style: const TextStyle(color: Colors.red))),
              data: (cards) {
                final publicCards = cards.where((c) => c.isPublic).toList();
                if (publicCards.isEmpty) return const SizedBox.shrink();

                return PageView.builder(
                  controller: _pageController,
                  itemCount: publicCards.length,
                  itemBuilder: (context, index) {
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double scale = 1.0;
                        if (_pageController.position.haveDimensions) {
                          double page = _pageController.page ?? 0.0;
                          // 中央からの離れ具合
                          double diff = (page - index).abs();
                          // 離れるほど小さくする (最大0.75倍まで小さくなる)
                          scale = (1 - (diff * 0.15)).clamp(0.75, 1.0);
                        } else {
                          // ロード直後で1回も描画されていない時
                          scale = index == 0 ? 1.0 : 0.75;
                        }

                        // 選択されていない両端のカードは下に下げる（カーブを描く）
                        final double offsetY = (1 - scale) * 150;

                        return Transform.translate(
                          offset: Offset(0, offsetY),
                          child: Transform.scale(
                            scale: scale,
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        // 上にスワイプした時に詳細画面へ遷移させる
                        child: GestureDetector(
                          onVerticalDragEnd: (details) {
                            if (details.primaryVelocity != null && details.primaryVelocity! < -10) {
                              context.push('/card_detail', extra: publicCards[index]);
                            }
                          },
                          onTap: () {
                            context.push('/card_detail', extra: publicCards[index]);
                          },
                          child: TcgCardView(model: publicCards[index]),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
