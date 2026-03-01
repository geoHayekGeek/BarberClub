import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';

/// Admin: list of services (prestations) to select before scanning user earn QR.
/// Tap a service -> navigate to scanner with serviceId; on scan, user earns points (1 pt/eur).
class AdminServiceSelectionScreen extends ConsumerStatefulWidget {
  const AdminServiceSelectionScreen({super.key});

  @override
  ConsumerState<AdminServiceSelectionScreen> createState() => _AdminServiceSelectionScreenState();
}

class _AdminServiceSelectionScreenState extends ConsumerState<AdminServiceSelectionScreen> {
  List<_ServiceItem> _services = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.get('/api/v1/admin/services');
      final data = response.data as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>? ?? [];
      setState(() {
        _services = list
            .map((e) {
              final m = e as Map<String, dynamic>;
              return _ServiceItem(
                id: m['id'] as String,
                name: m['name'] as String? ?? '',
                priceCents: (m['priceCents'] as num?)?.toInt() ?? 0,
                pointsEarned: (m['pointsEarned'] as num?)?.toInt() ?? 0,
              );
            })
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Impossible de charger les prestations';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadServices,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
    if (_services.isEmpty) {
      return Center(
        child: Text(
          'Aucune prestation configurée',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Choisir une prestation',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          'Puis scannez le QR du client pour lui attribuer les points.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 24),
        ..._services.map((s) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: const Color(0xFF1A1A1A),
              child: ListTile(
                title: Text(s.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  '${s.pointsEarned} pts - ${(s.priceCents / 100).toStringAsFixed(2)} EUR',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: const Icon(Icons.qr_code_scanner, color: Colors.white54),
                onTap: () => context.push('/admin/scanner?serviceId=${Uri.encodeComponent(s.id)}'),
              ),
            )),
      ],
    );
  }
}

class _ServiceItem {
  final String id;
  final String name;
  final int priceCents;
  final int pointsEarned;

  _ServiceItem({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.pointsEarned,
  });
}
