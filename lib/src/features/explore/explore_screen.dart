import 'dart:math';
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

class _ExploreScreenState extends ConsumerState<ExploreScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final PageController _pageController = PageController(viewportFraction: 0.65);
  bool _isLoadingLocation = false;
  LatLng? _currentLocation;
  bool _locationError = false; // 位置情報の取得失敗フラグ

  List<ExperienceCardModel> _nearbyCards = [];
  bool _isLoadingNearbyCards = true; // 初回は位置取得までローディング扱い
  int _lastFocusedIndex = 0; // 最後にフォーカスされたインデックスを追跡
  final List<ExperienceCardModel> _handCards = []; // 手札に加わったカード（発見済みのカード）を順番に保持
  AnimationController? _moveAnimationController; // マップ移動アニメーション用コントローラー

  @override
  void initState() {
    super.initState();
    // アプリ起動時（マップ画面表示時）に現在地へ自動移動
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _goToCurrentLocation(isInitial: true);
    });

    // PageViewのスクロールを監視してマップを連動させる
    _pageController.addListener(_onPageScrolled);
  }

  void _onPageScrolled() {
    if (!_pageController.hasClients || _nearbyCards.isEmpty) return;
    
    final double page = _pageController.page ?? 0.0;
    final int focusedIndex = page.round();
    
    // 選択されているカードが変わったらマップをその位置へ滑らかに移動
    if (focusedIndex != _lastFocusedIndex) {
      _lastFocusedIndex = focusedIndex;
      if (focusedIndex >= 0 && focusedIndex < _handCards.length) {
        final card = _handCards[focusedIndex];
        if (card.latitude != null && card.longitude != null) {
          _animatedMapMove(LatLng(card.latitude!, card.longitude!), 16.5);
        }
      }
    }
  }

  // マップを滑らかに（ぬるぬる）移動させるための関数
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(begin: _mapController.camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: _mapController.camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: _mapController.camera.zoom, end: destZoom);

    // 前回のアニメーションが残っていれば停止・破棄してから新しいものを開始
    _moveAnimationController?.dispose();
    _moveAnimationController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    final Animation<double> animation = CurvedAnimation(parent: _moveAnimationController!, curve: Curves.fastOutSlowIn);

    _moveAnimationController!.addListener(() {
      if (!mounted) return;
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    _moveAnimationController!.forward();
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
    _moveAnimationController?.dispose();
    _pageController.removeListener(_onPageScrolled);
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

  Marker _buildEncounterMarker(ExperienceCardModel card) {
    return Marker(
      point: LatLng(card.latitude!, card.longitude!),
      width: 64,
      height: 64,
      child: GestureDetector(
        onTap: () async {
          final isViewed = _handCards.any((c) => c.id == card.id);
          
          if (isViewed) {
            // すでに持っているカードなら、手札の中のそのカードまでスクロール
            final handIndex = _handCards.indexWhere((c) => c.id == card.id);
            if (handIndex != -1 && _pageController.hasClients) {
              _pageController.animateToPage(handIndex,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic);
            }
          } else {
            // 未発見の「！」なら、詳細画面を開いてから手札に加える
            await context.push('/card_detail', extra: card);
            
            // 詳細画面から戻ってきたら手札の最後（右側）に加える
            if (mounted && !_handCards.any((c) => c.id == card.id)) {
              setState(() {
                _handCards.add(card);
              });
              
              // 手札に加わった直後、その最後尾（一番右）まで手札をスクロール
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final newIndex = _handCards.length - 1;
                if (newIndex >= 0 && _pageController.hasClients) {
                  _pageController.animateToPage(newIndex,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.elasticOut); // 手札に飛び込んでくるような演出
                }
              });
            }
          }
        },
        child: AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            bool isOpen = false;
            final collected = _handCards;
            if (_pageController.hasClients &&
                _pageController.position.haveDimensions) {
              double page = _pageController.page ?? 0.0;
              // 手札の中のこのカードのインデックスを探す
              final handIndex = collected.indexWhere((c) => c.id == card.id);
              if (handIndex != -1 && (page - handIndex).abs() < 0.5) {
                isOpen = true;
              }
            } else {
              // 初期状態
              if (collected.isNotEmpty && collected[0].id == card.id) isOpen = true;
            }
            return _EncounterMarker(
              card: card,
              isOpen: isOpen,
              isViewed: _handCards.any((c) => c.id == card.id),
            );
          },
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
              // 2. マーカーレイヤー（現在地 + 近接カード）
              // AnimatedBuilder でラップすることで、スクロールに合わせて描画順をリアルタイムに入れ替える
              AnimatedBuilder(
                animation: _pageController,
                builder: (context, _) {
                  final markers = <Marker>[];
                  
                  // 現在地のマーカー（自分の位置）は最背面付近に配置
                  if (_currentLocation != null) {
                    markers.add(
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
                    );
                  }

                  // 現在フォーカスされているカードのインデックスを取得
                  int focusedIndex = 0;
                  final collected = _handCards;
                  if (_pageController.hasClients && _pageController.position.haveDimensions) {
                    focusedIndex = (_pageController.page ?? 0.0).round();
                  }

                  // 1. フォーカスされていないマーカーを先に描画（層を下にする）
                  for (int i = 0; i < _nearbyCards.length; i++) {
                    final card = _nearbyCards[i];
                    if (card.latitude == null || card.longitude == null) continue;
                    
                    // 手札にあるかチェック
                    bool isFocused = false;
                    if (collected.isNotEmpty && focusedIndex < collected.length) {
                      isFocused = (collected[focusedIndex].id == card.id);
                    }
                    if (isFocused) continue;

                    markers.add(_buildEncounterMarker(card));
                  }

                  // 2. フォーカスされている（＝現在見ている）マーカーを最後に描画（層を一番上にする）
                  if (collected.isNotEmpty && focusedIndex < collected.length) {
                    final focusedCard = collected[focusedIndex];
                    if (focusedCard.latitude != null && focusedCard.longitude != null) {
                      // フォーカスされているマーカーを最前面に描画
                      markers.add(_buildEncounterMarker(focusedCard));
                    }
                  }

                  return MarkerLayer(markers: markers);
                },
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
                          message: 'この周辺にはまだカードがありません\nあなたが最初の投稿者になりませんか？',
                          backgroundColor: Colors.black.withOpacity(0.6),
                          icon: Icons.edit_location_alt,
                        )
                      : _handCards.isEmpty
                          ? _buildBanner(
                              message: 'マップ上のキラキラを手札に加えよう！',
                              backgroundColor: Colors.amber.withValues(alpha: 0.8),
                              icon: Icons.auto_awesome,
                            )
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: _handCards.length,
                      itemBuilder: (context, index) {
                        final card = _handCards[index];
                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double scale = 1.0;
                            if (_pageController.position.haveDimensions) {
                              double page = _pageController.page ?? 0.0;
                              double diff = (page - index).abs();
                              // イージングを適用して、中央に来る時の変化を「ぬるぬる」させる
                              double ease = Curves.easeOutCubic.transform((1 - diff.clamp(0, 1)).toDouble());
                              scale = 0.75 + (ease * 0.25);
                            } else {
                              scale = index == 0 ? 1.0 : 0.75;
                            }

                            final double offsetY = (1 - scale) * 120; // 少しだけ位置調整をマイルドに

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
                                  context.push('/card_detail', extra: card);
                                }
                              },
                              onTap: () {
                                context.push('/card_detail', extra: card);
                              },
                              child: TcgCardView(model: card),
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

// エンカウントマーカー
class _EncounterMarker extends StatefulWidget {
  final ExperienceCardModel card;
  final bool isOpen;
  final bool isViewed; // 一度でも選択（表示）されたかどうか
  const _EncounterMarker({
    required this.card,
    this.isOpen = false,
    this.isViewed = false,
  });

  @override
  State<_EncounterMarker> createState() => _EncounterMarkerState();
}

class _EncounterMarkerState extends State<_EncounterMarker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    if (!widget.isViewed) {
      _controller.repeat();
    }

    // 震えるようなアニメーションを有機的なカーブに変更
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 0.05).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.05, end: -0.05).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.05, end: 0).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 15,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 40),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(_EncounterMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isViewed && widget.isViewed) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // サイン波を使って滑らかに上下浮遊させる
        final hoverOffset = sin(_controller.value * 2 * pi) * 2.5;
        return Transform.translate(
          offset: Offset(0, widget.isOpen ? -14 : hoverOffset),
          child: Transform.rotate(
            angle: widget.isOpen ? 0 : _shakeAnimation.value,
            child: child,
          ),
        );
      },
      child: AnimatedScale(
        scale: widget.isOpen ? 1.5 : 1.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack, // ポンッと出るような心地よいイージング
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // キラキラ演出（未発見時のみ星を表示）
            if (!widget.isViewed) ...[
              _buildSparkle(top: -10, left: -10, size: 14, delay: 0),
              _buildSparkle(top: -12, right: -5, size: 10, delay: 0.5),
              _buildSparkle(bottom: 5, right: -12, size: 12, delay: 0.2),
            ],
            // 吹き出しのしっぽ部分
            Positioned(
              bottom: 0,
              child: Icon(
                Icons.arrow_drop_down_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            // 白い丸い吹き出し
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                  // 未発見（！）の時だけ、黄色のキラキラ光るオーラをつける
                  if (!widget.isViewed)
                    BoxShadow(
                      color: Colors.amber.withValues(
                        alpha: 0.4 + (sin(_controller.value * 2 * pi) * 0.2 + 0.2), 
                      ),
                      blurRadius: 10 + (sin(_controller.value * 2 * pi) * 6 + 6),
                      spreadRadius: 1 + (sin(_controller.value * 2 * pi) * 3 + 3),
                    ),
                ],
              ),
              child: Center(
                child: widget.isViewed
                    ? Icon(
                        widget.card.category.icon,
                        color: widget.card.category.color,
                        size: 24,
                      )
                    : const Text(
                        '!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // キラキラの星を作るヘルパー
  Widget _buildSparkle({double? top, double? left, double? right, double? bottom, required double size, required double delay}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // 個別にタイミングをずらしてキラキラさせる
          final val = sin((_controller.value + delay) * 2 * pi);
          final opacity = (val * 0.5 + 0.5).clamp(0.0, 1.0);
          final scale = 0.5 + (val * 0.5 + 0.5) * 0.5;
          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          );
        },
        child: Icon(Icons.star_rounded, color: Colors.amber, size: size),
      ),
    );
  }
}
