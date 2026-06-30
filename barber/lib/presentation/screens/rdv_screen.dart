import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/ui/app_snackbar.dart';
import '../../domain/models/api_error.dart';
import '../../domain/models/reservation_models.dart';
import '../../domain/models/reservation_session.dart';
import '../../domain/models/user.dart';
import '../../domain/models/salon.dart';
import '../providers/auth_providers.dart';
import '../providers/reservation_auth_providers.dart';
import '../providers/reservation_providers.dart';
import '../providers/salon_providers.dart';
import '../widgets/glowing_separator.dart';

class RdvScreen extends ConsumerStatefulWidget {
  const RdvScreen({super.key});

  @override
  ConsumerState<RdvScreen> createState() => _RdvScreenState();
}

class _RdvScreenState extends ConsumerState<RdvScreen> {
  static const Color _pageBackground = Color(0xFF050505);
  static const Color _panelBackground = Color(0xFF0A0A0A);
  static const Color _disabled = Color(0xFF191919);

  static const String _titleFont = 'Orbitron';

  final ScrollController _scrollController = ScrollController();
  final GlobalKey<FormState> _guestFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _signupFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _forgotFormKey = GlobalKey<FormState>();

  final TextEditingController _guestFirstNameController =
      TextEditingController();
  final TextEditingController _guestLastNameController =
      TextEditingController();
  final TextEditingController _guestPhoneController = TextEditingController();
  final TextEditingController _guestEmailController = TextEditingController();

  final TextEditingController _loginIdentifierController =
      TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();

  final TextEditingController _signupFirstNameController =
      TextEditingController();
  final TextEditingController _signupLastNameController =
      TextEditingController();
  final TextEditingController _signupPhoneController = TextEditingController();
  final TextEditingController _signupEmailController = TextEditingController();
  final TextEditingController _signupPasswordController =
      TextEditingController();

  final TextEditingController _forgotEmailController = TextEditingController();

  late final DateTime _today;
  late final ProviderSubscription<AuthState> _authStateSubscription;
  late final ProviderSubscription<ReservationSessionState>
  _reservationSessionSubscription;
  late final ProviderSubscription<String?> _reservationSalonIdSubscription;
  List<_BarberOption> _barbers = const [];
  List<_ServiceOption> _services = const [];
  List<_SlotOption> _availableSlots = const [];
  List<_QuickSuggestion> _quickSuggestions = const [];
  Map<String, ReservationMonthAvailability> _monthAvailability = const {};
  String? _loadedBarbersReservationSalonId;

  bool _policyDialogShown = false;
  bool _guestConsent = false;
  bool _bookingBusy = false;
  bool _signupConsent = true;
  bool _barbersLoading = false;
  bool _servicesLoading = false;
  bool _slotsLoading = false;
  bool _quickSuggestionsLoading = false;
  bool _monthAvailabilityLoading = false;
  bool _reservationSessionApplied = false;
  bool _reservationSessionOverride = false;
  String? _reservationSessionUserId;

  String? _barbersError;
  String? _servicesError;
  String? _slotsError;
  String? _quickSuggestionsError;

  _ReservationStep _step = _ReservationStep.barber;
  _AuthMode _authMode = _AuthMode.choice;
  _BarberOption? _selectedBarber;
  _ServiceOption? _selectedService;
  DateTime? _selectedDate;
  _SlotOption? _selectedSlot;
  DateTime? _calendarMonth;
  String? _connectedClientName;
  ReservationBooking? _booking;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _calendarMonth = DateTime(_today.year, _today.month);
    _authStateSubscription = ref.listenManual<AuthState>(
      authStateProvider,
      _handleAuthStateChanged,
    );
    _reservationSessionSubscription = ref.listenManual<ReservationSessionState>(
      reservationSessionProvider,
      _handleReservationSessionChanged,
    );
    _reservationSalonIdSubscription = ref.listenManual<String?>(
      selectedReservationSalonIdForRdvProvider,
      _handleReservationSalonIdChanged,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleAuthStateChanged(null, ref.read(authStateProvider));
      _handleReservationSessionChanged(
        null,
        ref.read(reservationSessionProvider),
      );
      _handleReservationSalonIdChanged(
        null,
        ref.read(selectedReservationSalonIdForRdvProvider),
      );
      unawaited(_showPolicyDialogIfNeeded());
    });
  }

  @override
  void dispose() {
    _authStateSubscription.close();
    _reservationSessionSubscription.close();
    _reservationSalonIdSubscription.close();
    // Keep provider writes out of dispose; Riverpod rejects mutations while unmounting.
    _scrollController.dispose();
    _guestFirstNameController.dispose();
    _guestLastNameController.dispose();
    _guestPhoneController.dispose();
    _guestEmailController.dispose();
    _loginIdentifierController.dispose();
    _loginPasswordController.dispose();
    _signupFirstNameController.dispose();
    _signupLastNameController.dispose();
    _signupPhoneController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _forgotEmailController.dispose();
    super.dispose();
  }

  Salon? _selectedSalonFrom(List<Salon> salons, String? selectedSalonId) {
    if (selectedSalonId == null) return null;
    for (final salon in salons) {
      if (salon.id == selectedSalonId) return salon;
    }
    return null;
  }

  String? _currentReservationSalonId([Salon? selectedSalon]) {
    if (selectedSalon != null) {
      return selectedSalon.reservationSalonId;
    }

    final selectedReservationSalonId = ref.read(
      selectedReservationSalonIdForRdvProvider,
    );
    if (selectedReservationSalonId != null &&
        selectedReservationSalonId.trim().isNotEmpty) {
      return selectedReservationSalonId.trim();
    }

    final selectedSalonId = ref.read(selectedSalonIdForRdvProvider);
    if (selectedSalonId == null || selectedSalonId.trim().isEmpty) {
      return null;
    }

    final salonsAsync = ref.read(salonsListProvider);
    return salonsAsync.maybeWhen(
      data: (salons) {
        final selected = _selectedSalonFrom(salons, selectedSalonId);
        return selected?.reservationSalonId;
      },
      orElse: () => null,
    );
  }

  void _resetReservationFlow() {
    _selectedBarber = null;
    _selectedService = null;
    _selectedDate = null;
    _selectedSlot = null;
    _calendarMonth = DateTime(_today.year, _today.month);
    _authMode = _AuthMode.choice;
    _bookingBusy = false;
    _guestConsent = false;
    _signupConsent = true;
    _booking = null;
    _barbers = const [];
    _services = const [];
    _availableSlots = const [];
    _quickSuggestions = const [];
    _monthAvailability = const {};
    _barbersError = null;
    _servicesError = null;
    _slotsError = null;
    _quickSuggestionsError = null;
    _barbersLoading = false;
    _servicesLoading = false;
    _slotsLoading = false;
    _quickSuggestionsLoading = false;
    _monthAvailabilityLoading = false;
    _loadedBarbersReservationSalonId = null;
    _step = _ReservationStep.barber;
    FocusScope.of(context).unfocus();
  }

  void _selectSalon(Salon salon) {
    setState(_resetReservationFlow);
    ref.read(selectedSalonIdForRdvProvider.notifier).state = salon.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTop();
    });
  }

  void _clearSalonSelection() {
    ref.read(selectedSalonIdForRdvProvider.notifier).state = null;
    setState(_resetReservationFlow);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTop();
    });
  }

  Future<void> _showPolicyDialogIfNeeded() async {
    if (_policyDialogShown || !mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    _policyDialogShown = true;

    final accepted =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.86),
          builder: (dialogContext) {
            bool checked = false;

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C0C0C),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 44,
                              offset: Offset(0, 22),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 2),
                            const Text(
                              'NOS ENGAGEMENTS MUTUELS',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: _titleFont,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pour garantir la meilleure expérience à chacun',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 12.5,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _PolicyRuleCard(
                              title: 'PONCTUALITÉ',
                              description:
                                  'Au-delà de 5 minutes de retard, nous nous réservons le droit de refuser votre rendez-vous afin de ne pas décaler les clients suivants. Cette prestation sera facturée comme un rendez-vous non honoré.',
                              icon: Icons.schedule_outlined,
                            ),
                            const SizedBox(height: 10),
                            _PolicyRuleCard(
                              title: 'ANNULATION',
                              description:
                                  'Vous pouvez annuler jusqu’à 12 heures avant votre rendez-vous via le lien dans votre email de confirmation ou en nous envoyant un message.',
                              icon: Icons.calendar_month_outlined,
                            ),
                            const SizedBox(height: 10),
                            _PolicyRuleCard(
                              title: 'RENDEZ-VOUS NON HONORÉ',
                              description:
                                  'En cas d’absence sans prévenir, la prestation sera facturée à 100% lors de votre prochain passage. Chaque créneau réservé est un créneau qu’un autre client aurait pu prendre.',
                              icon: Icons.shield_outlined,
                            ),
                            const SizedBox(height: 14),
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setDialogState(() {
                                  checked = !checked;
                                });
                              },
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: checked
                                          ? Colors.white
                                          : const Color(0xFF1D1D1D),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: checked
                                            ? Colors.white
                                            : Colors.white.withValues(
                                                alpha: 0.22,
                                              ),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: checked
                                          ? Colors.black
                                          : Colors.transparent,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "J’ai lu et j’accepte ces conditions",
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                        fontSize: 13,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 48,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: checked ? Colors.white : _disabled,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: checked
                                        ? Colors.transparent
                                        : Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: checked
                                        ? () {
                                            Navigator.of(
                                              dialogContext,
                                            ).pop(true);
                                          }
                                        : null,
                                    child: Center(
                                      child: Text(
                                        'RÉSERVER MON CRÉNEAU',
                                        style: TextStyle(
                                          fontFamily: _titleFont,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.0,
                                          color: checked
                                              ? Colors.black
                                              : Colors.white.withValues(
                                                  alpha: 0.2,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ) ??
        false;

    if (!mounted || !accepted) return;
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _setStep(_ReservationStep step) {
    if (_step == step) return;
    setState(() {
      _step = step;
    });
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTop();
    });
  }

  void _handleBack() {
    final selectedSalonId = ref.read(selectedSalonIdForRdvProvider);
    if (selectedSalonId == null) {
      context.go('/home');
      return;
    }

    if (_step == _ReservationStep.success) {
      setState(() {
        _step = _ReservationStep.booking;
        _authMode = _AuthMode.choice;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTop();
      });
      return;
    }

    if (_step == _ReservationStep.booking && _authMode != _AuthMode.choice) {
      setState(() {
        _authMode = _AuthMode.choice;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTop();
      });
      return;
    }

    if (_step == _ReservationStep.booking) {
      _setStep(_ReservationStep.date);
      return;
    }

    if (_step == _ReservationStep.date) {
      _setStep(_ReservationStep.service);
      return;
    }

    if (_step == _ReservationStep.service) {
      _setStep(_ReservationStep.barber);
      return;
    }

    if (_step == _ReservationStep.barber) {
      _clearSalonSelection();
      return;
    }

    context.go('/home');
  }

  void _openAccount() {
    context.go('/compte');
  }

  void _showMessage(String message) {
    AppSnackBar.show(
      context,
      message,
      backgroundColor: const Color(0xFF1A1A1A),
      foregroundColor: Colors.white,
      icon: Icons.info_outline_rounded,
    );
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatShortDate(DateTime date) {
    const months = <String>[
      'JAN',
      'FEV',
      'MAR',
      'AVR',
      'MAI',
      'JUN',
      'JUL',
      'AOU',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}';
  }

  String _formatWeekdayShort(DateTime date) {
    const weekdays = <String>['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM'];
    return weekdays[date.weekday - 1];
  }

  MapEntry<String, String> _splitFullName(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return const MapEntry('', '');
    }
    if (parts.length == 1) {
      return MapEntry(parts.first, '');
    }
    return MapEntry(parts.first, parts.skip(1).join(' '));
  }

  String _friendlyErrorMessage(Object error) {
    if (error is ApiError) {
      return error.getFriendlyMessage();
    }
    return 'Une erreur est survenue. Veuillez reessayer.';
  }

  bool _isOutsideContract(_BarberOption barber, DateTime date) {
    final dateKey = _dateKey(date);
    if (barber.contractStart != null &&
        dateKey.compareTo(barber.contractStart!) < 0) {
      return true;
    }
    if (barber.contractEnd != null &&
        dateKey.compareTo(barber.contractEnd!) > 0) {
      return true;
    }
    return false;
  }

  bool _isOffDay(_BarberOption barber, DateTime date) {
    final dateKey = _dateKey(date);
    if (_isOutsideContract(barber, date)) {
      return true;
    }
    if (barber.offDates.contains(dateKey)) {
      return true;
    }
    if (barber.workDates.contains(dateKey)) {
      return false;
    }
    if (barber.isGuest && barber.guestDates.isNotEmpty) {
      return !barber.guestDates.contains(dateKey);
    }
    final dayIndex = date.weekday == DateTime.sunday ? 6 : date.weekday - 1;
    return barber.offDays.contains(dayIndex);
  }

  bool _canUseDateForSelection(DateTime date) {
    final today = DateTime(_today.year, _today.month, _today.day);
    final candidate = DateTime(date.year, date.month, date.day);
    if (candidate.isBefore(today)) return false;
    final maxDate = DateTime(_today.year, _today.month + 6, _today.day);
    if (candidate.isAfter(maxDate)) return false;
    if (_selectedBarber != null && !_selectedBarber!.isAny) {
      return !_isOffDay(_selectedBarber!, candidate);
    }
    return true;
  }

  ReservationMonthAvailability? _monthAvailabilityFor(DateTime date) {
    return _monthAvailability[_dateKey(date)];
  }

  int _selectedServiceDurationMinutes([DateTime? date]) {
    final service = _selectedService;
    if (service == null) return 30;
    return service.durationForDate(date ?? _selectedDate ?? _today);
  }

  String _bookingBarberId() {
    final barber = _selectedBarber;
    if (barber == null) return '';
    if (barber.isAny) {
      return _selectedSlot?.barberId ?? '';
    }
    return barber.id;
  }

  String _bookingBarberName() {
    final booking = _booking;
    if (booking != null && booking.barberName.isNotEmpty) {
      return booking.barberName;
    }
    final barber = _selectedBarber;
    if (barber == null) return 'Peu importe';
    if (barber.isAny) {
      return _selectedSlot?.barberName ?? 'A selectionner';
    }
    return barber.name;
  }

  String _bookingServiceName() {
    final booking = _booking;
    if (booking != null && booking.serviceName.isNotEmpty) {
      return booking.serviceName;
    }
    return _selectedService?.name ?? 'A selectionner';
  }

  String _bookingDateLabel() {
    final booking = _booking;
    if (booking != null && booking.date.isNotEmpty) {
      final parsed = DateTime.tryParse(booking.date);
      if (parsed != null) {
        return _formatLongDate(parsed);
      }
    }
    final date = _selectedDate;
    if (date == null) return 'A selectionner';
    return _formatLongDate(date);
  }

  String _bookingTimeLabel() {
    final booking = _booking;
    if (booking != null && booking.startTime.isNotEmpty) {
      return booking.startTime.length >= 5
          ? booking.startTime.substring(0, 5)
          : booking.startTime;
    }
    return _selectedSlot?.time ?? 'A selectionner';
  }

  void _prefillFormsFromUser(User user) {
    final fullName = user.fullName?.trim() ?? '';
    final email = user.email.trim();
    final phone = user.phoneNumber.trim();

    if (fullName.isNotEmpty) {
      final nameParts = _splitFullName(fullName);
      if (_guestFirstNameController.text.trim().isEmpty) {
        _guestFirstNameController.text = nameParts.key;
      }
      if (_guestLastNameController.text.trim().isEmpty &&
          nameParts.value.isNotEmpty) {
        _guestLastNameController.text = nameParts.value;
      }
      if (_signupFirstNameController.text.trim().isEmpty) {
        _signupFirstNameController.text = nameParts.key;
      }
      if (_signupLastNameController.text.trim().isEmpty &&
          nameParts.value.isNotEmpty) {
        _signupLastNameController.text = nameParts.value;
      }
    }

    if (_guestEmailController.text.trim().isEmpty) {
      _guestEmailController.text = email;
    }
    if (_signupEmailController.text.trim().isEmpty) {
      _signupEmailController.text = email;
    }
    if (_loginIdentifierController.text.trim().isEmpty) {
      _loginIdentifierController.text = email.isNotEmpty ? email : phone;
    }
    if (_guestPhoneController.text.trim().isEmpty && phone.isNotEmpty) {
      _guestPhoneController.text = phone;
    }
    if (_signupPhoneController.text.trim().isEmpty && phone.isNotEmpty) {
      _signupPhoneController.text = phone;
    }
  }

  void _prefillFormsFromReservationClient(ReservationClientProfile user) {
    final fullName = user.fullName.trim();
    final email = user.email.trim();
    final phone = user.phone.trim();

    if (user.firstName.trim().isNotEmpty &&
        _guestFirstNameController.text.trim().isEmpty) {
      _guestFirstNameController.text = user.firstName.trim();
    }
    if (user.lastName.trim().isNotEmpty &&
        _guestLastNameController.text.trim().isEmpty) {
      _guestLastNameController.text = user.lastName.trim();
    }
    if (user.firstName.trim().isNotEmpty &&
        _signupFirstNameController.text.trim().isEmpty) {
      _signupFirstNameController.text = user.firstName.trim();
    }
    if (user.lastName.trim().isNotEmpty &&
        _signupLastNameController.text.trim().isEmpty) {
      _signupLastNameController.text = user.lastName.trim();
    }
    if (_guestEmailController.text.trim().isEmpty) {
      _guestEmailController.text = email;
    }
    if (_signupEmailController.text.trim().isEmpty) {
      _signupEmailController.text = email;
    }
    if (_loginIdentifierController.text.trim().isEmpty) {
      _loginIdentifierController.text = email.isNotEmpty ? email : phone;
    }
    if (_guestPhoneController.text.trim().isEmpty && phone.isNotEmpty) {
      _guestPhoneController.text = phone;
    }
    if (_signupPhoneController.text.trim().isEmpty && phone.isNotEmpty) {
      _signupPhoneController.text = phone;
    }

    _connectedClientName = fullName.isNotEmpty ? fullName : email;
    _reservationSessionApplied = true;
    _reservationSessionUserId = user.id;
  }

  void _applyReservationSessionState(ReservationSessionState sessionState) {
    if (sessionState.status != ReservationSessionStatus.authenticated ||
        sessionState.user == null) {
      _reservationSessionApplied = false;
      _reservationSessionOverride = false;
      _reservationSessionUserId = null;
      _connectedClientName = null;
      return;
    }

    if (_reservationSessionOverride) {
      return;
    }

    final user = sessionState.user!;
    if (_reservationSessionApplied && _reservationSessionUserId == user.id) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _prefillFormsFromReservationClient(user);
    });
  }

  void _handleAuthStateChanged(AuthState? previous, AuthState next) {
    if (next.status == AuthStatus.authenticated && next.user != null) {
      final nextUserId = next.user!.id;
      final previousUserId = previous?.user?.id;
      if (_reservationSessionOverride) {
        if (!mounted) return;
        setState(() {
          _reservationSessionOverride = false;
        });
      }
      if (_connectedClientName == null || previousUserId != nextUserId) {
        if (!mounted) return;
        setState(() {
          _prefillFormsFromUser(next.user!);
        });
      }
      final reservationSessionState = ref.read(reservationSessionProvider);
      if (reservationSessionState.status ==
              ReservationSessionStatus.authenticated &&
          reservationSessionState.user != null) {
        _applyReservationSessionState(reservationSessionState);
      }
      return;
    }

    if (next.status == AuthStatus.error && next.errorMessage != null) {
      if (!mounted) return;
      _showMessage(next.errorMessage!);
      ref.read(authStateProvider.notifier).clearError();
    }
  }

  void _handleReservationSessionChanged(
    ReservationSessionState? previous,
    ReservationSessionState next,
  ) {
    if (next.status == ReservationSessionStatus.authenticated &&
        next.user != null) {
      _applyReservationSessionState(next);
      return;
    }

    if (next.status == ReservationSessionStatus.unauthenticated) {
      if (!mounted) return;
      if (_reservationSessionApplied ||
          _reservationSessionOverride ||
          _reservationSessionUserId != null ||
          _connectedClientName != null) {
        setState(() {
          _reservationSessionApplied = false;
          _reservationSessionOverride = false;
          _reservationSessionUserId = null;
          _connectedClientName = null;
        });
      } else {
        _reservationSessionApplied = false;
        _reservationSessionOverride = false;
        _reservationSessionUserId = null;
      }
    }
  }

  void _handleReservationSalonIdChanged(String? previous, String? next) {
    final reservationSalonId = next?.trim();
    if (reservationSalonId == null || reservationSalonId.isEmpty) {
      _loadedBarbersReservationSalonId = null;
      return;
    }

    if (_loadedBarbersReservationSalonId == reservationSalonId &&
        (_barbersLoading || _barbers.isNotEmpty || _barbersError != null)) {
      return;
    }

    unawaited(_loadBarbersForSalon(reservationSalonId));
  }

  void _refreshQuickSuggestions() {
    if (!mounted) return;

    final month = _calendarMonth ?? DateTime(_today.year, _today.month);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime(_today.year, _today.month, _today.day);
    final suggestions = <_QuickSuggestion>[];

    for (var day = 1; day <= lastDay && suggestions.length < 3; day++) {
      final date = DateTime(month.year, month.month, day);
      if (date.isBefore(today)) {
        continue;
      }
      if (!_canUseDateForSelection(date)) {
        continue;
      }

      final availability = _monthAvailabilityFor(date);
      if (_monthAvailability.isNotEmpty &&
          availability != null &&
          availability.total <= 0) {
        continue;
      }

      suggestions.add(
        _QuickSuggestion(
          date: date,
          dayLabel: _formatWeekdayShort(date),
          label:
              date.day == today.day + 1 &&
                  date.month == today.month &&
                  date.year == today.year
              ? 'Demain'
              : _formatShortDate(date),
          slotCount: availability?.total,
          status: availability?.status,
          alternativeCount: availability?.alternatives.length ?? 0,
        ),
      );
    }

    setState(() {
      _quickSuggestions = suggestions;
      _quickSuggestionsLoading = false;
    });
  }

  _BarberOption _mapBarber(ReservationBarber barber) {
    return _BarberOption(
      id: barber.id,
      name: barber.name.trim().isEmpty ? 'Barber' : barber.name.trim(),
      subtitle: _barberSubtitle(barber),
      photoUrl: AppConfig.resolvePublicAssetUrl(barber.photoUrl),
      role: barber.role,
      isAny: false,
      isGuest: barber.isGuest,
      offDays: barber.offDays,
      workDates: barber.workDates,
      offDates: barber.offDates,
      guestDates: barber.guestDates,
      contractStart: barber.contractStart,
      contractEnd: barber.contractEnd,
    );
  }

  String _barberSubtitle(ReservationBarber barber) {
    if (barber.isGuest) {
      return 'Barber invite';
    }
    final role = barber.role.trim();
    if (role.isEmpty) {
      return 'Barbier';
    }
    final normalized = role.toLowerCase();
    if (normalized.contains('barber') || normalized.contains('barbier')) {
      return 'Barbier';
    }
    return role;
  }

  _ServiceCategory _inferServiceCategory(ReservationService service) {
    final haystack = '${service.name} ${service.description}'.toLowerCase();
    if (haystack.contains('barbe') ||
        haystack.contains('soin') ||
        haystack.contains('rasage')) {
      return _ServiceCategory.beard;
    }
    if (haystack.contains('enfant') ||
        haystack.contains('college') ||
        haystack.contains('collège') ||
        haystack.contains('lycee') ||
        haystack.contains('lycée') ||
        haystack.contains('étude') ||
        haystack.contains('etude') ||
        haystack.contains('réduit') ||
        haystack.contains('reduit')) {
      return _ServiceCategory.reduced;
    }
    return _ServiceCategory.cuts;
  }

  List<_ServiceOption> _mapServices(List<ReservationService> services) {
    return services
        .map(
          (service) => _ServiceOption(
            id: service.id,
            name: service.name,
            description: service.description,
            priceCents: service.priceCents,
            durationMinutes: service.durationMinutes,
            durationSaturdayMinutes: service.durationSaturdayMinutes,
            customDurationMinutes: service.customDurationMinutes,
            color: service.color,
            category: _inferServiceCategory(service),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _loadBarbersForSalon(String reservationSalonId) async {
    if (!mounted) return;
    _loadedBarbersReservationSalonId = reservationSalonId;
    setState(() {
      _barbersLoading = true;
      _barbersError = null;
      _barbers = const [];
      _selectedBarber = null;
      _selectedService = null;
      _selectedDate = null;
      _selectedSlot = null;
      _services = const [];
      _availableSlots = const [];
      _quickSuggestions = const [];
      _monthAvailability = const {};
      _servicesLoading = false;
      _slotsLoading = false;
      _quickSuggestionsLoading = false;
      _monthAvailabilityLoading = false;
      _servicesError = null;
      _slotsError = null;
      _quickSuggestionsError = null;
    });

    try {
      final repository = ref.read(reservationRepositoryProvider);
      final barbers = await repository.getBarbers(salonId: reservationSalonId);
      if (!mounted || _currentReservationSalonId() != reservationSalonId) {
        return;
      }

      if (barbers.isEmpty) {
        setState(() {
          _barbersLoading = false;
          _barbersError = 'Aucun barber disponible pour le moment.';
        });
        return;
      }

      setState(() {
        _barbers = <_BarberOption>[
          const _BarberOption(
            id: 'any',
            name: 'PEU IMPORTE',
            subtitle: 'Premier barber disponible',
            isAny: true,
          ),
          ...barbers.map(_mapBarber),
        ];
        _barbersLoading = false;
        _barbersError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _barbersLoading = false;
        _barbersError = _friendlyErrorMessage(error);
      });
    }
  }

  Future<void> _loadServicesForCurrentSelection() async {
    final selectedReservationSalonId = _currentReservationSalonId();
    final barber = _selectedBarber;
    if (selectedReservationSalonId == null || barber == null) {
      return;
    }

    final barberId = barber.isAny ? 'any' : barber.id;
    if (!mounted) return;
    setState(() {
      _servicesLoading = true;
      _servicesError = null;
      _services = const [];
      _selectedService = null;
      _selectedDate = null;
      _selectedSlot = null;
      _availableSlots = const [];
      _quickSuggestions = const [];
      _monthAvailability = const {};
      _slotsLoading = false;
      _quickSuggestionsLoading = false;
      _monthAvailabilityLoading = false;
      _slotsError = null;
      _quickSuggestionsError = null;
    });

    try {
      final repository = ref.read(reservationRepositoryProvider);
      final services = await repository.getServices(
        salonId: selectedReservationSalonId,
        barberId: barberId,
      );
      if (!mounted ||
          _currentReservationSalonId() != selectedReservationSalonId ||
          _selectedBarber?.id != barber.id) {
        return;
      }

      final mapped = _mapServices(services);
      if (mapped.isEmpty) {
        setState(() {
          _servicesLoading = false;
          _servicesError = 'Aucune prestation disponible pour ce barber.';
        });
        return;
      }

      setState(() {
        _services = mapped;
        _servicesLoading = false;
        _servicesError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _servicesLoading = false;
        _servicesError = _friendlyErrorMessage(error);
      });
    }
  }

  Future<void> _loadMonthAvailability() async {
    final selectedReservationSalonId = _currentReservationSalonId();
    final barber = _selectedBarber;
    final service = _selectedService;
    if (selectedReservationSalonId == null ||
        barber == null ||
        service == null) {
      return;
    }

    final month = _calendarMonth ?? DateTime(_today.year, _today.month);
    final barberId = barber.isAny ? 'any' : barber.id;
    if (!mounted) return;
    setState(() {
      _monthAvailabilityLoading = true;
      _quickSuggestionsLoading = true;
      _quickSuggestionsError = null;
    });

    try {
      final repository = ref.read(reservationRepositoryProvider);
      final availability = await repository.getMonthAvailability(
        salonId: selectedReservationSalonId,
        serviceId: service.id,
        year: month.year,
        month: month.month,
        barberId: barberId,
        includeAlternatives: true,
      );

      if (!mounted ||
          _currentReservationSalonId() != selectedReservationSalonId ||
          _selectedBarber?.id != barber.id ||
          _selectedService?.id != service.id ||
          _calendarMonth?.year != month.year ||
          _calendarMonth?.month != month.month) {
        return;
      }

      setState(() {
        _monthAvailability = availability;
        _monthAvailabilityLoading = false;
      });
      _refreshQuickSuggestions();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _monthAvailabilityLoading = false;
        _quickSuggestionsError = _friendlyErrorMessage(error);
      });
      _refreshQuickSuggestions();
    }
  }

  Future<void> _loadSlotsForSelectedDate() async {
    final selectedReservationSalonId = _currentReservationSalonId();
    final barber = _selectedBarber;
    final service = _selectedService;
    final date = _selectedDate;
    if (selectedReservationSalonId == null ||
        barber == null ||
        service == null ||
        date == null) {
      return;
    }

    final barberId = barber.isAny ? 'any' : barber.id;
    final dateKey = _dateKey(date);
    if (!mounted) return;

    try {
      final repository = ref.read(reservationRepositoryProvider);
      final slots = await repository.getAvailability(
        salonId: selectedReservationSalonId,
        serviceId: service.id,
        date: dateKey,
        barberId: barberId,
      );

      if (!mounted ||
          _currentReservationSalonId() != selectedReservationSalonId ||
          _selectedBarber?.id != barber.id ||
          _selectedService?.id != service.id ||
          _selectedDate == null ||
          !_isSameDate(_selectedDate!, date)) {
        return;
      }

      setState(() {
        _availableSlots = slots
            .map(
              (slot) => _SlotOption(
                time: slot.time,
                barberId: slot.barberId,
                barberName: slot.barberName,
              ),
            )
            .toList(growable: false);
        _slotsLoading = false;
        _slotsError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _slotsLoading = false;
        _slotsError = _friendlyErrorMessage(error);
        _availableSlots = const [];
      });
    }
  }

  void _selectBarber(_BarberOption option) {
    setState(() {
      _selectedBarber = option;
      _selectedService = null;
      _selectedDate = null;
      _selectedSlot = null;
      _calendarMonth = DateTime(_today.year, _today.month);
      _authMode = _AuthMode.choice;
      _services = const [];
      _availableSlots = const [];
      _quickSuggestions = const [];
      _monthAvailability = const {};
      _servicesError = null;
      _slotsError = null;
      _quickSuggestionsError = null;
      _servicesLoading = true;
      _slotsLoading = false;
      _quickSuggestionsLoading = false;
      _monthAvailabilityLoading = false;
    });

    unawaited(_loadServicesForCurrentSelection());
  }

  void _selectService(_ServiceOption option) {
    setState(() {
      _selectedService = option;
      _selectedDate = null;
      _selectedSlot = null;
      _calendarMonth = DateTime(_today.year, _today.month);
      _authMode = _AuthMode.choice;
      _availableSlots = const [];
      _quickSuggestions = const [];
      _monthAvailability = const {};
      _slotsError = null;
      _quickSuggestionsError = null;
      _slotsLoading = false;
      _quickSuggestionsLoading = true;
      _monthAvailabilityLoading = true;
    });

    unawaited(_loadMonthAvailability());
  }

  void _selectDate(DateTime date) {
    final sameDate = _selectedDate != null && _isSameDate(_selectedDate!, date);
    setState(() {
      _selectedDate = date;
      if (!sameDate) {
        _selectedSlot = null;
      }
      _calendarMonth = DateTime(date.year, date.month);
      _availableSlots = const [];
      _slotsError = null;
      _slotsLoading = true;
    });

    unawaited(_loadSlotsForSelectedDate());
  }

  void _selectSlot(_SlotOption slot) {
    setState(() {
      _selectedSlot = slot;
    });
  }

  void _continuePrimaryFlow() {
    if (_step == _ReservationStep.barber) {
      if (_selectedBarber == null) {
        _showMessage('Choisissez un barber pour continuer.');
        return;
      }
      _setStep(_ReservationStep.service);
      return;
    }

    if (_step == _ReservationStep.service) {
      if (_selectedService == null) {
        _showMessage('Sélectionnez une prestation.');
        return;
      }
      setState(() {
        _selectedDate = null;
        _selectedSlot = null;
        _calendarMonth = DateTime(_today.year, _today.month);
        _availableSlots = const [];
        _quickSuggestions = const [];
        _monthAvailability = const {};
        _quickSuggestionsLoading = true;
        _monthAvailabilityLoading = true;
      });
      unawaited(_loadMonthAvailability());
      _setStep(_ReservationStep.date);
      return;
    }

    if (_step == _ReservationStep.date) {
      if (_selectedDate == null || _selectedSlot == null) {
        _showMessage('Choisissez une date et un créneau.');
        return;
      }
      _setStep(_ReservationStep.booking);
    }
  }

  bool _isSelectableDate(DateTime date) {
    return _canUseDateForSelection(date);
  }

  List<_SlotOption> _availableSlotsForDate(DateTime date) {
    if (_selectedDate == null || !_isSameDate(date, _selectedDate!)) {
      return const [];
    }
    return _availableSlots;

    const times = <String>[
      '09:00',
      '09:30',
      '10:00',
      '10:30',
      '11:00',
      '11:30',
      '13:00',
      '13:30',
      '14:00',
      '14:30',
      '15:00',
      '15:30',
      '16:00',
      '16:30',
      '17:00',
      '17:30',
      '18:00',
      '18:30',
    ];

    const barberRotation = <String>[
      'Louay',
      'Nathan',
      'Alan',
      'Tom',
      'Clément',
      'Louay',
      'Nathan',
      'Alan',
      'Tom',
      'Clément',
      'Louay',
      'Nathan',
      'Alan',
      'Tom',
      'Clément',
      'Louay',
      'Nathan',
      'Alan',
    ];

    return List.generate(times.length, (index) {
      return _SlotOption(time: times[index], barberName: barberRotation[index]);
    });
  }

  List<_QuickSuggestion> _visibleQuickSuggestions() {
    return _quickSuggestions;

    final result = <_QuickSuggestion>[];
    final daysShort = <String>['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
    for (var offset = 1; offset <= 3; offset++) {
      final date = DateTime(_today.year, _today.month, _today.day + offset);
      final label = offset == 1
          ? 'Demain'
          : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
      result.add(
        _QuickSuggestion(
          date: date,
          dayLabel: daysShort[date.weekday % 7],
          label: label,
        ),
      );
    }
    return result;
  }

  List<_CalendarDay> _calendarDays() {
    final month = _calendarMonth ?? DateTime(_today.year, _today.month);
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final leadingEmpty = (firstDay.weekday + 6) % 7;
    final days = <_CalendarDay>[];

    for (var i = 0; i < leadingEmpty; i++) {
      days.add(const _CalendarDay.empty());
    }

    for (var day = 1; day <= lastDay.day; day++) {
      final date = DateTime(month.year, month.month, day);
      final availability = _monthAvailabilityFor(date);
      days.add(
        _CalendarDay(
          date: date,
          isPast: date.isBefore(
            DateTime(_today.year, _today.month, _today.day),
          ),
          isAvailable: availability != null
              ? availability.total > 0
              : _isSelectableDate(date),
          isSelected:
              _selectedDate != null && _isSameDate(date, _selectedDate!),
          status: availability?.status,
          slotCount: availability?.total,
          alternativeCount: availability?.alternatives.length ?? 0,
        ),
      );
    }

    while (days.length % 7 != 0) {
      days.add(const _CalendarDay.empty());
    }
    return days;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatLongDate(DateTime date) {
    const days = <String>[
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    const months = <String>[
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatMonthLabel(DateTime date) {
    const months = <String>[
      'JANVIER',
      'FÉVRIER',
      'MARS',
      'AVRIL',
      'MAI',
      'JUIN',
      'JUILLET',
      'AOÛT',
      'SEPTEMBRE',
      'OCTOBRE',
      'NOVEMBRE',
      'DÉCEMBRE',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatPrice(int cents) {
    final euros = (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
    return '$euros €';
  }

  String get _summaryBarberName {
    return _bookingBarberName();
    if (_selectedBarber == null) return 'Peu importe';
    if (_selectedBarber!.isAny) {
      return _selectedSlot?.barberName ?? 'À sélectionner';
    }
    return _selectedBarber!.name;
  }

  String get _summaryServiceName {
    return _bookingServiceName();
    return _selectedService?.name ?? 'Coupe Homme sans barbe';
  }

  String get _summaryDateLabel {
    return _bookingDateLabel();
    final date = _selectedDate;
    if (date == null) return 'À sélectionner';
    return _formatLongDate(date);
  }

  String get _summaryTimeLabel => _bookingTimeLabel();

  bool get _showActionBar {
    final selectedSalonId = ref.read(selectedSalonIdForRdvProvider);
    return _step != _ReservationStep.booking &&
        _step != _ReservationStep.success &&
        _authMode == _AuthMode.choice &&
        selectedSalonId != null;
  }

  bool get _actionEnabled {
    switch (_step) {
      case _ReservationStep.barber:
        return _selectedBarber != null;
      case _ReservationStep.service:
        return _selectedService != null;
      case _ReservationStep.date:
        return _selectedDate != null && _selectedSlot != null;
      case _ReservationStep.booking:
      case _ReservationStep.success:
        return false;
    }
  }

  String get _actionLabel {
    switch (_step) {
      case _ReservationStep.barber:
      case _ReservationStep.service:
      case _ReservationStep.date:
        return 'CONTINUER';
      case _ReservationStep.booking:
      case _ReservationStep.success:
        return 'CONTINUER';
    }
  }

  Future<void> _handleGuestSubmit() async {
    if (!_guestFormKey.currentState!.validate()) return;
    if (!_guestConsent) {
      _showMessage('Vous devez accepter pour continuer.');
      return;
    }
    await _completeReservation();
  }

  Future<void> _handleLoginSubmit() async {
    if (!_loginFormKey.currentState!.validate()) return;
    final identifier = _loginIdentifierController.text.trim();
    final password = _loginPasswordController.text;
    final authController = ref.read(authStateProvider.notifier);

    if (identifier.contains('@')) {
      await authController.login(email: identifier, password: password);
    } else {
      await authController.login(phoneNumber: identifier, password: password);
    }

    final authState = ref.read(authStateProvider);
    if (authState.status == AuthStatus.authenticated &&
        authState.user != null) {
      setState(() {
        _prefillFormsFromUser(authState.user!);
      });
      _showMessage('Connexion reussie.');
      return;
    }

    if (authState.errorMessage != null) {
      _showMessage(authState.errorMessage!);
      ref.read(authStateProvider.notifier).clearError();
      return;
    }
  }

  Future<void> _handleSignupSubmit() async {
    if (!_signupFormKey.currentState!.validate()) return;
    final firstName = _signupFirstNameController.text.trim();
    final lastName = _signupLastNameController.text.trim();
    final phone = _signupPhoneController.text.trim();
    final email = _signupEmailController.text.trim();
    final password = _signupPasswordController.text;

    final authController = ref.read(authStateProvider.notifier);
    await authController.register(
      email: email,
      phoneNumber: phone,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );

    final authState = ref.read(authStateProvider);
    if (authState.status == AuthStatus.authenticated &&
        authState.user != null) {
      setState(() {
        _prefillFormsFromUser(authState.user!);
      });
      _showMessage('Compte cree.');
      return;
    }

    if (authState.errorMessage != null) {
      _showMessage(authState.errorMessage!);
      ref.read(authStateProvider.notifier).clearError();
      return;
    }
  }

  Future<void> _handleForgotSubmit() async {
    if (!_forgotFormKey.currentState!.validate()) return;
    final email = _forgotEmailController.text.trim();
    final authController = ref.read(authStateProvider.notifier);
    await authController.forgotPassword(email);

    final authState = ref.read(authStateProvider);
    if (authState.errorMessage != null) {
      _showMessage(authState.errorMessage!);
      ref.read(authStateProvider.notifier).clearError();
      return;
    }

    _showMessage('Si un compte existe, un lien a ete envoye.');
    return;
    _showMessage(
      'Si un compte existe avec cet email, un lien de réinitialisation fictif a été envoyé.',
    );
  }

  Future<void> _completeReservation() async {
    if (_bookingBusy) return;

    final selectedReservationSalonId = _currentReservationSalonId();
    final barber = _selectedBarber;
    final service = _selectedService;
    final date = _selectedDate;
    final slot = _selectedSlot;

    if (selectedReservationSalonId == null ||
        barber == null ||
        service == null ||
        date == null ||
        slot == null) {
      _showMessage(
        'Choisissez le barber, la prestation, la date et le creneau.',
      );
      return;
    }

    final bookingBarberId = _bookingBarberId();
    if (bookingBarberId.isEmpty) {
      _showMessage('Impossible de determiner le barber du rendez-vous.');
      return;
    }

    final firstName = _guestFirstNameController.text.trim();
    final lastName = _guestLastNameController.text.trim();
    final phone = _guestPhoneController.text.trim();
    final email = _guestEmailController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        phone.isEmpty ||
        email.isEmpty) {
      _showMessage('Veuillez completer vos coordonnees.');
      return;
    }

    setState(() {
      _bookingBusy = true;
    });

    try {
      final repository = ref.read(reservationRepositoryProvider);
      final booking = await repository.createBooking(
        salonId: selectedReservationSalonId,
        barberId: bookingBarberId,
        serviceId: service.id,
        date: _dateKey(date),
        startTime: slot.time,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        email: email,
      );

      if (!mounted) return;
      setState(() {
        _booking = booking;
        _bookingBusy = false;
        _step = _ReservationStep.success;
      });
      FocusScope.of(context).unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTop();
      });
      _showMessage(
        booking.hasAccount
            ? 'Rendez-vous confirme pour votre compte.'
            : 'Rendez-vous confirme. Verifiez votre email.',
      );
      return;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _bookingBusy = false;
      });
      _showMessage(_friendlyErrorMessage(error));
      return;
    }
  }

  void _chooseAuthMode(_AuthMode mode) {
    ref.read(authStateProvider.notifier).clearError();
    setState(() {
      _authMode = mode;
    });
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTop();
    });
  }

  void _goToMonth(int delta) {
    final current = _calendarMonth ?? DateTime(_today.year, _today.month);
    final target = DateTime(current.year, current.month + delta);
    final minMonth = DateTime(_today.year, _today.month);
    final maxMonth = DateTime(_today.year, _today.month + 6);
    final clamped = target.isBefore(minMonth)
        ? minMonth
        : (target.isAfter(maxMonth) ? maxMonth : target);
    setState(() {
      _calendarMonth = clamped;
    });
    if (_selectedBarber != null && _selectedService != null) {
      unawaited(_loadMonthAvailability());
    }
  }

  void _resetToAuthChoice() {
    setState(() {
      _authMode = _AuthMode.choice;
      _reservationSessionOverride = true;
    });
    ref.read(authStateProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final currentMonth = _calendarMonth ?? DateTime(_today.year, _today.month);
    final salonsAsync = ref.watch(salonsListProvider);
    final selectedSalonId = ref.watch(selectedSalonIdForRdvProvider);

    return Scaffold(
      backgroundColor: _pageBackground,
      body: Stack(
        children: [
          const Positioned.fill(child: _ReservationBackdrop()),
          SafeArea(
            bottom: false,
            child: salonsAsync.when(
              data: (salons) {
                final selectedSalon = _selectedSalonFrom(
                  salons,
                  selectedSalonId,
                );
                if (selectedSalon == null) {
                  return _buildSalonSelectionView(context, salons);
                }
                final reservationSalonId = selectedSalon.reservationSalonId;
                return _buildReservationFlow(
                  context: context,
                  bottomInset: bottomInset,
                  currentMonth: currentMonth,
                  selectedSalon: selectedSalon,
                  reservationSalonId: reservationSalonId,
                );
              },
              loading: () => _buildLoadingState(context),
              error: (error, stackTrace) =>
                  _buildSalonSelectionError(context, error, stackTrace),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationFlow({
    required BuildContext context,
    required double bottomInset,
    required DateTime currentMonth,
    required Salon selectedSalon,
    required String reservationSalonId,
  }) {
    final dockReserve = bottomInset + 108.0;
    final contentBottomPadding = _showActionBar ? 20.0 : 48.0;
    final headerTitle = 'RÉSERVER À ${selectedSalon.city.toUpperCase()}';
    final headerSubtitle = selectedSalon.name.toUpperCase();

    return Padding(
      padding: EdgeInsets.only(bottom: dockReserve),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: _ReservationTopHeader(
              title: headerTitle,
              subtitle: headerSubtitle,
              onBack: _handleBack,
              onProfile: _openAccount,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: _ReservationStepper(step: _step),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                contentBottomPadding + 12,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final offsetTween = Tween<Offset>(
                      begin: const Offset(0.02, 0.02),
                      end: Offset.zero,
                    );
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: animation.drive(offsetTween),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_step.name),
                    child: _buildCurrentStep(
                      context,
                      currentMonth,
                      reservationSalonId,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showActionBar) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _ReservationActionBar(
                enabled: _actionEnabled,
                loading: _bookingBusy,
                label: _actionLabel,
                onPressed: _continuePrimaryFlow,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSalonSelectionView(BuildContext context, List<Salon> salons) {
    final selectionSalons = salons.take(2).toList(growable: false);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 24;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: _ReservationTopHeader(
            title: 'CHOISISSEZ VOTRE SALON',
            subtitle: 'BarberClub Grenoble et Meylan',
            onBack: () => context.go('/home'),
            onProfile: _openAccount,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: selectionSalons.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Aucun salon disponible pour le moment.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 6, 16, bottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'NOS SALONS',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontSize: 28,
                              letterSpacing: 2.6,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choisissez l’adresse qui vous convient pour démarrer votre réservation.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: math.max(
                          430.0,
                          MediaQuery.sizeOf(context).height * 0.72,
                        ),
                        child: _SalonChoiceSplit(
                          salons: selectionSalons,
                          onTapSalon: _selectSalon,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white70),
    );
  }

  Widget _buildSalonSelectionError(
    BuildContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    final message = getSalonErrorMessage(error, stackTrace);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => ref.invalidate(salonsListProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep(
    BuildContext context,
    DateTime currentMonth,
    String reservationSalonId,
  ) {
    switch (_step) {
      case _ReservationStep.barber:
        return _buildBarberStep(context, reservationSalonId);
      case _ReservationStep.service:
        return _buildServiceStep(context);
      case _ReservationStep.date:
        return _buildDateStep(context, currentMonth);
      case _ReservationStep.booking:
        return _buildBookingStep(context);
      case _ReservationStep.success:
        return _buildSuccessStep(context);
    }
  }

  Widget _buildPanelShell({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _panelBackground.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x7A000000),
            blurRadius: 34,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontFamily: _titleFont,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            height: 1.0,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.48),
            fontSize: 14.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildBarberStep(BuildContext context, String reservationSalonId) {
    final isWaitingForBarbers =
        reservationSalonId.isNotEmpty &&
        _barbers.isEmpty &&
        _barbersError == null;

    if (_barbersLoading || isWaitingForBarbers) {
      return _buildPanelShell(
        child: const SizedBox(
          height: 360,
          child: Center(
            child: CircularProgressIndicator(color: Colors.white70),
          ),
        ),
      );
    }

    if (_barbersError != null) {
      return _buildPanelShell(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSectionHeader(
                'Votre barber',
                'Impossible de charger les barbers',
              ),
              const SizedBox(height: 18),
              Text(
                _barbersError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  final currentReservationSalonId =
                      _currentReservationSalonId();
                  if (currentReservationSalonId != null) {
                    unawaited(_loadBarbersForSalon(currentReservationSalonId));
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return _buildPanelShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Votre barber',
              'Choisissez votre barber préféré',
            ),
            const SizedBox(height: 18),
            ..._barbers.map(
              (barber) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BarberCard(
                  barber: barber,
                  selected: _selectedBarber?.id == barber.id,
                  onTap: () => _selectBarber(barber),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceStep(BuildContext context) {
    if (_servicesLoading) {
      return _buildPanelShell(
        child: const SizedBox(
          height: 360,
          child: Center(
            child: CircularProgressIndicator(color: Colors.white70),
          ),
        ),
      );
    }

    if (_servicesError != null) {
      return _buildPanelShell(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSectionHeader(
                'Prestation',
                'Impossible de charger les prestations',
              ),
              const SizedBox(height: 18),
              Text(
                _servicesError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _selectedBarber == null
                    ? null
                    : () => unawaited(_loadServicesForCurrentSelection()),
                icon: const Icon(Icons.refresh),
                label: const Text('Reessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final grouped = <_ServiceCategory, List<_ServiceOption>>{
      _ServiceCategory.cuts: [],
      _ServiceCategory.beard: [],
      _ServiceCategory.reduced: [],
    };
    for (final service in _services) {
      grouped[service.category]!.add(service);
    }

    return _buildPanelShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Prestation', 'Sélectionnez votre prestation'),
            const SizedBox(height: 18),
            for (final category in _serviceCategories)
              if (grouped[category]!.isNotEmpty) ...[
                _CategoryHeader(
                  title: _categoryTitle(category),
                  icon: _categoryIcon(category),
                ),
                const SizedBox(height: 10),
                for (final service in grouped[category]!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ServiceCard(
                      service: service,
                      selected: _selectedService?.id == service.id,
                      onTap: () => _selectService(service),
                    ),
                  ),
                const SizedBox(height: 10),
              ],
            _CategoryHeader(title: 'AUTRES', icon: Icons.add_rounded),
            const SizedBox(height: 10),
            const _DisabledServiceCard(
              title: 'Mèches',
              description: 'Appelez le salon au 09 56 30 93 86',
              price: '40,00 €',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateStep(BuildContext context, DateTime currentMonth) {
    final quickSuggestions = _visibleQuickSuggestions();
    final calendarDays = _calendarDays();
    final selectedDate = _selectedDate;
    final availableSlots = selectedDate == null
        ? const <_SlotOption>[]
        : _availableSlotsForDate(selectedDate);

    return _buildPanelShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Date & Heure', 'Choisissez votre créneau'),
            const SizedBox(height: 18),
            Text(
              'PROCHAINS CRÉNEAUX DISPONIBLES',
              style: TextStyle(
                fontFamily: _titleFont,
                fontSize: 11.5,
                letterSpacing: 0.9,
                color: Colors.white.withValues(alpha: 0.42),
              ),
            ),
            const SizedBox(height: 10),
            if (_quickSuggestionsLoading && quickSuggestions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.1,
                      color: Colors.white70,
                    ),
                  ),
                ),
              )
            else if (quickSuggestions.isNotEmpty)
              Row(
                children: [
                  for (final suggestion in quickSuggestions)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _QuickSuggestionCard(
                          suggestion: suggestion,
                          selected:
                              selectedDate != null &&
                              _isSameDate(selectedDate, suggestion.date),
                          onTap: () => _selectDate(suggestion.date),
                        ),
                      ),
                    ),
                ],
              )
            else if (_quickSuggestionsError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _quickSuggestionsError!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Les disponibilites rapides apparaitront ici.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.32),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _DividerLabel(label: 'OU CHOISIR UNE DATE'),
            const SizedBox(height: 12),
            _CalendarHeader(
              monthLabel: _formatMonthLabel(currentMonth),
              canGoPrevious:
                  currentMonth.year > _today.year ||
                  currentMonth.month > _today.month,
              canGoNext: currentMonth.isBefore(
                DateTime(_today.year, _today.month + 6),
              ),
              onPrevious: () => _goToMonth(-1),
              onNext: () => _goToMonth(1),
            ),
            const SizedBox(height: 10),
            const _WeekdaysRow(),
            const SizedBox(height: 6),
            GridView.builder(
              itemCount: calendarDays.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 3,
                crossAxisSpacing: 1,
                mainAxisExtent: 44,
              ),
              itemBuilder: (context, index) {
                final day = calendarDays[index];
                return _CalendarDayCell(
                  day: day,
                  onTap: day.isSelectable
                      ? () {
                          _selectDate(day.date!);
                        }
                      : null,
                );
              },
            ),
            const SizedBox(height: 10),
            if (selectedDate == null)
              Padding(
                padding: const EdgeInsets.only(top: 0),
                child: Text(
                  'Sélectionnez une date pour voir les créneaux disponibles',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.34),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              )
            else ...[
              Text(
                '${availableSlots.length} CRÉNEAUX DISPONIBLES',
                style: TextStyle(
                  fontFamily: _titleFont,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 6),
              _SlotsGrid(
                slots: availableSlots,
                selectedTime: _selectedSlot?.time,
                onTap: _selectSlot,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookingStep(BuildContext context) {
    final authBusy =
        ref.watch(authStateProvider).status == AuthStatus.authenticating;
    final showConnectedReservationPanel =
        _reservationSessionApplied && !_reservationSessionOverride;

    return _buildPanelShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Réservation', 'Finalisez votre rendez-vous'),
            const SizedBox(height: 18),
            _SummaryCard(
              barber: _summaryBarberName,
              service: _summaryServiceName,
              date: _summaryDateLabel,
              time: _summaryTimeLabel,
              duration: _selectedService?.durationMinutes ?? 30,
              price: _formatPrice(_selectedService?.priceCents ?? 2000),
            ),
            const SizedBox(height: 18),
            if (showConnectedReservationPanel) ...[
              _ConnectedPanel(
                name: _connectedClientName ?? 'Client BarberClub',
                loading: authBusy,
                onLogout: _resetToAuthChoice,
                onConfirm: () async {
                  await _completeReservation();
                },
              ),
            ] else if (_authMode == _AuthMode.choice) ...[
              _AuthOptionCard(
                icon: Icons.edit_outlined,
                title: "RÉSERVER EN TANT QU'INVITÉ",
                description:
                    'Sans compte — gestion du RDV par email uniquement',
                onTap: () => _chooseAuthMode(_AuthMode.guest),
              ),
              const SizedBox(height: 10),
              _AuthOptionCard(
                icon: Icons.person_outline_rounded,
                title: 'CONNEXION',
                description: "J'ai déjà un compte",
                onTap: () => _chooseAuthMode(_AuthMode.login),
              ),
              const SizedBox(height: 16),
              _MemberDivider(label: 'PAS ENCORE MEMBRE ?'),
              const SizedBox(height: 14),
              _SignupPromoCard(onTap: () => _chooseAuthMode(_AuthMode.signup)),
            ] else if (_authMode == _AuthMode.guest) ...[
              _GuestReservationForm(
                formKey: _guestFormKey,
                firstNameController: _guestFirstNameController,
                lastNameController: _guestLastNameController,
                phoneController: _guestPhoneController,
                emailController: _guestEmailController,
                consent: _guestConsent,
                loading: authBusy,
                onConsentChanged: (value) {
                  setState(() {
                    _guestConsent = value;
                  });
                },
                onSubmit: _handleGuestSubmit,
                onBack: _resetToAuthChoice,
              ),
            ] else if (_authMode == _AuthMode.login) ...[
              _LoginForm(
                formKey: _loginFormKey,
                identifierController: _loginIdentifierController,
                passwordController: _loginPasswordController,
                loading: authBusy,
                onSubmit: _handleLoginSubmit,
                onForgot: () => _chooseAuthMode(_AuthMode.forgot),
                onBack: _resetToAuthChoice,
              ),
            ] else if (_authMode == _AuthMode.signup) ...[
              _SignupForm(
                formKey: _signupFormKey,
                firstNameController: _signupFirstNameController,
                lastNameController: _signupLastNameController,
                phoneController: _signupPhoneController,
                emailController: _signupEmailController,
                passwordController: _signupPasswordController,
                consent: _signupConsent,
                loading: authBusy,
                onConsentChanged: (value) {
                  setState(() {
                    _signupConsent = value;
                  });
                },
                onSubmit: _handleSignupSubmit,
                onBack: _resetToAuthChoice,
              ),
            ] else if (_authMode == _AuthMode.forgot) ...[
              _ForgotPasswordForm(
                formKey: _forgotFormKey,
                emailController: _forgotEmailController,
                loading: authBusy,
                onSubmit: _handleForgotSubmit,
                onBack: () => _chooseAuthMode(_AuthMode.login),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessStep(BuildContext context) {
    final selectedService = _selectedService;
    final selectedDate = _selectedDate;
    final durationMinutes = _selectedServiceDurationMinutes(selectedDate);
    final price = _formatPrice(
      _booking?.priceCents ?? selectedService?.priceCents ?? 2000,
    );

    return _buildPanelShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader('Confirmé', 'Votre rendez-vous est confirmé'),
            const SizedBox(height: 18),
            _SuccessBadge(),
            const SizedBox(height: 14),
            Text(
              'Votre rendez-vous est confirmé.\nVérifiez vos emails pour la confirmation et le récapitulatif. Vous recevrez un SMS de rappel la veille.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            _SummaryCard(
              barber: _summaryBarberName,
              service: _summaryServiceName,
              date: _summaryDateLabel,
              time: _summaryTimeLabel,
              duration: durationMinutes,
              price: price,
            ),
            const SizedBox(height: 18),
            _SuccessActionButton(
              icon: Icons.home_outlined,
              label: 'Retour à l’accueil',
              primary: false,
              onTap: () => context.go('/home'),
            ),
            const SizedBox(height: 18),
            _PracticalInfoSection(
              onMapTap: () =>
                  _showMessage('Démo uniquement : Google Maps non activé.'),
            ),
            const SizedBox(height: 14),
            Text(
              'Vous pouvez annuler ou modifier votre RDV depuis votre espace Mon Compte, ou via le lien dans votre email de confirmation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            _SuccessActionButton(
              icon: Icons.person_outline_rounded,
              label: 'Accéder à Mon Compte',
              primary: false,
              onTap: _openAccount,
            ),
          ],
        ),
      ),
    );
  }

  List<_BarberOption> _buildBarbers() {
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    return <_BarberOption>[
      const _BarberOption(
        id: 'any',
        name: 'PEU IMPORTE',
        subtitle: 'Premier barber disponible',
        isAny: true,
      ),
      _BarberOption(
        id: 'louay',
        name: 'LOUAY',
        subtitle: 'Barbier',
        photoUrl:
            'https://barberclub-grenoble.fr/assets/images/barbers/louay.jpg',
      ),
      _BarberOption(
        id: 'nathan',
        name: 'NATHAN',
        subtitle: 'Barbier',
        photoUrl: '$base/images/barbers/nathan.png',
      ),
      _BarberOption(
        id: 'alan',
        name: 'ALAN',
        subtitle: 'Barbier',
        photoUrl: '$base/images/barbers/alan.png',
      ),
      _BarberOption(
        id: 'tom',
        name: 'TOM',
        subtitle: 'Barbier',
        photoUrl: '$base/images/barbers/tom.png',
      ),
      _BarberOption(
        id: 'clement',
        name: 'CLÉMENT',
        subtitle: 'Barbier',
        photoUrl: '$base/images/barbers/clement.png',
      ),
    ];
  }

  List<_ServiceOption> _legacyServices() => const <_ServiceOption>[
    _ServiceOption(
      id: 'cut_homme_sans_barbe',
      name: 'Coupe Homme sans barbe',
      description: 'Shampooing, coupe, coiffage',
      priceCents: 2000,
      durationMinutes: 30,
      category: _ServiceCategory.cuts,
    ),
    _ServiceOption(
      id: 'cut_homme',
      name: 'Coupe Homme',
      description: 'Shampooing, coupe, coiffage',
      priceCents: 2000,
      durationMinutes: 30,
      category: _ServiceCategory.cuts,
    ),
    _ServiceOption(
      id: 'cut_contours_barbe',
      name: 'Coupe + Contours Barbe',
      description:
          'Coupe cheveux, shampooing, coiffage + traçage et soin barbe',
      priceCents: 2500,
      durationMinutes: 40,
      category: _ServiceCategory.cuts,
    ),
    _ServiceOption(
      id: 'cut_barbe',
      name: 'Coupe + Barbe',
      description:
          'Coupe cheveux, shampooing, coiffage + traçage et taille soin barbe',
      priceCents: 3000,
      durationMinutes: 45,
      category: _ServiceCategory.cuts,
    ),
    _ServiceOption(
      id: 'barbe_uniquement',
      name: 'Barbe uniquement',
      description: 'Barbe : traçage, taillage et huile nourrissante',
      priceCents: 1500,
      durationMinutes: 25,
      category: _ServiceCategory.beard,
    ),
    _ServiceOption(
      id: 'cut_enfant',
      name: 'Coupe Enfant (-12 ans)',
      description: 'Coupes cheveux, shampooing, coiffage',
      priceCents: 1500,
      durationMinutes: 25,
      category: _ServiceCategory.reduced,
    ),
  ];

  static const List<_ServiceCategory> _serviceCategories = <_ServiceCategory>[
    _ServiceCategory.cuts,
    _ServiceCategory.beard,
    _ServiceCategory.reduced,
  ];

  String _categoryTitle(_ServiceCategory category) {
    switch (category) {
      case _ServiceCategory.cuts:
        return 'COUPES';
      case _ServiceCategory.beard:
        return 'BARBE & SOINS';
      case _ServiceCategory.reduced:
        return 'TARIFS RÉDUITS';
    }
  }

  IconData _categoryIcon(_ServiceCategory category) {
    switch (category) {
      case _ServiceCategory.cuts:
        return Icons.content_cut_rounded;
      case _ServiceCategory.beard:
        return Icons.water_drop_outlined;
      case _ServiceCategory.reduced:
        return Icons.percent_rounded;
    }
  }
}

enum _ReservationStep { barber, service, date, booking, success }

enum _AuthMode { choice, guest, login, signup, forgot }

enum _ServiceCategory { cuts, beard, reduced }

class _BarberOption {
  const _BarberOption({
    required this.id,
    required this.name,
    required this.subtitle,
    this.photoUrl,
    this.role = '',
    this.isAny = false,
    this.isGuest = false,
    this.offDays = const [],
    this.workDates = const [],
    this.offDates = const [],
    this.guestDates = const [],
    this.contractStart,
    this.contractEnd,
  });

  final String id;
  final String name;
  final String subtitle;
  final String? photoUrl;
  final String role;
  final bool isAny;
  final bool isGuest;
  final List<int> offDays;
  final List<String> workDates;
  final List<String> offDates;
  final List<String> guestDates;
  final String? contractStart;
  final String? contractEnd;
}

class _ServiceOption {
  const _ServiceOption({
    required this.id,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.durationMinutes,
    required this.category,
    this.durationSaturdayMinutes,
    this.customDurationMinutes,
    this.color,
  });

  final String id;
  final String name;
  final String description;
  final int priceCents;
  final int durationMinutes;
  final _ServiceCategory category;
  final int? durationSaturdayMinutes;
  final int? customDurationMinutes;
  final String? color;

  int get effectiveDurationMinutes => customDurationMinutes ?? durationMinutes;

  int durationForDate(DateTime date) {
    if (customDurationMinutes != null) {
      return customDurationMinutes!;
    }
    if (date.weekday == DateTime.saturday && durationSaturdayMinutes != null) {
      return durationSaturdayMinutes!;
    }
    return durationMinutes;
  }
}

class _SlotOption {
  const _SlotOption({
    required this.time,
    this.barberId = '',
    required this.barberName,
  });

  final String time;
  final String barberId;
  final String barberName;
}

class _QuickSuggestion {
  const _QuickSuggestion({
    required this.date,
    required this.dayLabel,
    required this.label,
    this.slotCount,
    this.status,
    this.alternativeCount = 0,
  });

  final DateTime date;
  final String dayLabel;
  final String label;
  final int? slotCount;
  final String? status;
  final int alternativeCount;
}

class _CalendarDay {
  const _CalendarDay({
    required this.date,
    required this.isPast,
    required this.isAvailable,
    required this.isSelected,
    this.status,
    this.slotCount,
    this.alternativeCount = 0,
  });

  const _CalendarDay.empty()
    : date = null,
      isPast = false,
      isAvailable = false,
      isSelected = false,
      status = null,
      slotCount = null,
      alternativeCount = 0;

  final DateTime? date;
  final bool isPast;
  final bool isAvailable;
  final bool isSelected;
  final String? status;
  final int? slotCount;
  final int alternativeCount;

  bool get isSelectable => date != null && !isPast && isAvailable;

  bool get hasAlternatives => alternativeCount > 0;
}

class _PolicyRuleCard extends StatelessWidget {
  const _PolicyRuleCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF202020),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: _RdvScreenState._titleFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF191919),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.88),
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _ReservationTopHeader extends StatelessWidget {
  const _ReservationTopHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onProfile,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          _HeaderIconButton(icon: Icons.arrow_back, onTap: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: _RdvScreenState._titleFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.0,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.6,
                    color: Color(0xFF8F8F8F),
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _HeaderIconButton(
            icon: Icons.person_outline_rounded,
            onTap: onProfile,
          ),
        ],
      ),
    );
  }
}

class _SalonChoiceSplit extends StatelessWidget {
  const _SalonChoiceSplit({required this.salons, required this.onTapSalon});

  final List<Salon> salons;
  final ValueChanged<Salon> onTapSalon;

  @override
  Widget build(BuildContext context) {
    if (salons.isEmpty) {
      return const _SalonChoiceFallbackPanel();
    }

    final topSalon = salons.first;
    final bottomSalon = salons.length > 1 ? salons[1] : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        Column(
          children: [
            Expanded(
              child: _SalonChoicePanel(
                salon: topSalon,
                onTap: () => onTapSalon(topSalon),
              ),
            ),
            const GlowingSeparator(),
            Expanded(
              child: bottomSalon != null
                  ? _SalonChoicePanel(
                      salon: bottomSalon,
                      onTap: () => onTapSalon(bottomSalon),
                      contentBottomInset: 96,
                    )
                  : const _SalonChoiceFallbackPanel(),
            ),
          ],
        ),
      ],
    );
  }
}

class _SalonChoicePanel extends StatelessWidget {
  const _SalonChoicePanel({
    required this.salon,
    required this.onTap,
    this.contentBottomInset = 26,
  });

  final Salon salon;
  final VoidCallback onTap;
  final double contentBottomInset;

  @override
  Widget build(BuildContext context) {
    final imageUrl = AppConfig.resolveImageUrl(salon.imageUrl);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _SalonChoiceImageBackground(imageUrl: imageUrl),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.84),
                    ],
                    stops: const [0.0, 0.42, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: contentBottomInset,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    salon.city.toUpperCase(),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    salon.location?.toUpperCase() ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _SalonChoiceCta(label: 'Choisir'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalonChoiceFallbackPanel extends StatelessWidget {
  const _SalonChoiceFallbackPanel();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Color(0xFF080808),
      child: Center(
        child: Opacity(
          opacity: 0.7,
          child: Icon(Icons.store, size: 72, color: Colors.white24),
        ),
      ),
    );
  }
}

class _SalonChoiceImageBackground extends StatelessWidget {
  const _SalonChoiceImageBackground({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(color: const Color(0xFF111111));
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(color: const Color(0xFF111111)),
      errorWidget: (context, url, error) =>
          Container(color: const Color(0xFF111111)),
    );
  }
}

class _SalonChoiceCta extends StatelessWidget {
  const _SalonChoiceCta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Orbitron',
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
        ],
      ),
    );
  }
}

class _ReservationStepper extends StatelessWidget {
  const _ReservationStepper({required this.step});

  final _ReservationStep step;

  @override
  Widget build(BuildContext context) {
    final index = step.index;
    final labels = <String>[
      'BARBER',
      'PRESTATION',
      'DATE',
      'INFOS',
      'CONFIRMÉ',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 5; i++) ...[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepperCircle(
                    active: i == index,
                    completed: i < index,
                    number: i + 1,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.3,
                      height: 1.0,
                      letterSpacing: 0.25,
                      fontWeight: i == index
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: i <= index
                          ? Colors.white.withValues(
                              alpha: i == index ? 0.98 : 0.72,
                            )
                          : Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                ],
              ),
            ),
            if (i < 4)
              Container(
                width: 26,
                height: 1,
                color: Colors.white.withValues(alpha: i < index ? 0.42 : 0.08),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepperCircle extends StatelessWidget {
  const _StepperCircle({
    required this.active,
    required this.completed,
    required this.number,
  });

  final bool active;
  final bool completed;
  final int number;

  @override
  Widget build(BuildContext context) {
    final borderColor = completed || active
        ? Colors.white
        : Colors.white.withValues(alpha: 0.12);
    final fillColor = completed || active ? Colors.white : Colors.transparent;
    final textColor = completed || active
        ? Colors.black
        : Colors.white.withValues(alpha: 0.8);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Center(
        child: completed
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.black)
            : Text(
                '$number',
                style: TextStyle(
                  fontFamily: _RdvScreenState._titleFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: textColor,
                ),
              ),
      ),
    );
  }
}

class _ReservationActionBar extends StatelessWidget {
  const _ReservationActionBar({
    required this.enabled,
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled && !loading ? onPressed : null,
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontFamily: _RdvScreenState._titleFont,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: Colors.black,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.84),
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontFamily: _RdvScreenState._titleFont,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BarberCard extends StatelessWidget {
  const _BarberCard({
    required this.barber,
    required this.selected,
    required this.onTap,
  });

  final _BarberOption barber;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.06);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: selected ? 1.2 : 1),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _BarberAvatar(barber: barber),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        barber.name,
                        style: const TextStyle(
                          fontFamily: _RdvScreenState._titleFont,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        barber.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.56),
                          fontSize: 12.5,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Colors.white : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: Colors.black,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarberAvatar extends StatelessWidget {
  const _BarberAvatar({required this.barber});

  final _BarberOption barber;

  @override
  Widget build(BuildContext context) {
    if (barber.isAny) {
      return Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF171717),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(
          Icons.groups_outlined,
          color: Colors.white.withValues(alpha: 0.35),
          size: 24,
        ),
      );
    }

    return ClipOval(
      child: Container(
        width: 54,
        height: 54,
        color: const Color(0xFF1A1A1A),
        child: CachedNetworkImage(
          imageUrl: barber.photoUrl ?? '',
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: const Color(0xFF1A1A1A),
            child: Icon(
              Icons.person_outline_rounded,
              color: Colors.white.withValues(alpha: 0.28),
              size: 26,
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            color: const Color(0xFF1A1A1A),
            child: Icon(
              Icons.person_outline_rounded,
              color: Colors.white.withValues(alpha: 0.28),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.selected,
    required this.onTap,
  });

  final _ServiceOption service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                      if (service.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          service.description,
                          style: TextStyle(
                            fontSize: 12.2,
                            height: 1.25,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      (service.priceCents / 100)
                              .toStringAsFixed(2)
                              .replaceAll('.', ',') +
                          ' €',
                      style: const TextStyle(
                        fontFamily: _RdvScreenState._titleFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? Colors.white : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: Colors.black,
                            )
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DisabledServiceCard extends StatelessWidget {
  const _DisabledServiceCard({
    required this.title,
    required this.description,
    required this.price,
  });

  final String title;
  final String description;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12.2,
                      height: 1.25,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              price,
              style: const TextStyle(
                fontFamily: _RdvScreenState._titleFont,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSuggestionCard extends StatelessWidget {
  const _QuickSuggestionCard({
    required this.suggestion,
    required this.selected,
    required this.onTap,
  });

  final _QuickSuggestion suggestion;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    suggestion.dayLabel.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.4,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: selected
                          ? Colors.black.withValues(alpha: 0.72)
                          : Colors.white.withValues(alpha: 0.46),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _RdvScreenState._titleFont,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: selected ? Colors.black : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.8,
              color: Colors.white.withValues(alpha: 0.40),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.10),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.monthLabel,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final String monthLabel;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _NavArrowButton(
          icon: Icons.chevron_left_rounded,
          enabled: canGoPrevious,
          onTap: onPrevious,
        ),
        Text(
          monthLabel,
          style: const TextStyle(
            fontFamily: _RdvScreenState._titleFont,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.4,
          ),
        ),
        _NavArrowButton(
          icon: Icons.chevron_right_rounded,
          enabled: canGoNext,
          onTap: onNext,
        ),
      ],
    );
  }
}

class _NavArrowButton extends StatelessWidget {
  const _NavArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Icon(
            icon,
            size: 22,
            color: enabled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.18),
          ),
        ),
      ),
    );
  }
}

class _WeekdaysRow extends StatelessWidget {
  const _WeekdaysRow();

  @override
  Widget build(BuildContext context) {
    const labels = ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM'];
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.45,
                color: Colors.white.withValues(alpha: 0.34),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({required this.day, required this.onTap});

  final _CalendarDay day;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (day.date == null) {
      return const SizedBox.shrink();
    }

    final selected = day.isSelected;
    final available = day.isAvailable && !day.isPast;
    final dayTextColor = selected
        ? Colors.black
        : day.isPast
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.82);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${day.date!.day}',
                  style: TextStyle(
                    fontFamily: _RdvScreenState._titleFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: dayTextColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 1),
            if (available && !selected)
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF25C06D),
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 3),
          ],
        ),
      ),
    );
  }
}

class _SlotsGrid extends StatelessWidget {
  const _SlotsGrid({
    required this.slots,
    required this.selectedTime,
    required this.onTap,
  });

  final List<_SlotOption> slots;
  final String? selectedTime;
  final ValueChanged<_SlotOption> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: slots.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 42,
      ),
      itemBuilder: (context, index) {
        final slot = slots[index];
        return _SlotChip(
          slot: slot,
          selected: slot.time == selectedTime,
          onTap: () => onTap(slot),
        );
      },
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final _SlotOption slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          decoration: BoxDecoration(
            color: selected ? Colors.white : const Color(0xFF111111),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Center(
            child: Text(
              slot.time,
              style: TextStyle(
                fontFamily: _RdvScreenState._titleFont,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.barber,
    required this.service,
    required this.date,
    required this.time,
    required this.duration,
    required this.price,
  });

  final String barber;
  final String service;
  final String date;
  final String time;
  final int duration;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          _SummaryRow(label: 'BARBER', value: barber),
          _SummaryRow(label: 'PRESTATION', value: service, maxValueLines: 2),
          _SummaryRow(label: 'DATE', value: date),
          _SummaryRow(label: 'HEURE', value: time),
          _SummaryRow(label: 'DURÉE', value: '$duration min'),
          const SizedBox(height: 2),
          _SummaryRow(
            label: 'PRIX',
            value: price,
            largeValue: true,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.largeValue = false,
    this.isLast = false,
    this.maxValueLines = 1,
    this.labelWidth = 92,
  });

  final String label;
  final String value;
  final bool largeValue;
  final bool isLast;
  final int maxValueLines;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 11, bottom: isLast ? 0 : 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: Colors.white.withValues(alpha: 0.04)),
        ),
      ),
      child: Row(
        crossAxisAlignment: maxValueLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Colors.white.withValues(alpha: 0.28),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: maxValueLines,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: TextStyle(
                fontFamily: _RdvScreenState._titleFont,
                fontSize: largeValue ? 18 : 13,
                fontWeight: FontWeight.w700,
                letterSpacing: largeValue ? 0.5 : 0.2,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthOptionCard extends StatelessWidget {
  const _AuthOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: _RdvScreenState._titleFont,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.42),
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.22),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberDivider extends StatelessWidget {
  const _MemberDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: _RdvScreenState._titleFont,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}

class _SignupPromoCard extends StatelessWidget {
  const _SignupPromoCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/barber_club_full_logo.png',
                  width: 130,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                _PerkLine(text: 'Gérez vos RDV en ligne'),
                const SizedBox(height: 6),
                _PerkLine(text: 'Annulez ou décalez facilement'),
                const SizedBox(height: 6),
                _PerkLine(text: 'Historique de vos visites'),
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'CRÉER MON COMPTE',
                        style: TextStyle(
                          fontFamily: _RdvScreenState._titleFont,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PerkLine extends StatelessWidget {
  const _PerkLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.check_rounded,
          size: 14,
          color: Colors.white.withValues(alpha: 0.55),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 12.5,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _GuestReservationForm extends StatelessWidget {
  const _GuestReservationForm({
    required this.formKey,
    required this.firstNameController,
    required this.lastNameController,
    required this.phoneController,
    required this.emailController,
    required this.consent,
    required this.loading,
    required this.onConsentChanged,
    required this.onSubmit,
    required this.onBack,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final bool consent;
  final bool loading;
  final ValueChanged<bool> onConsentChanged;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AuthBackButton(onBack: onBack),
        const SizedBox(height: 10),
        const _FormHeader(
          icon: Icons.person_add_alt_1_rounded,
          title: 'REJOINDRE LE CLUB',
          subtitle: 'Créez votre compte en quelques secondes',
        ),
        const SizedBox(height: 12),
        _FormPanel(
          child: Form(
            key: formKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _FormTextField(
                        label: 'Prénom',
                        hint: 'Jean',
                        controller: firstNameController,
                        light: true,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Prénom requis';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FormTextField(
                        label: 'Nom',
                        hint: 'Dupont',
                        controller: lastNameController,
                        light: true,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Nom requis';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _PhoneField(
                  label: 'Téléphone',
                  phoneController: phoneController,
                  light: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Numéro requis';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _FormTextField(
                  label: 'Email',
                  hint: 'jean@exemple.fr',
                  controller: emailController,
                  light: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Email requis';
                    if (!value.contains('@')) return 'Email invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _ConsentRow(
                  value: consent,
                  onChanged: onConsentChanged,
                  text:
                      'J’accepte que mes données personnelles soient utilisées pour la gestion de mon rendez-vous.',
                ),
                const SizedBox(height: 14),
                _FormActionButton(
                  label: 'CRÉER MON COMPTE',
                  loading: loading,
                  onTap: onSubmit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.identifierController,
    required this.passwordController,
    required this.loading,
    required this.onSubmit,
    required this.onForgot,
    required this.onBack,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController identifierController;
  final TextEditingController passwordController;
  final bool loading;
  final VoidCallback onSubmit;
  final VoidCallback onForgot;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AuthBackButton(onBack: onBack),
        const SizedBox(height: 10),
        const _FormHeader(
          icon: Icons.lock_outline_rounded,
          title: 'CONNEXION',
          subtitle: 'Accédez à votre espace BarberClub',
        ),
        const SizedBox(height: 12),
        _FormPanel(
          child: Form(
            key: formKey,
            child: Column(
              children: [
                _FormTextField(
                  label: 'Email ou téléphone',
                  hint: 'jean@exemple.fr',
                  controller: identifierController,
                  light: false,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Champ requis';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _FormTextField(
                  label: 'Mot de passe',
                  hint: '••••••••',
                  controller: passwordController,
                  light: false,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  suffix: TextButton(
                    onPressed: onForgot,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.5),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Oublié ?',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Mot de passe requis';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _FormActionButton(
                  label: 'SE CONNECTER',
                  loading: loading,
                  onTap: onSubmit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SignupForm extends StatelessWidget {
  const _SignupForm({
    required this.formKey,
    required this.firstNameController,
    required this.lastNameController,
    required this.phoneController,
    required this.emailController,
    required this.passwordController,
    required this.consent,
    required this.loading,
    required this.onConsentChanged,
    required this.onSubmit,
    required this.onBack,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool consent;
  final bool loading;
  final ValueChanged<bool> onConsentChanged;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AuthBackButton(onBack: onBack),
        const SizedBox(height: 10),
        const _FormHeader(
          icon: Icons.person_add_rounded,
          title: 'REJOINDRE LE CLUB',
          subtitle: 'Créez votre compte en quelques secondes',
        ),
        const SizedBox(height: 12),
        _FormPanel(
          child: Form(
            key: formKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _FormTextField(
                        label: 'Prénom',
                        hint: 'Jean',
                        controller: firstNameController,
                        light: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Prénom requis';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FormTextField(
                        label: 'Nom',
                        hint: 'Dupont',
                        controller: lastNameController,
                        light: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Nom requis';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _PhoneField(
                  label: 'Téléphone',
                  phoneController: phoneController,
                  light: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Numéro requis';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _FormTextField(
                  label: 'Email',
                  hint: 'jean@exemple.fr',
                  controller: emailController,
                  light: true,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Email requis';
                    if (!value.contains('@')) return 'Email invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _FormTextField(
                  label: 'Mot de passe',
                  hint: '8 caractères minimum',
                  controller: passwordController,
                  light: true,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Mot de passe requis';
                    if (value.trim().length < 8) return '8 caractères minimum';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _ConsentRow(
                  value: consent,
                  onChanged: onConsentChanged,
                  text:
                      'J’accepte que mes données personnelles soient utilisées pour la gestion de mon rendez-vous.',
                ),
                const SizedBox(height: 14),
                _FormActionButton(
                  label: 'CRÉER MON COMPTE',
                  loading: loading,
                  onTap: onSubmit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ForgotPasswordForm extends StatelessWidget {
  const _ForgotPasswordForm({
    required this.formKey,
    required this.emailController,
    required this.loading,
    required this.onSubmit,
    required this.onBack,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final bool loading;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AuthBackButton(onBack: onBack),
        const SizedBox(height: 10),
        const _FormHeader(
          icon: Icons.lock_reset_rounded,
          title: 'MOT DE PASSE OUBLIÉ',
          subtitle:
              'Entrez votre email pour recevoir un lien de réinitialisation',
        ),
        const SizedBox(height: 12),
        _FormPanel(
          child: Form(
            key: formKey,
            child: Column(
              children: [
                _FormTextField(
                  label: 'Email',
                  hint: 'jean@exemple.fr',
                  controller: emailController,
                  light: false,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Email requis';
                    if (!value.contains('@')) return 'Email invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _FormActionButton(
                  label: 'ENVOYER LE LIEN',
                  loading: loading,
                  onTap: onSubmit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectedPanel extends StatelessWidget {
  const _ConnectedPanel({
    required this.name,
    required this.loading,
    required this.onLogout,
    required this.onConfirm,
  });

  final String name;
  final bool loading;
  final VoidCallback onLogout;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 6),
        const _FormHeader(
          icon: Icons.check_circle_outline_rounded,
          title: 'PRÊT À RÉSERVER',
          subtitle: 'Connecté en tant que client BarberClub',
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Image.asset(
                'assets/images/barber_club_full_logo.png',
                width: 140,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: _RdvScreenState._titleFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Votre compte est prêt. Vous pouvez confirmer votre rendez-vous maintenant.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              _FormActionButton(
                label: 'RÉSERVER MON CRÉNEAU',
                loading: loading,
                onTap: onConfirm,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onLogout,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.38),
                ),
                child: const Text('Se déconnecter'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthBackButton extends StatelessWidget {
  const _AuthBackButton({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onBack,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.46),
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: const Text('Retour'),
      ),
    );
  }
}

class _FormHeader extends StatelessWidget {
  const _FormHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.75),
            size: 24,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: _RdvScreenState._titleFont,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.8,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.48),
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: child,
    );
  }
}

class _FormActionButton extends StatelessWidget {
  const _FormActionButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: loading ? null : onTap,
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: loading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.black,
                          ),
                        ),
                      )
                    : Text(
                        label,
                        key: const ValueKey('label'),
                        style: const TextStyle(
                          fontFamily: _RdvScreenState._titleFont,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: Colors.black,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.value,
    required this.onChanged,
    required this.text,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: value ? Colors.white : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: value
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 12,
                color: value ? Colors.black : Colors.transparent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.56),
                fontSize: 12.3,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.label,
    required this.phoneController,
    required this.light,
    required this.validator,
  });

  final String label;
  final TextEditingController phoneController;
  final bool light;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    final field = Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: light ? const Color(0xFFEAEFF7) : const Color(0xFF161616),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
        ),
      ),
      child: TextFormField(
        controller: phoneController,
        keyboardType: TextInputType.phone,
        style: TextStyle(
          color: light ? Colors.black : Colors.white,
          fontSize: 14.5,
        ),
        validator: validator,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 78,
              height: 34,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: const Center(
                child: Text(
                  'FR +33',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(child: field),
          ],
        ),
      ],
    );
  }
}

class _FormTextField extends StatelessWidget {
  const _FormTextField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.light,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.suffix,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool light;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final fillColor = light ? const Color(0xFFEAEFF7) : const Color(0xFF161616);
    final textColor = light ? Colors.black : Colors.white;
    final hintColor = light
        ? Colors.black54
        : Colors.white.withValues(alpha: 0.28);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: fillColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
            ),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            validator: validator,
            style: TextStyle(color: textColor, fontSize: 14.5),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: hintColor, fontSize: 14.2),
              suffixIcon: suffix,
              suffixIconConstraints: const BoxConstraints(
                minHeight: 0,
                minWidth: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReservationBackdrop extends StatelessWidget {
  const _ReservationBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.0, -0.75),
          radius: 1.2,
          colors: [
            const Color(0xFF2E2B16).withValues(alpha: 0.5),
            Colors.transparent,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.01),
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black,
                  ],
                  stops: const [0, 0.48, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -80,
            child: _GlowBlob(
              size: 220,
              color: const Color(0xFF2C2A13).withValues(alpha: 0.42),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -100,
            child: _GlowBlob(
              size: 260,
              color: Colors.white.withValues(alpha: 0.045),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.01)],
        ),
      ),
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.check_rounded, color: Colors.black, size: 34),
    );
  }
}

class _SuccessActionButton extends StatelessWidget {
  const _SuccessActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final background = primary ? Colors.white : const Color(0xFF111111);
    final foreground = primary ? Colors.black : Colors.white;

    return SizedBox(
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: primary
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: _RdvScreenState._titleFont,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PracticalInfoSection extends StatelessWidget {
  const _PracticalInfoSection({required this.onMapTap});

  final VoidCallback onMapTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PracticalInfoCard(
          icon: Icons.location_on_outlined,
          title: '5 Rue Clôt Bey, 38000 Grenoble',
          trailingLabel: 'Ouvrir dans Google Maps',
          onTap: onMapTap,
        ),
        const SizedBox(height: 10),
        const _PracticalInfoCard(
          icon: Icons.local_parking_outlined,
          title: 'Parking',
          subtitle: 'Parking payant à proximité',
        ),
        const SizedBox(height: 10),
        const _PracticalInfoCard(
          icon: Icons.info_outline_rounded,
          title: 'Bon à savoir',
          subtitle:
              'Merci d’arriver à l’heure. Au-delà de 5 min de retard, le RDV pourra être refusé.',
        ),
      ],
    );
  }
}

class _PracticalInfoCard extends StatelessWidget {
  const _PracticalInfoCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingLabel,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: _RdvScreenState._titleFont,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.44),
                            fontSize: 12.4,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailingLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 10, top: 2),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
