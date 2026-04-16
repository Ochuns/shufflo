import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/cards_provider.dart';
import '../../models/decks_provider.dart';
import '../../models/deck_model.dart';
import '../../common_widgets/tcg_card_view.dart';

class MyCardsScreen extends ConsumerStatefulWidget {
  const MyCardsScreen({super.key});

  @override
  ConsumerState<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends ConsumerState<MyCardsScreen> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final myCardsAsync = ref.watch(cardsProvider);
    final decksAsync = ref.watch(decksProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('My Decks & Cards', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
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
              Tab(text: 'Cards'),
              Tab(text: 'Decks'),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Cards Grid with Calendar
                Column(
                  children: [
                    TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: CalendarFormat.week,
                      availableCalendarFormats: const {
                        CalendarFormat.week: 'Week',
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
                        titleTextStyle: TextStyle(color: Colors.white),
                        leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                        rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
                      ),
                      calendarStyle: CalendarStyle(
                        selectedDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
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
                                color: Colors.red.withOpacity(0.6),
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
                    const Divider(height: 1, color: Colors.white10),
                    Expanded(
                      child: myCardsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                        data: (myCards) {
                          final privateCards = myCards.where((c) => !c.isPublic).toList();
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
                              childAspectRatio: 0.65,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: filteredCards.length,
                            itemBuilder: (context, index) {
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
                // Tab 2: Decks
                decksAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                  data: (decks) {
                    if (decks.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.layers, size: 64, color: Colors.grey.shade800),
                            const SizedBox(height: 16),
                            const Text(
                              'No decks created yet.',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap the + button to create your first deck!',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: decks.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildDeckItem(context, decks[index]);
                      },
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
      color: const Color(0xFF141414),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
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
          child: Icon(LucideIcons.layers, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(
          deck.title, 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
        ),
        subtitle: Text(
          '${deck.cards.length} cards • ${deck.location}',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        trailing: const Icon(LucideIcons.chevronRight, color: Colors.grey, size: 20),
        onTap: () {
          context.push('/deck_playback', extra: deck);
        },
      ),
    );
  }
}
