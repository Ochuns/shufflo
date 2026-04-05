import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/mock_data.dart';
import '../../common_widgets/experience_card.dart';
import '../../models/experience_card_model.dart';
// ignore: unused_import
import 'package:go_router/go_router.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Full-screen map (flutter_map using Mapbox tiles)
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(35.6812, 139.7671), // Tokyo
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}@2x?access_token={accessToken}',
                additionalOptions: const {
                  'accessToken': dotenv.env['MAPBOX_TOKEN']!, // Mapbox API Key
                },
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(35.6812, 139.7671),
                    width: 40,
                    height: 40,
                    child: Icon(Icons.location_on, color: Color(0xFFFF6B6B), size: 40),
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
          
          // 3. Bottom Sheet Preview (Floating Cards)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 160,
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.85),
                itemCount: mockCards.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ExperienceCard(
                      model: mockCards[index],
                      isCompact: true,
                      onTap: () {
                        // TODO: Open Card Popup Detail
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
