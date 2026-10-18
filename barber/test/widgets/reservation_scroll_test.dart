import 'package:barber/data/repositories/website_catalog_repository.dart';
import 'package:barber/domain/models/barber.dart';
import 'package:barber/domain/models/reservation_models.dart';
import 'package:barber/domain/models/salon.dart';
import 'package:barber/domain/repositories/reservation_repository.dart';
import 'package:barber/presentation/providers/reservation_providers.dart';
import 'package:barber/presentation/providers/salon_providers.dart';
import 'package:barber/presentation/providers/website_catalog_provider.dart';
import 'package:barber/presentation/screens/rdv_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _salon = Salon(
  id: 'voiron',
  websiteId: 'voiron',
  name: 'BarberClub Voiron',
  city: 'Voiron',
  descriptionShort: '',
  descriptionLong: '',
  address: '',
  openingHours: '',
  images: [],
  services: [],
);

class _Bookings extends Fake implements ReservationRepository {
  String? loadedSalon;
  @override
  Future<List<ReservationBarber>> getBarbers({required String salonId}) async {
    loadedSalon = salonId;
    return [
      for (var i = 1; i <= 12; i++)
        ReservationBarber.fromJson({
          'id': 'barber-$i',
          'name': 'Barber $i',
          'role': 'Barbier',
        }),
    ];
  }

  @override
  Future<List<ReservationService>> getServices({
    required String salonId,
    String? barberId,
  }) async => [
    ReservationService.fromJson({
      'id': 'coupe',
      'name': 'Coupe Homme',
      'price': 2500,
      'duration': 30,
    }),
  ];
}

class _Catalogue extends WebsiteCatalogRepository {
  @override
  Future<List<Barber>> getBarbers({String? salonId}) async => [];
}

void main() {
  testWidgets(
    'third published salon can be reached and opens its own booking team',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bookings = _Bookings();
      final salons = [
        for (final id in ['grenoble', 'meylan', 'voiron'])
          Salon.fromJson({'id': id, 'websiteId': id, 'name': id, 'city': id}),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salonsListProvider.overrideWith((ref) async => salons),
            reservationRepositoryProvider.overrideWithValue(bookings),
            websiteCatalogProvider.overrideWithValue(_Catalogue()),
          ],
          child: const MaterialApp(home: RdvScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('J’ai lu et j’accepte ces conditions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RÉSERVER MON CRÉNEAU'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -1800),
      );
      await tester.pumpAndSettle();
      expect(find.text('VOIRON').hitTestable(), findsOneWidget);
      await tester.tap(find.text('VOIRON'));
      await tester.pumpAndSettle();
      expect(bookings.loadedSalon, 'voiron');
      expect(find.text('Barber 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a barber chosen on a profile preloads their booking services', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonsListProvider.overrideWith((ref) async => [_salon]),
          selectedSalonIdForRdvProvider.overrideWith((ref) => 'voiron'),
          selectedBarberNameForRdvProvider.overrideWith((ref) => 'Barber 3'),
          reservationRepositoryProvider.overrideWithValue(_Bookings()),
          websiteCatalogProvider.overrideWithValue(_Catalogue()),
        ],
        child: const MaterialApp(home: RdvScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('J’ai lu et j’accepte ces conditions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RÉSERVER MON CRÉNEAU'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUER'));
    await tester.pumpAndSettle();
    expect(find.text('Coupe Homme'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.5]) {
    testWidgets(
      'last barber is reachable on a compact phone at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              salonsListProvider.overrideWith((ref) async => [_salon]),
              selectedSalonIdForRdvProvider.overrideWith((ref) => 'voiron'),
              reservationRepositoryProvider.overrideWithValue(_Bookings()),
              websiteCatalogProvider.overrideWithValue(_Catalogue()),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const RdvScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Accept the existing booking policy before exercising the selection list.
        await tester.tap(find.text('J’ai lu et j’accepte ces conditions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('RÉSERVER MON CRÉNEAU'));
        await tester.pumpAndSettle();
        final scroll = find.byKey(const ValueKey('reservation-step-scroll'));
        await tester.drag(scroll, const Offset(0, -2200));
        await tester.pumpAndSettle();
        expect(find.text('Barber 12').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
