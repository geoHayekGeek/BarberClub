import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';

/// Admin flow: select salon, then select service (prestation), then scan user QR.
class AdminServiceSelectionScreen extends ConsumerStatefulWidget {
  const AdminServiceSelectionScreen({super.key});

  @override
  ConsumerState<AdminServiceSelectionScreen> createState() => _AdminServiceSelectionScreenState();
}

class _AdminServiceSelectionScreenState extends ConsumerState<AdminServiceSelectionScreen> {
  List<_SalonItem> _salons = [];
  List<_ServiceItem> _services = [];
  String? _selectedSalonId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _error = null;
      _services = [];
    });
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.get('/api/v1/admin/salons');
      final data = response.data as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>? ?? [];
      final salons = list.map((e) {
        final m = e as Map<String, dynamic>;
        return _SalonItem(
          id: m['id'] as String,
          name: (m['name'] as String?) ?? '',
          city: (m['city'] as String?) ?? '',
        );
      }).toList();

      if (!mounted) return;
      if (salons.isEmpty) {
        setState(() {
          _salons = [];
          _loading = false;
        });
        return;
      }

      setState(() {
        _salons = salons;
        _selectedSalonId = salons.first.id;
      });

      await _loadServicesForSalon(salons.first.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les salons';
        _loading = false;
      });
    }
  }

  Future<void> _loadServicesForSalon(String salonId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.get('/api/v1/admin/salons/$salonId/services');
      final data = response.data as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>? ?? [];

      if (!mounted) return;
      setState(() {
        _selectedSalonId = salonId;
        _services = list.map((e) {
          final m = e as Map<String, dynamic>;
          return _ServiceItem(
            id: m['id'] as String,
            name: m['name'] as String? ?? '',
            priceCents: (m['priceCents'] as num?)?.toInt() ?? 0,
            pointsEarned: (m['pointsEarned'] as num?)?.toInt() ?? 0,
          );
        }).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
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
              onPressed: _loadInitialData,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
    if (_salons.isEmpty) {
      return Center(
        child: Text(
          'Aucun salon accessible',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
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
          'Choisir un salon',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        ..._salons.map((salon) {
          final isSelected = salon.id == _selectedSalonId;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isSelected ? const Color(0xFF262626) : const Color(0xFF1A1A1A),
            child: ListTile(
              title: Text(salon.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                salon.city,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.white70)
                  : const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () => _loadServicesForSalon(salon.id),
            ),
          );
        }),
        const SizedBox(height: 16),
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

class _SalonItem {
  final String id;
  final String name;
  final String city;

  _SalonItem({
    required this.id,
    required this.name,
    required this.city,
  });
}
