import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/salon_providers.dart';
import '../widgets/salon_card.dart';

class RdvScreen extends ConsumerWidget {
  const RdvScreen({super.key});

  /// Function to open Timify URL
  Future<void> _launchTimify(BuildContext context, String? url) async {
    if (url == null || url.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Réservation en ligne indisponible pour ce salon.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir le lien de réservation.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salonsAsync = ref.watch(salonsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prendre RDV'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 24, 0, 16),
              child: Text(
                'Choisissez votre salon',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                    ),
              ),
            ),
            
            Expanded(
              child: salonsAsync.when(
                data: (salons) {
                  if (salons.isEmpty) {
                    return const Center(child: Text('Aucun salon trouvé.'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: salons.length,
                    itemBuilder: (context, index) {
                      final salon = salons[index];
                      return SalonCard(
                        salon: salon,
                        onTap: () => _launchTimify(context, salon.timifyUrl),
                        // CHANGED: Set to true to hide description like in Offers
                        hideDescription: true, 
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Text('Erreur: $err', style: const TextStyle(color: Colors.red)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}