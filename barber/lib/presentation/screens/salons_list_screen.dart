import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/sources/salons_mock_data.dart';
import '../../domain/models/salon.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/salon_card.dart';

/// Nos Salons list page.
/// Scrollable list of salon cards; tap opens SalonDetailScreen.
class SalonsListScreen extends StatelessWidget {
  const SalonsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final salons = salonsMockData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nos salons'),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: salons.length,
          itemBuilder: (context, index) {
            final salon = salons[index];
            return SalonCard(
              salon: salon,
              onTap: () => _openDetail(context, salon),
            );
          },
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  void _openDetail(BuildContext context, Salon salon) {
    context.push('/salons/${salon.id}');
  }
}
