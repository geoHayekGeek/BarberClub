import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/reservation_repository_impl.dart';
import '../../domain/repositories/reservation_repository.dart';

final reservationRepositoryProvider = Provider<ReservationRepository>((ref) {
  return ReservationRepositoryImpl();
});
