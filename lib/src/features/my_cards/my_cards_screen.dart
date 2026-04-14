import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/cards_provider.dart';
import '../../common_widgets/tcg_card_view.dart';
import '../../models/experience_card_model.dart';
import '../../models/mock_data.dart';

class MyCardsScreen extends ConsumerStatefulWidget {
  const MyCardsScreen({super.key});

  @override
  ConsumerState<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends ConsumerState<MyCardsScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    // ユーザー(自分)が作成した全カード（Public + Private両方）を表示
    final myCardsAsync = ref.watch(cardsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Decks & Cards', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Cards'),
                Tab(text: 'Decks'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Cards Grid with Calendar
                  Column(
                    children: [
                      // Table Calendar
                      TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: CalendarFormat.week, // 週表示のみ
                        availableCalendarFormats: const {
                          CalendarFormat.week: 'Week',
                        },
                        eventLoader: (day) {
                          // その日に自分の非公開カードがあるかチェックしてマーカーを表示
                          final cards = myCardsAsync.value ?? [];
                          return cards.where((c) {
                            if (c.createdAt == null || c.isPublic) return false;
                            return isSameDay(c.createdAt, day);
                          }).toList();
                        },
                        selectedDayPredicate: (day) {
                          return isSameDay(_selectedDay, day);
                        },
                        onDaySelected: (selectedDay, focusedDay) {
                          // UTCの差分を吸収するためローカル時刻に明示的に変換して保存
                          setState(() {
                            _selectedDay = selectedDay.toLocal();
                            _focusedDay = focusedDay.toLocal();
                          });
                        },
                        headerStyle: const HeaderStyle(
                          titleCentered: true,
                          formatButtonVisible: false,
                        ),
                        calendarStyle: CalendarStyle(
                          selectedDecoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary, // Pop Yellow
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: const TextStyle(
                            color: Colors.black, 
                            fontWeight: FontWeight.bold
                          ),
                          todayDecoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          defaultTextStyle: const TextStyle(color: Colors.white),
                          weekendTextStyle: const TextStyle(color: Colors.white70),
                          outsideTextStyle: const TextStyle(color: Colors.grey),
                          markersAlignment: Alignment.bottomCenter,
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (events.isNotEmpty) {
                              return Center(
                                child: Icon(
                                  Icons.check,
                                  size: 32,
                                  color: Colors.red.withValues(alpha: 0.6), // 透過させて数字も見えるように
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(color: Colors.white70),
                          weekendStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const Divider(height: 1),
                      // Filtered Cards Grid
                      Expanded(
                        child: myCardsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                          data: (myCards) {
                            // 1. プライベート（非公開）カードのみに絞り込む
                            final privateCards = myCards.where((c) => !c.isPublic).toList();

                            // 2. 選択された日付と一致するものに絞り込む（年・月・日のマニュアル比較で確実性を高める）
                            final filteredCards = privateCards.where((card) {
                              if (card.createdAt == null || _selectedDay == null) return false;
                              final date = card.createdAt!.toLocal();
                              final target = _selectedDay!.toLocal();
                              return date.year == target.year && 
                                     date.month == target.month && 
                                     date.day == target.day;
                            }).toList();

                            if (privateCards.isEmpty) {
                              return const Center(child: Text('No private cards yet.', style: TextStyle(color: Colors.grey)));
                            }
                            if (filteredCards.isEmpty) {
                              return Center(
                                child: Text(
                                  'No cards created on ${_selectedDay?.month}/${_selectedDay?.day}.', 
                                  style: const TextStyle(color: Colors.grey)
                                )
                              );
                            }
                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.65, // TCGカードのアスペクト比に合わせる
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: filteredCards.length,
                              itemBuilder: (context, index) {
                                // ここを TcgCardView に変更
                                return GestureDetector(
                                  onTap: () => context.push('/card_detail', extra: filteredCards[index]),
                                  child: TcgCardView(model: filteredCards[index], isCompact: true),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  // Tab 2: Decks (Flow/Timeline view)
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildDeckItem(context, 'Kyoto Trip', 'Oct 12, 2026', 4),
                      const SizedBox(height: 16),
                      _buildDeckItem(context, 'Tokyo Night out', 'Nov 1, 2026', 3),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckItem(BuildContext context, String title, String date, int cardCount) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(Icons.layers, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$date • $cardCount cards'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.push('/deck_playback', extra: mockDemoDeck);
        },
      ),
    );
  }
}
