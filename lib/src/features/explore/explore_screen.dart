import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common_widgets/tcg_card_view.dart';
import '../../models/experience_card_model.dart';
import '../../models/supabase_repository.dart';
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
  LatLng? _currentLocation;
  bool _locationError = false; // 位置情報の取得失敗フラグ

  List<ExperienceCardModel> _nearbyCards = [];
  bool _isLoadingNearbyCards = true; // 初回は位置取得までローディング扱い

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
      _currentLocation = loc;
      _locationError = false;
      _mapController.move(loc, 16.5); // 地図の縮尺
      _fetchNearbyCards(loc);
    } else {
      setState(() {
        _isLoadingNearbyCards = false; // エラー時もローディング解除
        _locationError = true;
      });
      if (!isInitial) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('位置情報が許可されていません。設定をご確認ください。')),
        );
      }
    }
  }

  Future<void> _fetchNearbyCards(LatLng loc) async {
    setState(() {
      _isLoadingNearbyCards = true;
      _locationError = false;
    });
    final repo = ref.read(supabaseRepositoryProvider);
    final cards = await repo.fetchNearbyPublicCards(loc.latitude, loc.longitude);
    if (!mounted) return;
    setState(() {
      _nearbyCards = cards;
      _isLoadingNearbyCards = false;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildBanner({required String message, required Color backgroundColor, IconData? icon}) {
    return Container(
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(top: 80),
      child: Semantics(
        label: message,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(message, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  // 現在地のマーカー（自分の位置）
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1),
                          ],
                        ),
                      ),
                    ),
                  // 近接カードのマーカー
                  ..._nearbyCards.where((c) => c.latitude != null && c.longitude != null).map((card) {
                    return Marker(
                      point: LatLng(card.latitude!, card.longitude!),
                      width: 40,
                      height: 40,
                      child: Icon(Icons.location_on, color: card.category.color, size: 40),
                    );
                  }),
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
                        label: Text(cat.label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
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
            bottom: (_isLoadingNearbyCards || _nearbyCards.isNotEmpty) ? 200 : 130, // カードがない時は少し下に配置
            right: 16,
            child: SizedBox(
              width: 56,
              height: 56,
              child: FloatingActionButton(
                heroTag: 'location_fab',
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onPressed: () => _goToCurrentLocation(),
                child: _isLoadingLocation 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, color: Colors.blueAccent, size: 28),
              ),
            ),
          ),
          
          // 4. Bottom Sheet Preview (Floating TCG Cards peeking out)
          Positioned(
            bottom: -300, // ひょっこり度を調整
            left: 0,
            right: 0,
            height: 480, // TCGカード枠を描画するのに十分な高さ
            child: _isLoadingNearbyCards
              ? const Center(child: CircularProgressIndicator())
              : _locationError
                  ? _buildBanner(
                      message: '位置情報が取得できませんでした。設定をご確認ください。',
                      backgroundColor: Colors.red.withOpacity(0.75),
                      icon: Icons.location_off,
                    )
                  : _nearbyCards.isEmpty
                      ? _buildBanner(
                          message: 'この周辺にはまだカードがありません',
                          backgroundColor: Colors.black.withOpacity(0.6),
                        )
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: _nearbyCards.length,
                      itemBuilder: (context, index) {
                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double scale = 1.0;
                            if (_pageController.position.haveDimensions) {
                              double page = _pageController.page ?? 0.0;
                              double diff = (page - index).abs();
                              scale = (1 - (diff * 0.15)).clamp(0.75, 1.0);
                            } else {
                              scale = index == 0 ? 1.0 : 0.75;
                            }

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
                            child: GestureDetector(
                              onVerticalDragEnd: (details) {
                                if (details.primaryVelocity != null && details.primaryVelocity! < -10) {
                                  context.push('/card_detail', extra: _nearbyCards[index]);
                                }
                              },
                              onTap: () {
                                context.push('/card_detail', extra: _nearbyCards[index]);
                              },
                              child: TcgCardView(model: _nearbyCards[index]),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
