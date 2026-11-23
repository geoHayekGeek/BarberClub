import 'package:barber/core/services/fcm_service.dart';
import 'package:barber/core/storage/token_repository.dart';
import 'package:barber/domain/models/api_error.dart';
import 'package:barber/domain/models/reservation_models.dart';
import 'package:barber/domain/models/reservation_session.dart';
import 'package:barber/domain/models/user.dart';
import 'package:barber/domain/repositories/auth_repository.dart';
import 'package:barber/domain/repositories/reservation_auth_repository.dart';
import 'package:barber/domain/repositories/reservation_repository.dart';
import 'package:barber/presentation/providers/auth_providers.dart';
import 'package:barber/presentation/providers/reservation_auth_providers.dart';
import 'package:barber/presentation/providers/reservation_providers.dart';
import 'package:barber/presentation/screens/compte_screen.dart';
import 'package:barber/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AppAuthRepository extends Fake implements AuthRepository {}

class _ReservationAuthRepository extends Fake
    implements ReservationAuthRepository {}

class _Tokens extends Fake implements TokenRepository {}

class _Fcm extends Fake implements FcmService {}

class _SignedIn extends AuthController {
  _SignedIn(Ref ref)
    : super(
        ref: ref,
        authRepository: _AppAuthRepository(),
        tokenRepository: _Tokens(),
        fcmService: _Fcm(),
        reservationAuthRepository: _ReservationAuthRepository(),
      ) {
    state = const AuthState(
      status: AuthStatus.authenticated,
      user: User(
        id: 'client',
        email: 'test@example.test',
        phoneNumber: '0600000000',
      ),
    );
  }
}

String _dateKey(DateTime date) => date.toIso8601String().split('T').first;

class _BookingRepository extends Fake implements ReservationRepository {
  final summary = ReservationBooking.fromJson({
    'id': 'booking-1',
    'date': _dateKey(DateTime.now().add(const Duration(days: 5))),
    'start_time': '16:30',
    'end_time': '17:00',
    'salon_id': 'meylan',
    'barber_id': 'ju',
    'barber_name': 'Ju',
    'service_id': 'coupe-barbe',
    'service_name': 'Coupe Homme + Barbe',
    'cancel_token': 'test-token',
    'status': 'confirmed',
  });
  late ReservationBooking details = summary;
  bool unavailableOnFirstCheck = false;
  bool movedDuringSubmission = false;
  int detailReads = 0;
  int monthReads = 0;
  int slotReads = 0;
  final submissions = <(String, String, String, String, String?)>[];

  @override
  Future<ReservationClientBookingsPage> getClientBookings({
    String? salonId,
  }) async => ReservationClientBookingsPage(upcoming: [summary], past: []);

  @override
  Future<ReservationBooking> getBookingDetails({
    required String bookingId,
    required String cancelToken,
  }) async {
    detailReads++;
    if (detailReads == 1 && unavailableOnFirstCheck) {
      throw const ApiError(code: 'NETWORK_ERROR', message: 'Offline');
    }
    return details;
  }

  @override
  Future<Map<String, ReservationMonthAvailability>> getMonthAvailability({
    required String salonId,
    required String serviceId,
    required int year,
    required int month,
    String? barberId,
    bool includeAlternatives = false,
  }) async {
    monthReads++;
    return {};
  }

  @override
  Future<List<ReservationSlot>> getAvailability({
    required String salonId,
    required String serviceId,
    required String date,
    String? barberId,
  }) async {
    slotReads++;
    return [
      const ReservationSlot(time: '17:10', barberId: 'ju', barberName: 'Ju'),
    ];
  }

  @override
  Future<ReservationBooking> rescheduleBooking({
    required String bookingId,
    required String cancelToken,
    required String date,
    required String startTime,
    String? salonId,
  }) async {
    submissions.add((bookingId, cancelToken, date, startTime, salonId));
    details = details.copyWith(
      date: date,
      startTime: startTime,
      rescheduled: true,
    );
    if (movedDuringSubmission) {
      throw const ApiError(code: 'VALIDATION_ERROR', message: 'Bad request');
    }
    return details;
  }
}

Future<void> _openReschedule(
  WidgetTester tester,
  _BookingRepository repository, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_SignedIn.new),
        reservationSessionProvider.overrideWith(
          (ref) =>
              ReservationSessionController(
                repository: _ReservationAuthRepository(),
              )..setSession(
                const ReservationSession(
                  accessToken: 'test-access',
                  refreshToken: 'test-refresh',
                  user: ReservationClientProfile(
                    id: 'client',
                    firstName: 'Camille',
                    lastName: 'Test',
                    phone: '0600000000',
                    email: 'test@example.test',
                  ),
                ),
              ),
        ),
        reservationRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const CompteScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (find.text('Décaler').evaluate().isEmpty) {
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -280));
    await tester.pumpAndSettle();
  }
  await _tap(tester, find.text('Décaler'));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _inSheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

const _confirm = 'Confirmer le nouveau créneau';
const _alreadyMoved = 'Ce rendez-vous a déjà été déplacé';

void main() {
  testWidgets('a stale profile entry cannot open a second reschedule', (
    tester,
  ) async {
    final repository = _BookingRepository();
    repository.details = repository.summary.copyWith(rescheduled: true);
    await _openReschedule(tester, repository, textScale: 1.4);

    expect(_inSheet(_alreadyMoved), findsOneWidget);
    expect(_inSheet('Rendez-vous actuel'), findsOneWidget);
    expect(_inSheet(_confirm), findsNothing);
    expect(repository.detailReads, 1);
    expect(repository.monthReads, 0);
    expect(repository.slotReads, 0);
    expect(repository.submissions, isEmpty);

    await _tap(tester, _inSheet('Retour à mes rendez-vous'));
    expect(find.text('Décaler'), findsNothing);
    expect(find.text('Annuler'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the status check can be retried without opening the calendar', (
    tester,
  ) async {
    final repository = _BookingRepository()..unavailableOnFirstCheck = true;
    await _openReschedule(tester, repository);
    expect(_inSheet('Vérification indisponible'), findsOneWidget);
    expect(repository.monthReads, 0);
    await _tap(tester, _inSheet('Réessayer'));
    expect(repository.detailReads, 2);
    expect(repository.monthReads, 1);
    expect(_inSheet(_confirm), findsOneWidget);
  });

  for (final race in [false, true]) {
    testWidgets(
      race
          ? 'a rejected move rechecks the one-move limit'
          : 'a first move can be confirmed',
      (tester) async {
        final repository = _BookingRepository()..movedDuringSubmission = race;
        await _openReschedule(tester, repository);
        final confirm = find.widgetWithText(ElevatedButton, _confirm);
        expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull);
        final today = DateTime.now();
        await _tap(tester, _inSheet('${today.day}'));
        await _tap(tester, _inSheet('17:10'));
        expect(confirm.hitTestable(), findsOneWidget);
        await _tap(tester, confirm);

        expect(repository.submissions.single, (
          'booking-1',
          'test-token',
          _dateKey(today),
          '17:10',
          'meylan',
        ));
        if (race) {
          expect(repository.detailReads, 2);
          expect(_inSheet(_alreadyMoved), findsOneWidget);
          expect(_inSheet(_confirm), findsNothing);
          expect(
            find.text('Veuillez vérifier les informations saisies.'),
            findsNothing,
          );
        } else {
          expect(repository.detailReads, 1);
          expect(find.byType(BottomSheet), findsNothing);
          expect(find.text('Rendez-vous décalé avec succès.'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
