import 'package:flutter/material.dart';
import '../../models/deck_model.dart';
import '../explore/card_detail_screen.dart';

class DeckPlaybackScreen extends StatefulWidget {
  final DeckModel deck;

  const DeckPlaybackScreen({super.key, required this.deck});

  @override
  State<DeckPlaybackScreen> createState() => _DeckPlaybackScreenState();
}

class _DeckPlaybackScreenState extends State<DeckPlaybackScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.deck.cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.deck.title)),
        body: const Center(child: Text("This deck is empty.")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. PageView for swiping through cards
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.deck.cards.length,
            itemBuilder: (context, index) {
              // We reuse the CardDetailScreen's UI logic directly here
              // or inject it. Since CardDetailScreen is a Scaffold, we can't easily embed it directly 
              // in a PageView if it has its own Scaffold. But CardDetailScreen is a Scaffold!
              // For MVP, we will embed the CardDetailScreen straight into the PageView.
              return CardDetailScreen(model: widget.deck.cards[index]);
            },
          ),

          // 2. Journey Progress Indicator (Timeline at the top)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: List.generate(widget.deck.cards.length, (index) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2.0),
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: index <= _currentIndex ? Colors.white : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          
          // 3. Deck Title overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  widget.deck.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
