import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/cards_provider.dart';
import '../../common_widgets/experience_card.dart';
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
                        selectedDayPredicate: (day) {
                          return isSameDay(_selectedDay, day);
                        },
                        onDaySelected: (selectedDay, focusedDay) {
                          if (!isSameDay(_selectedDay, selectedDay)) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          }
                        },
                        headerStyle: const HeaderStyle(
                          titleCentered: true,
                          formatButtonVisible: false,
                        ),
                        calendarStyle: CalendarStyle(
                          selectedDecoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      // Filered Cards Grid
                      Expanded(
                        child: myCardsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                          data: (myCards) {
                            final filteredCards = myCards.where((card) {
                              if (card.createdAt == null) return false;
                              return isSameDay(card.createdAt, _selectedDay);
                            }).toList();

                            if (myCards.isEmpty) {
                              return const Center(child: Text('No cards crafted yet.', style: TextStyle(color: Colors.grey)));
                            }
                            if (filteredCards.isEmpty) {
                              return Center(
                                child: Text(
                                  'No cards created on \${_selectedDay?.month}/\${_selectedDay?.day}.', 
                                  style: const TextStyle(color: Colors.grey)
                                )
                              );
                            }
                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.75, // トレーディングカード風の縦長比率
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: filteredCards.length,
                              itemBuilder: (context, index) {
                                return ExperienceCard(
                                  model: filteredCards[index],
                                  isCompact: true,
                                  onTap: () => context.push('/card_detail', extra: filteredCards[index]),
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
        subtitle: Text('\$date • \$cardCount cards'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.push('/deck_playback', extra: mockDemoDeck);
        },
      ),
    );
  }
}
