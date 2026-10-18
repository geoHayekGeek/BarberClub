import 'package:barber/domain/models/salon.dart';
import 'package:barber/presentation/providers/salon_providers.dart';
import 'package:barber/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  final salons = [
    for (final entry in {
      'Grenoble': 'Barbershop premium centre-ville',
      'Meylan': 'Barbershop premium à Corenc',
      'Voiron': 'Ouverture 21 octobre 2026',
    }.entries)
      Salon.fromJson({
        'id': entry.key.toLowerCase(),
        'name': 'BarberClub ${entry.key}',
        'city': entry.key,
        'location': entry.value,
        'address': 'Adresse de ${entry.key}',
      }),
  ];

  for (final textScale in [1.0, 1.5]) {
    testWidgets(
      'all landing salons share city, subtitle and CTA at text scale $textScale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            GoRoute(
              path: '/salon/:id',
              builder: (_, state) =>
                  Scaffold(body: Text('Detail ${state.pathParameters['id']}')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [salonsListProvider.overrideWith((ref) async => salons)],
            child: MaterialApp.router(
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        for (final salon in salons) {
          final panel = find.byKey(ValueKey('home-salon-${salon.id}'));
          expect(tester.getSize(panel), const Size(320, 320));
          expect(
            find.descendant(
              of: panel,
              matching: find.text(salon.city.toUpperCase()),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: panel,
              matching: find.text(
                salon.id == 'voiron'
                    ? 'BARBERSHOP PREMIUM À VOIRON'
                    : salon.location!.toUpperCase(),
              ),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(of: panel, matching: find.text('DECOUVRIR')),
            findsOneWidget,
          );
          expect(find.text(salon.name.toUpperCase()), findsNothing);
          expect(find.text(salon.address), findsNothing);
        }
        expect(find.text('AUTRES ADRESSES'), findsNothing);
        expect(find.text("PLUS D'INFOS"), findsNothing);
        expect(find.text('OUVERTURE 21 OCTOBRE 2026'), findsNothing);

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -2200),
        );
        await tester.pump(const Duration(seconds: 1));
        final voiron = find.byKey(const ValueKey('home-salon-voiron'));
        expect(voiron.hitTestable(), findsOneWidget);
        await tester.tap(voiron);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Detail voiron'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
