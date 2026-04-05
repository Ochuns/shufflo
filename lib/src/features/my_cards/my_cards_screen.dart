import 'package:flutter/material.dart';
import '../../models/mock_data.dart';
import '../../common_widgets/experience_card.dart';

class MyCardsScreen extends StatelessWidget {
  const MyCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  // Tab 1: Cards Grid
                  GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75, // トレーディングカード風の縦長比率
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: mockCards.length,
                    itemBuilder: (context, index) {
                      return ExperienceCard(
                        model: mockCards[index],
                        isCompact: true,
                      );
                    },
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
      ),
    );
  }
}
