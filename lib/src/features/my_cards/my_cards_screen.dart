import 'package:flutter/material.dart';
import '../../theme/aizu_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../models/cards_provider.dart';
import '../../models/decks_provider.dart';
import '../../models/deck_model.dart';
import '../../models/experience_card_model.dart';
import '../../common_widgets/tcg_card_view.dart';

class MyCardsScreen extends ConsumerStatefulWidget {
  const MyCardsScreen({super.key});

  @override
  ConsumerState<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends ConsumerState<MyCardsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // カード一覧の左右スワイプで選択日を前後に移動する
  void _changeDay(int delta) {
    final base = _selectedDay ?? DateTime.now();
    final next = DateTime(base.year, base.month, base.day + delta);
    setState(() {
      _selectedDay = next;
      _focusedDay = next;
    });
  }

  // 年月の見出しをタップすると、最初にカードを作成した月から今月までの月カレンダーを表示し、
  // 選んだ日のカード一覧へ移動する
  Future<void> _showMonthCalendar(List<ExperienceCardModel> cards) async {
    final now = DateTime.now();
    final dates = cards
        .where((c) => c.createdAt != null && !c.isPublic)
        .map((c) => c.createdAt!.toLocal())
        .toList();
    final earliest = dates.isEmpty
        ? now
        : dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final firstDay = DateTime(earliest.year, earliest.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    var focused = _selectedDay ?? now;
    if (focused.isBefore(firstDay)) focused = firstDay;
    if (focused.isAfter(lastDay)) focused = lastDay;

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      // 下部ナビゲーションバーに隠れないよう、ルートのナビゲーターに表示する
      useRootNavigator: true,
      backgroundColor: AizuColors.kinari,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '日付を選んで移動',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AizuColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TableCalendar(
                locale: 'ja_JP',
                firstDay: firstDay,
                lastDay: lastDay,
                focusedDay: focused,
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {CalendarFormat.month: '月'},
                eventLoader: (day) =>
                    dates.where((d) => isSameDay(d, day)).toList(),
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, _) =>
                    Navigator.pop(sheetContext, selectedDay.toLocal()),
                headerStyle: const HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextStyle: TextStyle(color: AizuColors.textPrimary),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: AizuColors.textPrimary,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: AizuColors.textPrimary,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  defaultTextStyle: const TextStyle(
                    color: AizuColors.textPrimary,
                  ),
                  weekendTextStyle: const TextStyle(
                    color: AizuColors.textSecondary,
                  ),
                  outsideDaysVisible: false,
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return null;
                    return Center(
                      child: Icon(
                        Icons.check,
                        size: 28,
                        color: Colors.red.withOpacity(0.6),
                      ),
                    );
                  },
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: AizuColors.textSecondary),
                  weekendStyle: TextStyle(color: AizuColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedDay = picked;
      _focusedDay = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final myCardsAsync = ref.watch(cardsProvider);
    final decksAsync = ref.watch(decksProvider);

    return Scaffold(
      backgroundColor: AizuColors.kinari,
      appBar: AppBar(
        title: const Text(
          'カード & デッキ',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AizuColors.textPrimary,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: () => context.push('/create_deck'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(LucideIcons.plus, color: Colors.black),
            )
          : null,
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'カード'),
              Tab(text: 'デッキ'),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              // 左右スワイプは日付の切り替えに使うため、タブ切り替えはタップのみ
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Tab 1: Cards Grid with Calendar
                Column(
                  children: [
                    TableCalendar(
                      locale: 'ja_JP',
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: CalendarFormat.week,
                      availableCalendarFormats: const {
                        CalendarFormat.week: '週',
                      },
                      eventLoader: (day) {
                        final cards = myCardsAsync.value ?? [];
                        return cards.where((c) {
                          if (c.createdAt == null || c.isPublic) return false;
                          return isSameDay(c.createdAt!.toLocal(), day);
                        }).toList();
                      },
                      selectedDayPredicate: (day) {
                        return isSameDay(_selectedDay, day);
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay.toLocal();
                          _focusedDay = focusedDay.toLocal();
                        });
                      },
                      headerStyle: const HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false,
                        titleTextStyle: TextStyle(
                          color: AizuColors.textPrimary,
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left,
                          color: AizuColors.textPrimary,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right,
                          color: AizuColors.textPrimary,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        selectedDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        selectedTextStyle: const TextStyle(
                          color: AizuColors.kinari,
                          fontWeight: FontWeight.bold,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        defaultTextStyle: const TextStyle(
                          color: AizuColors.textPrimary,
                        ),
                        weekendTextStyle: const TextStyle(
                          color: AizuColors.textSecondary,
                        ),
                        outsideTextStyle: const TextStyle(color: Colors.grey),
                        markersAlignment: Alignment.bottomCenter,
                      ),
                      calendarBuilders: CalendarBuilders(
                        // 年月の見出しがタップできることを示す ▼ を付ける
                        // （headerTitleBuilder を使うと onHeaderTapped は呼ばれないため、ここでタップを受ける）
                        headerTitleBuilder: (context, day) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              _showMonthCalendar(myCardsAsync.value ?? []),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat.yMMMM('ja_JP').format(day),
                                style: const TextStyle(
                                  fontSize: 17,
                                  color: AizuColors.textPrimary,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: AizuColors.textPrimary,
                              ),
                            ],
                          ),
                        ),
                        markerBuilder: (context, date, events) {
                          if (events.isNotEmpty) {
                            return Center(
                              child: Icon(
                                Icons.check,
                                size: 32,
                                color: Colors.red.withOpacity(0.6),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                          color: AizuColors.textSecondary,
                        ),
                        weekendStyle: TextStyle(
                          color: AizuColors.textSecondary,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AizuColors.border),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragEnd: (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          if (velocity < -200) _changeDay(1);
                          if (velocity > 200) _changeDay(-1);
                        },
                        child: myCardsAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, st) => const Center(
                            child: Text(
                              'カードを読み込めませんでした',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          data: (myCards) {
                            final privateCards = myCards
                                .where((c) => !c.isPublic)
                                .toList();
                            final filteredCards = privateCards.where((card) {
                              if (card.createdAt == null ||
                                  _selectedDay == null)
                                return false;
                              final date = card.createdAt!.toLocal();
                              final target = _selectedDay!.toLocal();
                              return date.year == target.year &&
                                  date.month == target.month &&
                                  date.day == target.day;
                            }).toList();

                            if (privateCards.isEmpty) {
                              return const Center(
                                child: Text(
                                  'まだカードがありません',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              );
                            }
                            if (filteredCards.isEmpty) {
                              return Center(
                                child: Text(
                                  '${_selectedDay?.month}月${_selectedDay?.day}日に作成したカードはありません',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              );
                            }
                            // 上下スワイプ時のカードの伸び（オーバースクロール効果）を無効にする
                            return ScrollConfiguration(
                              behavior: ScrollConfiguration.of(
                                context,
                              ).copyWith(overscroll: false),
                              child: GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.65,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                itemCount: filteredCards.length,
                                itemBuilder: (context, index) {
                                  return GestureDetector(
                                    onTap: () => context.push(
                                      '/card_detail',
                                      extra: filteredCards[index],
                                    ),
                                    child: TcgCardView(
                                      model: filteredCards[index],
                                      isCompact: true,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                // Tab 2: Decks
                decksAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => const Center(
                    child: Text(
                      'デッキを読み込めませんでした',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  data: (decks) {
                    if (decks.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.layers,
                              size: 64,
                              color: AizuColors.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'まだデッキがありません',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '＋ボタンから最初のデッキを作成しましょう',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }
                    // カード一覧と同じく、上下スワイプ時の伸び（オーバースクロール効果）を無効にする
                    return ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(overscroll: false),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: decks.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildDeckItem(context, decks[index]);
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckItem(BuildContext context, DeckModel deck) {
    return Card(
      elevation: 0,
      color: AizuColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AizuColors.textPrimary.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            LucideIcons.layers,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          deck.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AizuColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${deck.cards.length}枚 • ${deck.location}',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        trailing: const Icon(
          LucideIcons.chevronRight,
          color: Colors.grey,
          size: 20,
        ),
        onTap: () {
          context.push('/deck_playback', extra: deck);
        },
      ),
    );
  }
}
