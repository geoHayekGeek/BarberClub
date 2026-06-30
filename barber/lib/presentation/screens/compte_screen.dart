import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import '../../core/config/app_config.dart';
import '../../core/ui/app_snackbar.dart';
import '../../domain/models/api_error.dart';
import '../../domain/models/reservation_models.dart';
import '../../domain/models/reservation_session.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/reservation_repository.dart';
import '../providers/auth_providers.dart';
import '../providers/reservation_auth_providers.dart';
import '../providers/reservation_providers.dart';
import '../providers/salon_providers.dart';
import '../widgets/bottom_nav_bar.dart';

class CompteScreen extends ConsumerStatefulWidget {
  const CompteScreen({super.key});

  @override
  ConsumerState<CompteScreen> createState() => _CompteScreenState();
}

class _CompteScreenState extends ConsumerState<CompteScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingAvatar = false;
  static const int _maxAvatarBytes = 3 * 1024 * 1024;

  Future<ImageSource?> _showAvatarSourceSheet(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: Colors.white,
              ),
              title: const Text(
                'Choisir depuis la galerie',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: Colors.white,
              ),
              title: const Text(
                'Prendre une photo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _compressAvatar(String path) async {
    int quality = 85;
    Uint8List? compressed;

    while (quality >= 55) {
      compressed = await FlutterImageCompress.compressWithFile(
        path,
        format: CompressFormat.jpeg,
        quality: quality,
        minWidth: 1080,
        minHeight: 1080,
        keepExif: false,
      );

      if (compressed != null &&
          compressed.isNotEmpty &&
          compressed.lengthInBytes <= _maxAvatarBytes) {
        return compressed;
      }

      quality -= 10;
    }

    return compressed;
  }

  String _avatarUploadErrorMessage(Object error) {
    if (error is ApiError) {
      return error.getFriendlyMessage();
    }

    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      if (code.contains('permission') ||
          code.contains('denied') ||
          code.contains('restricted')) {
        return 'Permission refusee. Autorisez la camera et la galerie dans les reglages.';
      }
    }

    return 'Impossible de mettre a jour la photo de profil. Veuillez reessayer.';
  }

  Future<void> _changeAvatar() async {
    if (_isUploadingAvatar) return;

    final source = await _showAvatarSourceSheet(context);
    if (source == null) return;

    try {
      final pickedImage = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 95,
      );
      if (pickedImage == null) return;

      final croppedImage = await ImageCropper().cropImage(
        sourcePath: pickedImage.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 95,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recadrer',
            toolbarColor: const Color(0xFF121212),
            toolbarWidgetColor: Colors.white,
            backgroundColor: const Color(0xFF121212),
            lockAspectRatio: true,
            hideBottomControls: true,
            initAspectRatio: CropAspectRatioPreset.square,
          ),
          IOSUiSettings(
            title: 'Recadrer',
            aspectRatioLockEnabled: true,
            aspectRatioPickerButtonHidden: true,
            resetAspectRatioEnabled: false,
            rotateButtonsHidden: true,
          ),
        ],
      );

      if (croppedImage == null) return;

      final compressedBytes = await _compressAvatar(croppedImage.path);
      if (compressedBytes == null || compressedBytes.isEmpty) {
        throw const FormatException('Empty image');
      }
      if (compressedBytes.lengthInBytes > _maxAvatarBytes) {
        throw const FormatException('Image too large');
      }

      setState(() => _isUploadingAvatar = true);

      await ref
          .read(authStateProvider.notifier)
          .updateAvatar(imageBytes: compressedBytes, mimeType: 'image/jpeg');

      if (!mounted) return;
      AppSnackBar.show(
        context,
        'Photo de profil mise a jour.',
        backgroundColor: Colors.green,
        icon: Icons.check_circle_outline_rounded,
      );
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        _avatarUploadErrorMessage(error),
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Colors.white,
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Widget _buildAvatarWidget({
    required String initials,
    required String? avatarUrl,
  }) {
    final resolvedAvatarUrl = AppConfig.resolveImageUrl(avatarUrl);

    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A1A1A),
              border: Border.all(color: Colors.white24, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: resolvedAvatarUrl == null
                  ? _buildAvatarFallback(initials)
                  : CachedNetworkImage(
                      imageUrl: resolvedAvatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _buildAvatarFallback(initials),
                      errorWidget: (_, __, ___) =>
                          _buildAvatarFallback(initials),
                    ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isUploadingAvatar ? null : _changeAvatar,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: _isUploadingAvatar
                      ? const Padding(
                          padding: EdgeInsets.all(7),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(String initials) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  static const List<String> _monthNames = <String>[
    'Janvier',
    'Fevrier',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Aout',
    'Septembre',
    'Octobre',
    'Novembre',
    'Decembre',
  ];

  static const List<String> _shortMonthNames = <String>[
    'Jan',
    'Fev',
    'Mars',
    'Avr',
    'Mai',
    'Juin',
    'Juil',
    'Aout',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _shortWeekdays = <String>[
    'Dim.',
    'Lun.',
    'Mar.',
    'Mer.',
    'Jeu.',
    'Ven.',
    'Sam.',
  ];

  static const Map<String, String> _bookingStatusLabels = <String, String>{
    'confirmed': 'Confirme',
    'completed': 'Termine',
    'cancelled': 'Annule',
    'no_show': 'Absent',
  };

  String _getInitials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.trim().substring(0, 1).toUpperCase();
    }
    return '${parts.first.trim().substring(0, 1)}${parts[1].trim().substring(0, 1)}'
        .toUpperCase();
  }

  String _formatPrice(int cents) {
    if (cents <= 0) return '—';
    final euros = cents / 100.0;
    return '${euros.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  String _formatDateFr(String dateStr) {
    final date = DateTime.tryParse('${dateStr}T00:00:00');
    if (date == null) return dateStr;
    return '${_shortWeekdays[date.weekday % 7]} ${date.day} ${_monthNames[date.month - 1]} ${date.year}';
  }

  String _formatDateShort(String dateStr) {
    final date = DateTime.tryParse('${dateStr}T00:00:00');
    if (date == null) return dateStr;
    return '${_shortWeekdays[date.weekday % 7]} ${date.day} ${_shortMonthNames[date.month - 1]}';
  }

  String _formatMemberDuration(DateTime? createdAt) {
    if (createdAt == null) return '—';
    final now = DateTime.now();
    final diffDays = now.difference(createdAt).inDays;
    if (diffDays < 30) return '${diffDays.clamp(0, 999)}j';
    if (diffDays < 365) return '${(diffDays / 30).floor()} mois';
    final years = (diffDays / 365).floor();
    return '$years an${years > 1 ? 's' : ''}';
  }

  String _formatMemberSince(DateTime? createdAt) {
    if (createdAt == null) return '—';
    return '${_monthNames[createdAt.month - 1]} ${createdAt.year}';
  }

  bool _canModifyBooking(ReservationBooking booking) {
    final bookingDate = DateTime.tryParse(
      '${booking.date}T${booking.startTime}',
    );
    if (bookingDate == null) return false;
    return bookingDate.difference(DateTime.now()) >= const Duration(hours: 12);
  }

  Uri _buildManageBookingUri(ReservationBooking booking) {
    final salonId = booking.salonId.trim().isNotEmpty
        ? booking.salonId.trim()
        : 'meylan';
    return Uri.parse(
      '${AppConfig.publicSiteBaseUrl}/pages/$salonId/mon-rdv.html?id=${Uri.encodeComponent(booking.id)}&token=${Uri.encodeComponent(booking.cancelToken)}',
    );
  }

  Uri _buildBookingIcsUri(ReservationBooking booking) {
    return Uri.parse(
      '${AppConfig.reservationApiBaseUrl}/bookings/${Uri.encodeComponent(booking.id)}/ics?token=${Uri.encodeComponent(booking.cancelToken)}',
    );
  }

  Widget _buildStatusBadge(String status) {
    final normalized = status.trim().toLowerCase();
    final label = _bookingStatusLabels[normalized] ?? status;
    final isCancelled = normalized == 'cancelled';
    final isCompleted = normalized == 'completed';
    final isConfirmed = normalized == 'confirmed';
    final background = isCancelled
        ? const Color(0x1AEF4444)
        : isCompleted
        ? const Color(0x1A22C55E)
        : isConfirmed
        ? const Color(0x1AF5A524)
        : Colors.white10;
    final foreground = isCancelled
        ? const Color(0xFFF87171)
        : isCompleted
        ? const Color(0xFF4ADE80)
        : isConfirmed
        ? const Color(0xFFF5A524)
        : Colors.white70;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFromUrl({
    required String initials,
    required String? avatarUrl,
    double size = 110,
  }) {
    final resolvedAvatarUrl = avatarUrl?.trim();
    Widget child = _buildAvatarFallback(initials);

    if (resolvedAvatarUrl != null && resolvedAvatarUrl.isNotEmpty) {
      if (resolvedAvatarUrl.startsWith('data:image/')) {
        final commaIndex = resolvedAvatarUrl.indexOf(',');
        if (commaIndex > 0) {
          try {
            final base64Part = resolvedAvatarUrl.substring(commaIndex + 1);
            final bytes = base64Decode(base64Part);
            child = Image.memory(bytes, fit: BoxFit.cover);
          } catch (_) {
            child = _buildAvatarFallback(initials);
          }
        }
      } else {
        final resolved =
            AppConfig.resolveImageUrl(resolvedAvatarUrl) ??
            AppConfig.resolvePublicAssetUrl(resolvedAvatarUrl) ??
            resolvedAvatarUrl;
        child = CachedNetworkImage(
          imageUrl: resolved,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildAvatarFallback(initials),
          errorWidget: (_, __, ___) => _buildAvatarFallback(initials),
        );
      }
    }

    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: Colors.white24, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(child: child),
      ),
    );
  }

  Widget _buildBookingAvatar(ReservationBooking booking, String initials) {
    final photoUrl = booking.barberPhotoUrl?.trim();
    if (photoUrl == null || photoUrl.isEmpty) {
      return _buildBookingAvatarFallback(initials);
    }

    if (photoUrl.startsWith('data:image/')) {
      final commaIndex = photoUrl.indexOf(',');
      if (commaIndex > 0) {
        try {
          final bytes = base64Decode(photoUrl.substring(commaIndex + 1));
          return Image.memory(bytes, fit: BoxFit.cover);
        } catch (_) {
          return _buildBookingAvatarFallback(initials);
        }
      }
    }

    final resolved =
        AppConfig.resolveImageUrl(photoUrl) ??
        AppConfig.resolvePublicAssetUrl(photoUrl) ??
        photoUrl;

    return CachedNetworkImage(
      imageUrl: resolved,
      fit: BoxFit.cover,
      placeholder: (_, __) => _buildBookingAvatarFallback(initials),
      errorWidget: (_, __, ___) => _buildBookingAvatarFallback(initials),
    );
  }

  Widget _buildBookingAvatarFallback(String initials) {
    return Container(
      color: const Color(0xFF1A1A1A),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CompteScreenShell(
      onChangeAvatar: _changeAvatar,
      onEditProfile: () =>
          _showEditProfileSheet(context, ref, ref.read(authStateProvider).user),
      onChangePassword: () => _showChangePasswordSheet(context, ref),
      onDeleteAccount: () => _showDeleteAccountDialog(context, ref),
      onLogout: () async {
        await ref.read(authStateProvider.notifier).logout();
        if (!context.mounted) return;
        context.go('/home');
      },
    );

    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final theme = Theme.of(context);

    // Initial logic for avatar
    final initials = user?.fullName?.isNotEmpty == true
        ? user!.fullName![0].toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Explicit dark background
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          'MON PROFIL',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: user == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Vous êtes en mode invité.\nConnectez-vous pour accéder aux fonctionnalités premium et à votre compte.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () =>
                            context.go('/login?redirect=%2Fcompte'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white12,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Se connecter'),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // 1. Avatar Section
                    _buildAvatarWidget(
                      initials: initials,
                      avatarUrl: user.avatarUrl,
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _isUploadingAvatar ? null : _changeAvatar,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(
                        _isUploadingAvatar
                            ? 'Envoi en cours...'
                            : 'Changer la photo',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      user.fullName ?? 'Utilisateur',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Membre Barber Club',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // 2. Info Card
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Mes Informations',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () =>
                                      _showEditProfileSheet(context, ref, user),
                                ),
                              ],
                            ),
                          ),
                          const Divider(color: Colors.white10),
                          _buildInfoTile(
                            context,
                            icon: Icons.person_outline,
                            title: 'Nom complet',
                            value: user.fullName ?? '-',
                          ),
                          _buildInfoTile(
                            context,
                            icon: Icons.email_outlined,
                            title: 'Email',
                            value: user.email,
                          ),
                          _buildInfoTile(
                            context,
                            icon: Icons.phone_outlined,
                            title: 'Téléphone',
                            value: user.phoneNumber,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 3. Security Card
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            color: Colors.white70,
                          ),
                        ),
                        title: const Text(
                          'Mot de passe',
                          style: TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.white54,
                        ),
                        onTap: () => _showChangePasswordSheet(context, ref),
                      ),
                    ),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () => _showDeleteAccountDialog(context, ref),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A1010),
                          foregroundColor: Colors.redAccent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0x66FF5252)),
                          ),
                        ),
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: const Text(
                          'Supprimer mon compte',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 4. Logout Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await ref.read(authStateProvider.notifier).logout();
                          if (context.mounted) context.go('/home');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.05),
                          foregroundColor: Colors.redAccent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text(
                          'Se déconnecter',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const BottomNavBar(
        key: ValueKey('account-bottom-nav'),
        activeBranchIndex: 4,
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isDeleting = false;
    bool obscurePassword = true;

    final deleted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C1C1C),
              title: const Text(
                'Supprimer mon compte',
                style: TextStyle(color: Colors.white),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cette action est définitive. Votre compte et vos données personnelles seront supprimés. '
                      'Vos données fidélité, récompenses et informations de compte ne seront plus disponibles.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe actuel',
                        labelStyle: const TextStyle(color: Colors.white54),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white54,
                          ),
                          onPressed: () {
                            setModalState(
                              () => obscurePassword = !obscurePassword,
                            );
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez saisir votre mot de passe.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModalState(() => isDeleting = true);
                          try {
                            await ref
                                .read(authStateProvider.notifier)
                                .deleteAccount(
                                  password: passwordController.text,
                                );
                            if (!dialogContext.mounted) return;
                            Navigator.of(
                              dialogContext,
                              rootNavigator: true,
                            ).pop(true);
                          } catch (e) {
                            if (!context.mounted) return;
                            setModalState(() => isDeleting = false);
                            final message = e
                                .toString()
                                .replaceAll('Exception:', '')
                                .trim();
                            AppSnackBar.show(
                              context,
                              message,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                              foregroundColor: Colors.white,
                              icon: Icons.error_outline_rounded,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A1717),
                    foregroundColor: Colors.white,
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirmer'),
                ),
              ],
            );
          },
        );
      },
    );
    passwordController.dispose();

    if (deleted == true) {
      if (!context.mounted) return;
      context.go('/home');
      AppSnackBar.show(
        context,
        'Votre compte a été supprimé avec succès.',
        backgroundColor: Colors.green,
        icon: Icons.check_circle_outline_rounded,
      );
    }
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white38),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- EDIT PROFILE SHEET ---
  void _showEditProfileSheet(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
  ) {
    final nameCtrl = TextEditingController(text: user.fullName);
    final emailCtrl = TextEditingController(text: user.email);
    final formKey = GlobalKey<FormState>();

    String completePhoneNumber = user.phoneNumber ?? '';

    // Check if the user already has a properly formatted international number
    bool hasInternationalNumber = completePhoneNumber.startsWith('+');

    InputDecoration buildInputDecoration(String labelText) {
      return InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Modifier le profil',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: buildInputDecoration('Nom complet'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailCtrl,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: buildInputDecoration('Email'),
                validator: (v) => v!.contains('@') ? null : 'Email invalide',
              ),
              const SizedBox(height: 16),

              // --- INTL PHONE FIELD ---
              IntlPhoneField(
                initialValue: hasInternationalNumber
                    ? completePhoneNumber
                    : null,
                // Only default to FR if they don't have a valid international number saved
                initialCountryCode: hasInternationalNumber ? null : 'FR',
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                dropdownTextStyle: const TextStyle(color: Colors.white),
                dropdownIcon: const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.white54,
                ),

                // Pushes the flag and country code down to align with the text
                flagsButtonPadding: const EdgeInsets.only(top: 18),

                decoration: buildInputDecoration('Téléphone'),
                onChanged: (phone) {
                  completePhoneNumber = phone.completeNumber;
                },
                pickerDialogStyle: PickerDialogStyle(
                  backgroundColor: const Color(0xFF1A1A1A),
                  countryCodeStyle: const TextStyle(color: Colors.white),
                  countryNameStyle: const TextStyle(color: Colors.white),
                  searchFieldInputDecoration: InputDecoration(
                    hintText: 'Rechercher un pays',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white10),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: Consumer(
                  builder: (context, ref, _) {
                    return ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        try {
                          if (ctx.mounted) {
                            Navigator.of(ctx, rootNavigator: true).pop();
                          }
                          await ref
                              .read(authStateProvider.notifier)
                              .updateProfile(
                                fullName: nameCtrl.text,
                                email: emailCtrl.text,
                                phoneNumber: completePhoneNumber,
                              );
                          if (context.mounted) {
                            AppSnackBar.show(
                              context,
                              'Profil mis à jour',
                              backgroundColor: Colors.green,
                              icon: Icons.check_circle_outline_rounded,
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            AppSnackBar.show(
                              context,
                              'Erreur: $e',
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                              foregroundColor: Colors.white,
                              icon: Icons.error_outline_rounded,
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Enregistrer'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- CHANGE PASSWORD SHEET ---
  void _showChangePasswordSheet(BuildContext context, WidgetRef ref) {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool isLoading = false;
    String? localError;

    InputDecoration buildInputDecoration(String labelText) {
      return InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Changer le mot de passe',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: oldPassCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: buildInputDecoration('Ancien mot de passe'),
                    validator: (v) => v!.isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: newPassCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: buildInputDecoration('Nouveau mot de passe'),
                    validator: (v) => v!.length < 8 ? 'Min 8 caractères' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: confirmPassCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: buildInputDecoration(
                      'Confirmer le mot de passe',
                    ),
                    validator: (v) => v != newPassCtrl.text
                        ? 'Les mots de passe ne correspondent pas'
                        : null,
                  ),
                  const SizedBox(height: 24),

                  if (localError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        localError!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;

                              setModalState(() {
                                isLoading = true;
                                localError = null;
                              });

                              try {
                                await ref
                                    .read(authStateProvider.notifier)
                                    .changePassword(
                                      oldPassword: oldPassCtrl.text,
                                      newPassword: newPassCtrl.text,
                                    );

                                if (ctx.mounted) {
                                  if (!context.mounted) {
                                    return;
                                  }
                                  Navigator.of(ctx, rootNavigator: true).pop();
                                  AppSnackBar.show(
                                    context,
                                    'Mot de passe modifié avec succès',
                                    backgroundColor: Colors.green,
                                    icon: Icons.check_circle_outline_rounded,
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  String cleanMessage = e
                                      .toString()
                                      .replaceAll('Exception:', '')
                                      .trim();
                                  setModalState(() {
                                    isLoading = false;
                                    localError = cleanMessage;
                                  });
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Confirmer'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RescheduleBookingSheet extends StatefulWidget {
  const _RescheduleBookingSheet({
    required this.booking,
    required this.repository,
  });

  final ReservationBooking booking;
  final ReservationRepository repository;

  @override
  State<_RescheduleBookingSheet> createState() =>
      _RescheduleBookingSheetState();
}

class _RescheduleBookingSheetState extends State<_RescheduleBookingSheet> {
  late final DateTime _firstDate;
  late final DateTime _lastDate;
  late DateTime _selectedDate;

  List<ReservationSlot> _slots = const [];
  String? _selectedTime;
  bool _loadingSlots = false;
  bool _submitting = false;
  String? _errorMessage;
  int _loadRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _firstDate = DateTime(now.year, now.month, now.day);
    _lastDate = DateTime(now.year, now.month + 6, now.day);

    final bookingDate = DateTime.tryParse('${widget.booking.date}T00:00:00');
    _selectedDate = _clampDate(bookingDate ?? _firstDate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadSlots());
    });
  }

  DateTime _clampDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    if (normalized.isBefore(_firstDate)) return _firstDate;
    if (normalized.isAfter(_lastDate)) return _lastDate;
    return normalized;
  }

  String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _shortTime(String value) {
    return value.length >= 5 ? value.substring(0, 5) : value;
  }

  String _formatDateFr(DateTime date) {
    const weekdays = <String>[
      'Dimanche',
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
    ];
    const months = <String>[
      'Janvier',
      'Fevrier',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Aout',
      'Septembre',
      'Octobre',
      'Novembre',
      'Decembre',
    ];
    return '${weekdays[date.weekday % 7]} ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateShort(DateTime date) {
    const weekdays = <String>[
      'Dim.',
      'Lun.',
      'Mar.',
      'Mer.',
      'Jeu.',
      'Ven.',
      'Sam.',
    ];
    const months = <String>[
      'Jan',
      'Fev',
      'Mars',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Aout',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[date.weekday % 7]} ${date.day} ${months[date.month - 1]}';
  }

  List<ReservationSlot> _dedupeSlots(List<ReservationSlot> slots) {
    final seenTimes = <String>{};
    final uniqueSlots = <ReservationSlot>[];
    for (final slot in slots) {
      final time = slot.time.trim();
      if (time.isEmpty || seenTimes.contains(time)) continue;
      seenTimes.add(time);
      uniqueSlots.add(slot);
    }
    return uniqueSlots;
  }

  Future<void> _loadSlots() async {
    final currentVersion = ++_loadRequestVersion;
    final salonId = widget.booking.salonId.trim().isNotEmpty
        ? widget.booking.salonId.trim()
        : 'meylan';

    setState(() {
      _loadingSlots = true;
      _errorMessage = null;
      _slots = const [];
      _selectedTime = null;
    });

    try {
      final slots = await widget.repository.getAvailability(
        salonId: salonId,
        serviceId: widget.booking.serviceId,
        date: _dateKey(_selectedDate),
        barberId: widget.booking.barberId,
      );

      if (!mounted || currentVersion != _loadRequestVersion) return;

      setState(() {
        _slots = _dedupeSlots(slots);
        _loadingSlots = false;
      });
    } catch (error) {
      if (!mounted || currentVersion != _loadRequestVersion) return;

      setState(() {
        _loadingSlots = false;
        _errorMessage = error is ApiError
            ? error.getFriendlyMessage()
            : 'Impossible de charger les créneaux.';
      });
    }
  }

  Future<void> _onDateChanged(DateTime date) async {
    final normalized = _clampDate(date);
    if (normalized == _selectedDate) {
      return;
    }

    setState(() {
      _selectedDate = normalized;
    });

    await _loadSlots();
  }

  Future<void> _confirmReschedule() async {
    if (_selectedTime == null || _loadingSlots || _submitting) return;

    final salonId = widget.booking.salonId.trim().isNotEmpty
        ? widget.booking.salonId.trim()
        : 'meylan';

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await widget.repository.rescheduleBooking(
        bookingId: widget.booking.id,
        cancelToken: widget.booking.cancelToken,
        date: _dateKey(_selectedDate),
        startTime: _selectedTime!,
        salonId: salonId,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _submitting = false;
        _errorMessage = error is ApiError
            ? error.getFriendlyMessage()
            : 'Impossible de déplacer le rendez-vous.';
      });
    }
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final bookingDate = DateTime.tryParse('${widget.booking.date}T00:00:00');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _CompteScreenShell._cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rendez-vous actuel',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.booking.serviceName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.booking.barberName,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoChip(
            icon: Icons.calendar_month_outlined,
            label: 'Date',
            value: bookingDate == null
                ? widget.booking.date
                : _formatDateFr(bookingDate),
          ),
          const SizedBox(height: 10),
          _buildInfoChip(
            icon: Icons.schedule_rounded,
            label: 'Horaire',
            value:
                '${_shortTime(widget.booking.startTime)} - ${_shortTime(widget.booking.endTime)}',
          ),
          if (widget.booking.rescheduled) ...[
            const SizedBox(height: 12),
            Text(
              'Ce rendez-vous a déjà été décalé une fois.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlotButton(ReservationSlot slot) {
    final isSelected = _selectedTime == slot.time;
    return ChoiceChip(
      label: Text(
        _shortTime(slot.time),
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: isSelected,
      onSelected: _submitting
          ? null
          : (_) {
              setState(() {
                _selectedTime = slot.time;
              });
            },
      selectedColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      side: BorderSide(
        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.08),
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActionDisabled =
        _loadingSlots || _submitting || _selectedTime == null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Material(
        color: _CompteScreenShell._pageBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 46,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Décaler le rendez-vous',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 18),
                      _buildSectionTitle('Choisir une nouvelle date'),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          color: _CompteScreenShell._cardBackground,
                          padding: const EdgeInsets.all(8),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: Theme.of(context).colorScheme
                                  .copyWith(
                                    primary: Colors.white,
                                    onPrimary: Colors.black,
                                    surface: _CompteScreenShell._cardBackground,
                                    onSurface: Colors.white,
                                  ),
                            ),
                            child: CalendarDatePicker(
                              initialDate: _selectedDate,
                              firstDate: _firstDate,
                              lastDate: _lastDate,
                              onDateChanged: _onDateChanged,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildSectionTitle('Créneaux disponibles'),
                      const SizedBox(height: 10),
                      if (_loadingSlots)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: _CompteScreenShell._cardBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        )
                      else if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _CompteScreenShell._cardBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.45,
                            ),
                          ),
                        )
                      else if (_slots.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _CompteScreenShell._cardBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            'Aucun créneau disponible pour ${_formatDateShort(_selectedDate)}. Essayez une autre date.',
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.45,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _CompteScreenShell._cardBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _slots.map(_buildSlotButton).toList(),
                          ),
                        ),
                      if (_errorMessage == null && _slots.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          _selectedTime == null
                              ? 'Choisissez un créneau pour confirmer.'
                              : 'Créneau sélectionné: ${_shortTime(_selectedTime!)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (widget.booking.rescheduled) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Un seul déplacement est autorisé par rendez-vous.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isActionDisabled
                              ? null
                              : _confirmReschedule,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white.withValues(
                              alpha: 0.16,
                            ),
                            disabledForegroundColor: Colors.white.withValues(
                              alpha: 0.35,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text(
                                  'Confirmer le nouveau créneau',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RescheduleBookingSheetV2 extends StatefulWidget {
  const _RescheduleBookingSheetV2({
    required this.booking,
    required this.repository,
  });

  final ReservationBooking booking;
  final ReservationRepository repository;

  @override
  State<_RescheduleBookingSheetV2> createState() =>
      _RescheduleBookingSheetV2State();
}

class _RescheduleBookingSheetV2State extends State<_RescheduleBookingSheetV2> {
  static const List<String> _monthNames = <String>[
    'Janvier',
    'Fevrier',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Aout',
    'Septembre',
    'Octobre',
    'Novembre',
    'Decembre',
  ];

  static const List<String> _shortWeekdays = <String>[
    'Lun.',
    'Mar.',
    'Mer.',
    'Jeu.',
    'Ven.',
    'Sam.',
    'Dim.',
  ];

  late final DateTime _today;
  late final DateTime _minMonth;
  late final DateTime _maxMonth;
  late DateTime _currentMonth;

  DateTime? _selectedDate;
  List<ReservationSlot> _slots = const [];
  Map<String, ReservationMonthAvailability> _monthAvailability = const {};
  String? _selectedTime;
  bool _loadingSlots = false;
  bool _loadingMonthAvailability = false;
  bool _submitting = false;
  String? _errorMessage;
  String? _monthErrorMessage;
  int _loadSlotsRequestVersion = 0;
  int _loadMonthRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _minMonth = DateTime(now.year, now.month);
    _maxMonth = DateTime(now.year, now.month + 6);
    _currentMonth = DateTime(now.year, now.month);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadMonthAvailability());
    });
  }

  String get _salonId => widget.booking.salonId.trim().isNotEmpty
      ? widget.booking.salonId.trim()
      : 'meylan';

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _normalizeMonth(DateTime date) => DateTime(date.year, date.month);

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  bool _isMonthBefore(DateTime a, DateTime b) {
    return a.year < b.year || (a.year == b.year && a.month < b.month);
  }

  bool _isMonthAfter(DateTime a, DateTime b) {
    return a.year > b.year || (a.year == b.year && a.month > b.month);
  }

  String _dateKey(DateTime date) {
    final normalized = _normalizeDate(date);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _shortTime(String value) {
    return value.length >= 5 ? value.substring(0, 5) : value;
  }

  String _formatDateFr(DateTime date) {
    const weekdays = <String>[
      'Dimanche',
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
    ];
    const months = <String>[
      'Janvier',
      'Fevrier',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Aout',
      'Septembre',
      'Octobre',
      'Novembre',
      'Decembre',
    ];
    return '${weekdays[date.weekday % 7]} ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatMonthLabel(DateTime month) {
    return '${_monthNames[month.month - 1]} ${month.year}';
  }

  ReservationMonthAvailability? _availabilityFor(DateTime date) {
    return _monthAvailability[_dateKey(date)];
  }

  List<ReservationSlot> _dedupeSlots(List<ReservationSlot> slots) {
    final seenTimes = <String>{};
    final uniqueSlots = <ReservationSlot>[];
    for (final slot in slots) {
      final time = slot.time.trim();
      if (time.isEmpty || seenTimes.contains(time)) continue;
      seenTimes.add(time);
      uniqueSlots.add(slot);
    }
    return uniqueSlots;
  }

  Future<void> _loadMonthAvailability() async {
    final currentVersion = ++_loadMonthRequestVersion;
    final month = _normalizeMonth(_currentMonth);

    setState(() {
      _loadingMonthAvailability = true;
      _monthErrorMessage = null;
    });

    try {
      final availability = await widget.repository.getMonthAvailability(
        salonId: _salonId,
        serviceId: widget.booking.serviceId,
        year: month.year,
        month: month.month,
        barberId: widget.booking.barberId,
        includeAlternatives: true,
      );

      if (!mounted ||
          currentVersion != _loadMonthRequestVersion ||
          !_isSameMonth(_currentMonth, month)) {
        return;
      }

      setState(() {
        _monthAvailability = availability;
        _loadingMonthAvailability = false;
      });
    } catch (error) {
      if (!mounted || currentVersion != _loadMonthRequestVersion) return;

      setState(() {
        _loadingMonthAvailability = false;
        _monthAvailability = const {};
        _monthErrorMessage = error is ApiError
            ? error.getFriendlyMessage()
            : 'Impossible de charger les disponibilites du mois.';
      });
    }
  }

  Future<void> _loadSlots() async {
    final selectedDate = _selectedDate;
    if (selectedDate == null) return;

    final currentVersion = ++_loadSlotsRequestVersion;

    setState(() {
      _loadingSlots = true;
      _errorMessage = null;
      _slots = const [];
    });

    try {
      final slots = await widget.repository.getAvailability(
        salonId: _salonId,
        serviceId: widget.booking.serviceId,
        date: _dateKey(selectedDate),
        barberId: widget.booking.barberId,
      );

      if (!mounted ||
          currentVersion != _loadSlotsRequestVersion ||
          _selectedDate == null ||
          !_isSameDate(_selectedDate!, selectedDate)) {
        return;
      }

      setState(() {
        _slots = _dedupeSlots(slots);
        _loadingSlots = false;
      });
    } catch (error) {
      if (!mounted || currentVersion != _loadSlotsRequestVersion) return;

      setState(() {
        _loadingSlots = false;
        _errorMessage = error is ApiError
            ? error.getFriendlyMessage()
            : 'Impossible de charger les creneaux.';
      });
    }
  }

  void _goToMonth(int delta) {
    final nextMonth = _normalizeMonth(
      DateTime(_currentMonth.year, _currentMonth.month + delta),
    );
    final clamped = _isMonthBefore(nextMonth, _minMonth)
        ? _minMonth
        : _isMonthAfter(nextMonth, _maxMonth)
        ? _maxMonth
        : nextMonth;

    if (_isSameMonth(clamped, _currentMonth)) {
      return;
    }

    setState(() {
      _currentMonth = clamped;
      _monthErrorMessage = null;
    });

    unawaited(_loadMonthAvailability());
  }

  void _selectDate(DateTime date) {
    final normalized = _normalizeDate(date);
    if (normalized.isBefore(_today)) {
      return;
    }

    final sameDate =
        _selectedDate != null && _isSameDate(_selectedDate!, normalized);

    setState(() {
      _selectedDate = normalized;
      _currentMonth = _normalizeMonth(normalized);
      if (!sameDate) {
        _selectedTime = null;
      }
      _errorMessage = null;
      _slots = const [];
      _loadingSlots = true;
    });

    unawaited(_loadSlots());
  }

  Future<void> _confirmReschedule() async {
    if (_selectedDate == null || _selectedTime == null || _submitting) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await widget.repository.rescheduleBooking(
        bookingId: widget.booking.id,
        cancelToken: widget.booking.cancelToken,
        date: _dateKey(_selectedDate!),
        startTime: _selectedTime!,
        salonId: _salonId,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _submitting = false;
        _errorMessage = error is ApiError
            ? error.getFriendlyMessage()
            : 'Impossible de deplacer le rendez-vous.';
      });
    }
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
      ),
    );
  }

  Widget _buildPanelCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _CompteScreenShell._cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  Widget _buildSummaryCard() {
    final bookingDate = DateTime.tryParse('${widget.booking.date}T00:00:00');
    return _buildPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rendez-vous actuel',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.booking.serviceName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.booking.barberName,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow(
            icon: Icons.calendar_month_outlined,
            label: 'Date',
            value: bookingDate == null
                ? widget.booking.date
                : _formatDateFr(bookingDate),
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Icons.schedule_rounded,
            label: 'Horaire',
            value:
                '${_shortTime(widget.booking.startTime)} - ${_shortTime(widget.booking.endTime)}',
          ),
          if (widget.booking.rescheduled) ...[
            const SizedBox(height: 12),
            Text(
              'Ce rendez-vous a deja ete decale une fois.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      children: [
        _CalendarNavButton(
          icon: Icons.chevron_left_rounded,
          onTap: _isMonthAfter(_currentMonth, _minMonth)
              ? () => _goToMonth(-1)
              : null,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                _formatMonthLabel(_currentMonth),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.06,
                ),
              ),
              if (_loadingMonthAvailability) ...[
                const SizedBox(height: 5),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ],
          ),
        ),
        _CalendarNavButton(
          icon: Icons.chevron_right_rounded,
          onTap: _isMonthBefore(_currentMonth, _maxMonth)
              ? () => _goToMonth(1)
              : null,
        ),
      ],
    );
  }

  Widget _buildWeekdaysRow() {
    return Row(
      children: List.generate(_shortWeekdays.length, (index) {
        return Expanded(
          child: Center(
            child: Text(
              _shortWeekdays[index],
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.05,
              ),
            ),
          ),
        );
      }),
    );
  }

  List<_RescheduleCalendarDay> _calendarDays() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startDow = firstDay.weekday - 1;
    final days = <_RescheduleCalendarDay>[];

    for (var i = 0; i < startDow; i++) {
      days.add(const _RescheduleCalendarDay.empty());
    }

    for (var day = 1; day <= lastDay.day; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      days.add(
        _RescheduleCalendarDay(
          date: date,
          isPast: date.isBefore(_today),
          isToday: _isSameDate(date, _today),
          isSelected:
              _selectedDate != null && _isSameDate(date, _selectedDate!),
          availability: _availabilityFor(date),
        ),
      );
    }

    return days;
  }

  Color? _dotColorForDay(_RescheduleCalendarDay day) {
    if (day.date == null || day.isPast || day.isSelected) {
      return null;
    }

    final availability = day.availability;
    if (availability == null) {
      return null;
    }

    final status = availability.status.trim().toLowerCase();
    if (availability.total > 0) {
      if (status == 'low') {
        return const Color(0xFFFB923C).withValues(alpha: 0.8);
      }
      return const Color(0xFF22C55E).withValues(alpha: 0.7);
    }

    if (status == 'low') {
      return const Color(0xFFFB923C).withValues(alpha: 0.8);
    }

    return const Color(0xFFFFFFFF).withValues(alpha: 0.15);
  }

  Widget _buildSlotsSection() {
    if (_selectedDate == null) {
      return _buildMessageCard(
        'Sélectionnez une date pour voir les créneaux disponibles.',
      );
    }

    if (_loadingSlots) {
      return _buildCenteredCard(
        child: const CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return _buildMessageCard(_errorMessage!);
    }

    if (_slots.isEmpty) {
      return _buildMessageCard(
        'Aucun créneau disponible pour ${_formatDateFr(_selectedDate!)}.\nEssayez une autre date.',
      );
    }

    return _buildPanelCard(
      child: _RescheduleSlotsGrid(
        slots: _slots,
        selectedTime: _selectedTime,
        onTap: (slot) {
          setState(() {
            _selectedTime = slot.time;
          });
        },
      ),
    );
  }

  Widget _buildCenteredCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: _CompteScreenShell._cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(child: child),
    );
  }

  Widget _buildMessageCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _CompteScreenShell._cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white70, height: 1.45),
      ),
    );
  }

  String _selectedSlotMessage() {
    if (_selectedDate == null || _selectedTime == null) {
      return 'Choisissez un créneau pour confirmer.';
    }
    return 'Créneau sélectionné: ${_shortTime(_selectedTime!)}';
  }

  @override
  Widget build(BuildContext context) {
    final isActionDisabled =
        _loadingSlots ||
        _submitting ||
        _selectedDate == null ||
        _selectedTime == null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final calendarDays = _calendarDays();

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Material(
        color: _CompteScreenShell._pageBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 46,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Décaler le rendez-vous',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 18),
                      _buildSectionTitle('Choisir une nouvelle date'),
                      const SizedBox(height: 10),
                      _buildPanelCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCalendarHeader(),
                            if (_monthErrorMessage != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _monthErrorMessage!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            _buildWeekdaysRow(),
                            const SizedBox(height: 8),
                            GridView.builder(
                              itemCount: calendarDays.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 7,
                                    mainAxisSpacing: 4,
                                    crossAxisSpacing: 4,
                                    mainAxisExtent: 44,
                                  ),
                              itemBuilder: (context, index) {
                                final day = calendarDays[index];
                                return _RescheduleCalendarDayCell(
                                  day: day,
                                  dotColor: _dotColorForDay(day),
                                  onTap: day.isSelectable
                                      ? () => _selectDate(day.date!)
                                      : null,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildSectionTitle('Créneaux disponibles'),
                      const SizedBox(height: 10),
                      _buildSlotsSection(),
                      if (_selectedDate != null &&
                          _errorMessage == null &&
                          _slots.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          _selectedSlotMessage(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (widget.booking.rescheduled) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Un seul déplacement est autorisé par rendez-vous.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isActionDisabled
                              ? null
                              : _confirmReschedule,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white.withValues(
                              alpha: 0.16,
                            ),
                            disabledForegroundColor: Colors.white.withValues(
                              alpha: 0.35,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text(
                                  'Confirmer le nouveau créneau',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RescheduleCalendarDay {
  const _RescheduleCalendarDay({
    required this.date,
    required this.isPast,
    required this.isToday,
    required this.isSelected,
    this.availability,
  });

  const _RescheduleCalendarDay.empty()
    : date = null,
      isPast = false,
      isToday = false,
      isSelected = false,
      availability = null;

  final DateTime? date;
  final bool isPast;
  final bool isToday;
  final bool isSelected;
  final ReservationMonthAvailability? availability;

  bool get isSelectable => date != null && !isPast;
}

class _CalendarNavButton extends StatelessWidget {
  const _CalendarNavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(
            icon,
            size: 20,
            color: onTap == null
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _RescheduleCalendarDayCell extends StatelessWidget {
  const _RescheduleCalendarDayCell({
    required this.day,
    required this.dotColor,
    required this.onTap,
  });

  final _RescheduleCalendarDay day;
  final Color? dotColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (day.date == null) {
      return const SizedBox.shrink();
    }

    final selected = day.isSelected;
    final availability = day.availability;
    final isFull = availability != null && availability.total <= 0;
    final dayTextColor = selected
        ? Colors.black
        : day.isPast
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.82);
    final textDecoration = isFull && !selected
        ? TextDecoration.lineThrough
        : TextDecoration.none;

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
                border: day.isToday && !selected
                    ? Border.all(color: Colors.white.withValues(alpha: 0.4))
                    : null,
              ),
              child: Center(
                child: Text(
                  '${day.date!.day}',
                  style: TextStyle(
                    color: dayTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    decoration: textDecoration,
                    decorationColor: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 1),
            if (!selected && dotColor != null)
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: dotColor,
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

class _RescheduleSlotsGrid extends StatelessWidget {
  const _RescheduleSlotsGrid({
    required this.slots,
    required this.selectedTime,
    required this.onTap,
  });

  final List<ReservationSlot> slots;
  final String? selectedTime;
  final ValueChanged<ReservationSlot> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: slots.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 42,
      ),
      itemBuilder: (context, index) {
        final slot = slots[index];
        final selected = slot.time == selectedTime;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTap(slot),
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
                  slot.time.length >= 5 ? slot.time.substring(0, 5) : slot.time,
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CompteScreenShell extends ConsumerWidget {
  const _CompteScreenShell({
    required this.onChangeAvatar,
    required this.onEditProfile,
    required this.onChangePassword,
    required this.onDeleteAccount,
    required this.onLogout,
  });

  final Future<void> Function() onChangeAvatar;
  final VoidCallback onEditProfile;
  final VoidCallback onChangePassword;
  final VoidCallback onDeleteAccount;
  final Future<void> Function() onLogout;

  static const Color _pageBackground = Color(0xFF121212);
  static const Color _cardBackground = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final reservationState = ref.watch(reservationSessionProvider);
    final appUser = authState.user;
    final reservationUser = reservationState.user;
    final theme = Theme.of(context);

    final isBootstrapping =
        authState.status == AuthStatus.authenticating ||
        reservationState.status == ReservationSessionStatus.authenticating;
    final hasReservationSession =
        appUser != null &&
        reservationState.status == ReservationSessionStatus.authenticated &&
        reservationUser != null;

    final selectedReservationSalonId = ref.watch(
      selectedReservationSalonIdForRdvProvider,
    );
    final salonFilter = selectedReservationSalonId?.trim();
    final bookingsSalonId = salonFilter != null && salonFilter.isNotEmpty
        ? salonFilter
        : null;

    final bookingsAsync = hasReservationSession
        ? ref.watch(reservationClientBookingsProvider(bookingsSalonId))
        : null;

    final displayName = reservationUser?.fullName.trim().isNotEmpty == true
        ? reservationUser!.fullName.trim()
        : (appUser?.fullName?.trim().isNotEmpty == true
              ? appUser!.fullName!.trim()
              : 'Utilisateur');
    final firstName = reservationUser?.firstName.trim().isNotEmpty == true
        ? reservationUser!.firstName.trim()
        : (displayName.contains(' ')
              ? displayName.split(' ').first
              : displayName);
    final initials = _initials(displayName);
    final bookingsData = bookingsAsync?.valueOrNull;
    final upcomingCount = bookingsData?.upcoming.length ?? 0;
    final completedCount = bookingsData == null
        ? 0
        : bookingsData.past
              .where((booking) => booking.status == 'completed')
              .length;
    final memberSince = _formatMemberSince(reservationUser?.createdAt);
    final memberDuration = _formatMemberDuration(reservationUser?.createdAt);

    return Scaffold(
      backgroundColor: _pageBackground,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          'MON PROFIL',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: isBootstrapping
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : !hasReservationSession
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Vous etes en mode invite.\nConnectez-vous pour acceder a votre compte et a vos rendez-vous.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () =>
                            context.go('/login?redirect=%2Fcompte'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white12,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Se connecter'),
                      ),
                    ],
                  ),
                ),
              )
            : DefaultTabController(
                length: 2,
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                        child: Column(
                          children: [
                            _buildAvatar(
                              initials: initials,
                              avatarUrl: appUser?.avatarUrl,
                              size: 104,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              firstName.isNotEmpty
                                  ? 'Bonjour, $firstName.'
                                  : 'Bonjour.',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Membre depuis $memberSince',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white60,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                _buildStatCard(
                                  context,
                                  value: bookingsAsync?.hasError == true
                                      ? '—'
                                      : completedCount.toString(),
                                  label: 'Visites',
                                ),
                                const SizedBox(width: 10),
                                _buildStatCard(
                                  context,
                                  value: memberDuration,
                                  label: 'Membre',
                                ),
                                const SizedBox(width: 10),
                                _buildStatCard(
                                  context,
                                  value: bookingsAsync?.hasError == true
                                      ? '—'
                                      : upcomingCount.toString(),
                                  label: 'A venir',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _cardBackground,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: TabBar(
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.white60,
                            dividerColor: Colors.transparent,
                            splashFactory: NoSplash.splashFactory,
                            overlayColor: const MaterialStatePropertyAll(
                              Colors.transparent,
                            ),
                            tabs: const [
                              Tab(text: 'Mes RDV'),
                              Tab(text: 'Mon Profil'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                  body: TabBarView(
                    children: [
                      if (bookingsAsync == null)
                        const SizedBox.shrink()
                      else
                        _buildBookingsTab(
                          context: context,
                          ref: ref,
                          bookingsAsync: bookingsAsync,
                          salonFilter: bookingsSalonId,
                        ),
                      _buildProfileTab(
                        context: context,
                        appUser: appUser,
                        reservationUser: reservationUser,
                      ),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: const BottomNavBar(
        key: ValueKey('account-bottom-nav'),
        activeBranchIndex: 4,
      ),
    );
  }

  Widget _buildBookingsTab({
    required BuildContext context,
    required WidgetRef ref,
    required AsyncValue<ReservationClientBookingsPage> bookingsAsync,
    required String? salonFilter,
  }) {
    return bookingsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (error, stackTrace) =>
          _buildBookingsError(context, ref, error, salonFilter),
      data: (bookings) => _buildBookingsContent(
        context: context,
        ref: ref,
        bookings: bookings,
        salonFilter: salonFilter,
      ),
    );
  }

  Widget _buildBookingsContent({
    required BuildContext context,
    required WidgetRef ref,
    required ReservationClientBookingsPage bookings,
    required String? salonFilter,
  }) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bookings.isEmpty) ...[
            _buildEmptyBookingsState(context),
          ] else ...[
            if (bookings.upcoming.isNotEmpty) ...[
              _buildSectionTitle('Prochain RDV'),
              _buildNextBookingCard(
                context: context,
                ref: ref,
                booking: bookings.nextUpcoming!,
                salonFilter: salonFilter,
              ),
              if (bookings.upcoming.length > 1) ...[
                const SizedBox(height: 6),
                for (final booking in bookings.upcoming.skip(1))
                  _buildBookingCard(booking: booking, isPast: false),
              ],
            ],
            if (bookings.past.isNotEmpty) ...[
              if (bookings.upcoming.isNotEmpty) const SizedBox(height: 24),
              _buildSectionTitle('Historique'),
              for (final booking in bookings.past.take(10))
                _buildBookingCard(booking: booking, isPast: true),
            ],
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/rdv'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text(
                'Prendre un RDV',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsError(
    BuildContext context,
    WidgetRef ref,
    Object error,
    String? salonFilter,
  ) {
    final message = error is ApiError
        ? error.getFriendlyMessage()
        : 'Impossible de charger vos rendez-vous. Veuillez reessayer.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_busy_outlined,
              color: Colors.white54,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(reservationClientBookingsProvider(salonFilter));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white12,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyBookingsState(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_outlined,
              color: Colors.white70,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Aucun rendez-vous pour le moment',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Vos prochains RDV apparaitront ici apres une reservation.',
            style: TextStyle(color: Colors.white60, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildNextBookingCard({
    required BuildContext context,
    required WidgetRef ref,
    required ReservationBooking booking,
    required String? salonFilter,
  }) {
    final barberInitials = _initials(
      booking.barberName.isNotEmpty ? booking.barberName : booking.serviceName,
    );
    final canCancel = _canModifyBooking(booking);
    final canReschedule = canCancel && !booking.rescheduled;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.bolt, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Prochain RDV',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _buildStatusBadge(booking.status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 58,
                height: 58,
                child: ClipOval(
                  child: _buildBookingAvatar(
                    booking: booking,
                    initials: barberInitials,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.serviceName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.barberName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Prestation', booking.serviceName),
          _buildDetailRow('Barber', booking.barberName),
          _buildDetailRow('Date', _formatDateFr(booking.date)),
          _buildDetailRow(
            'Horaire',
            '${_formatTime(booking.startTime)} — ${_formatTime(booking.endTime)}',
          ),
          _buildDetailRow('Prix', _formatPrice(booking.priceCents)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildActionButton(
                label: 'Décaler',
                icon: Icons.edit_calendar_outlined,
                onPressed: canReschedule
                    ? () => _showRescheduleBookingDialog(
                        context,
                        ref,
                        booking,
                        salonFilter,
                      )
                    : null,
              ),
              _buildActionButton(
                label: 'Annuler',
                icon: Icons.close_rounded,
                onPressed: canCancel
                    ? () => _showCancelBookingDialog(
                        context,
                        ref,
                        booking,
                        salonFilter,
                      )
                    : null,
              ),
            ],
          ),
          if (booking.rescheduled) ...[
            const SizedBox(height: 10),
            Text(
              'Ce rendez-vous a déjà été décalé une fois.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookingCard({
    required ReservationBooking booking,
    required bool isPast,
  }) {
    final barberInitials = _initials(
      booking.barberName.isNotEmpty ? booking.barberName : booking.serviceName,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: ClipOval(
              child: _buildBookingAvatar(
                booking: booking,
                initials: barberInitials,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        booking.serviceName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildStatusBadge(booking.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  booking.barberName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 15,
                      color: isPast ? Colors.white38 : Colors.white60,
                    ),
                    Text(
                      _formatDateShort(booking.date),
                      style: TextStyle(
                        color: isPast ? Colors.white54 : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.white30,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      _formatTime(booking.startTime),
                      style: TextStyle(
                        color: isPast ? Colors.white54 : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.white30,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      _formatPrice(booking.priceCents),
                      style: TextStyle(
                        color: isPast ? Colors.white54 : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab({
    required BuildContext context,
    required User? appUser,
    required ReservationClientProfile? reservationUser,
  }) {
    final displayName = reservationUser?.fullName.trim().isNotEmpty == true
        ? reservationUser!.fullName.trim()
        : (appUser?.fullName?.trim().isNotEmpty == true
              ? appUser!.fullName!.trim()
              : 'Utilisateur');
    final initials = _initials(displayName);
    final memberSince = _formatMemberSince(reservationUser?.createdAt);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildAvatar(
            initials: initials,
            avatarUrl: appUser?.avatarUrl,
            size: 104,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => onChangeAvatar(),
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: const Text('Changer la photo'),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mes Informations',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Colors.white70,
                        ),
                        onPressed: onEditProfile,
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10),
                _buildProfileRow(
                  icon: Icons.person_outline,
                  label: 'Prenom',
                  value: reservationUser?.firstName ?? '—',
                ),
                _buildProfileRow(
                  icon: Icons.person_outline,
                  label: 'Nom',
                  value: reservationUser?.lastName ?? '—',
                ),
                _buildProfileRow(
                  icon: Icons.phone_outlined,
                  label: 'Telephone',
                  value: reservationUser?.phone ?? '—',
                ),
                _buildProfileRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: reservationUser?.email ?? '—',
                ),
                _buildProfileRow(
                  icon: Icons.verified_outlined,
                  label: 'Membre depuis',
                  value: memberSince,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Container(
            decoration: BoxDecoration(
              color: _cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_outline, color: Colors.white70),
              ),
              title: const Text(
                'Mot de passe',
                style: TextStyle(color: Colors.white),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.white54,
              ),
              onTap: onChangePassword,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onDeleteAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A1010),
                foregroundColor: Colors.redAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0x66FF5252)),
                ),
              ),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text(
                'Supprimer mon compte',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () async => onLogout(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.05),
                foregroundColor: Colors.redAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text(
                'Se deconnecter',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: _cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar({
    required String initials,
    required String? avatarUrl,
    required double size,
  }) {
    final resolved = avatarUrl?.trim();
    Widget child = _avatarFallback(initials);

    if (resolved != null && resolved.isNotEmpty) {
      if (resolved.startsWith('data:image/')) {
        final commaIndex = resolved.indexOf(',');
        if (commaIndex > 0) {
          try {
            child = Image.memory(
              base64Decode(resolved.substring(commaIndex + 1)),
              fit: BoxFit.cover,
            );
          } catch (_) {
            child = _avatarFallback(initials);
          }
        }
      } else {
        final imageUrl =
            AppConfig.resolveImageUrl(resolved) ??
            AppConfig.resolvePublicAssetUrl(resolved) ??
            resolved;
        child = CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => _avatarFallback(initials),
          errorWidget: (_, __, ___) => _avatarFallback(initials),
        );
      }
    }

    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.04),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: ClipOval(child: child),
      ),
    );
  }

  Widget _avatarFallback(String initials) {
    return Container(
      color: Colors.white.withOpacity(0.05),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: onPressed == null ? Colors.white38 : Colors.white,
        side: BorderSide(
          color: onPressed == null ? Colors.white10 : Colors.white24,
        ),
        backgroundColor: Colors.white.withOpacity(0.03),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final normalized = status.trim().toLowerCase();
    final label = switch (normalized) {
      'confirmed' => 'Confirme',
      'completed' => 'Termine',
      'cancelled' => 'Annule',
      'no_show' => 'Absent',
      _ => status,
    };
    final color = switch (normalized) {
      'completed' => const Color(0xFF4ADE80),
      'cancelled' => const Color(0xFFF87171),
      'confirmed' => const Color(0xFFF5A524),
      _ => Colors.white70,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildBookingAvatar({
    required ReservationBooking booking,
    required String initials,
  }) {
    final photoUrl = booking.barberPhotoUrl?.trim();
    if (photoUrl == null || photoUrl.isEmpty) {
      return _avatarFallback(initials);
    }

    if (photoUrl.startsWith('data:image/')) {
      final commaIndex = photoUrl.indexOf(',');
      if (commaIndex > 0) {
        try {
          return Image.memory(
            base64Decode(photoUrl.substring(commaIndex + 1)),
            fit: BoxFit.cover,
          );
        } catch (_) {
          return _avatarFallback(initials);
        }
      }
    }

    final resolved =
        AppConfig.resolveImageUrl(photoUrl) ??
        AppConfig.resolvePublicAssetUrl(photoUrl) ??
        photoUrl;
    return CachedNetworkImage(
      imageUrl: resolved,
      fit: BoxFit.cover,
      placeholder: (_, __) => _avatarFallback(initials),
      errorWidget: (_, __, ___) => _avatarFallback(initials),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String time) {
    if (time.length >= 5) {
      return time.substring(0, 5);
    }
    return time;
  }

  String _initials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.trim().substring(0, 1).toUpperCase();
    }
    return '${parts.first.trim().substring(0, 1)}${parts[1].trim().substring(0, 1)}'
        .toUpperCase();
  }

  String _formatPrice(int cents) {
    if (cents <= 0) return '—';
    final euros = cents / 100.0;
    return '${euros.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  String _formatDateFr(String dateStr) {
    final date = DateTime.tryParse('${dateStr}T00:00:00');
    if (date == null) return dateStr;
    const weekdays = <String>[
      'Dimanche',
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
    ];
    const months = <String>[
      'Janvier',
      'Fevrier',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Aout',
      'Septembre',
      'Octobre',
      'Novembre',
      'Decembre',
    ];
    return '${weekdays[date.weekday % 7]} ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateShort(String dateStr) {
    final date = DateTime.tryParse('${dateStr}T00:00:00');
    if (date == null) return dateStr;
    const weekdays = <String>[
      'Dim.',
      'Lun.',
      'Mar.',
      'Mer.',
      'Jeu.',
      'Ven.',
      'Sam.',
    ];
    const months = <String>[
      'Jan',
      'Fev',
      'Mars',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Aout',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[date.weekday % 7]} ${date.day} ${months[date.month - 1]}';
  }

  String _formatMemberDuration(DateTime? createdAt) {
    if (createdAt == null) return '—';
    final diffDays = DateTime.now().difference(createdAt).inDays;
    if (diffDays < 30) return '${diffDays.clamp(0, 999)}j';
    if (diffDays < 365) return '${(diffDays / 30).floor()} mois';
    final years = (diffDays / 365).floor();
    return '$years an${years > 1 ? 's' : ''}';
  }

  String _formatMemberSince(DateTime? createdAt) {
    if (createdAt == null) return '—';
    const months = <String>[
      'Janvier',
      'Fevrier',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Aout',
      'Septembre',
      'Octobre',
      'Novembre',
      'Decembre',
    ];
    return '${months[createdAt.month - 1]} ${createdAt.year}';
  }

  bool _canModifyBooking(ReservationBooking booking) {
    final bookingDate = DateTime.tryParse(
      '${booking.date}T${booking.startTime}',
    );
    if (bookingDate == null) return false;
    return bookingDate.difference(DateTime.now()) >= const Duration(hours: 12);
  }

  Future<ReservationBooking> _resolveBookingForReschedule(
    ReservationBooking booking,
    String? salonFilter,
    ReservationRepository repository,
  ) async {
    final hasAvailabilityIds =
        booking.serviceId.trim().isNotEmpty &&
        booking.barberId.trim().isNotEmpty;
    final hasSalonId =
        booking.salonId.trim().isNotEmpty ||
        (salonFilter?.trim().isNotEmpty == true);

    if (hasAvailabilityIds && hasSalonId) {
      if (booking.salonId.trim().isNotEmpty) {
        return booking;
      }
      return booking.copyWith(salonId: salonFilter!.trim());
    }

    final details = await repository.getBookingDetails(
      bookingId: booking.id,
      cancelToken: booking.cancelToken,
    );

    final resolvedSalonId = booking.salonId.trim().isNotEmpty
        ? booking.salonId.trim()
        : (salonFilter?.trim().isNotEmpty == true
              ? salonFilter!.trim()
              : details.salonId);

    return details.copyWith(salonId: resolvedSalonId);
  }

  Future<void> _showRescheduleBookingDialog(
    BuildContext context,
    WidgetRef ref,
    ReservationBooking booking,
    String? salonFilter,
  ) async {
    if (!_canModifyBooking(booking)) {
      AppSnackBar.show(
        context,
        'Les modifications sont possibles au moins 12 heures avant le rendez-vous.',
      );
      return;
    }

    final repository = ref.read(reservationRepositoryProvider);
    late final ReservationBooking bookingForReschedule;
    try {
      bookingForReschedule = await _resolveBookingForReschedule(
        booking,
        salonFilter,
        repository,
      );
    } catch (error) {
      if (!context.mounted) return;

      final message = error is ApiError
          ? error.getFriendlyMessage()
          : 'Impossible de charger les détails du rendez-vous.';
      AppSnackBar.show(
        context,
        message,
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Colors.white,
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    if (!context.mounted) return;

    final rescheduled = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _RescheduleBookingSheetV2(
          booking: bookingForReschedule,
          repository: repository,
        );
      },
    );

    if (rescheduled == true) {
      ref.invalidate(reservationClientBookingsProvider(salonFilter));
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        'Rendez-vous décalé avec succès.',
        backgroundColor: Colors.green,
        icon: Icons.check_circle_outline_rounded,
      );
    }
  }

  Future<void> _showCancelBookingDialog(
    BuildContext context,
    WidgetRef ref,
    ReservationBooking booking,
    String? salonFilter,
  ) async {
    if (!_canModifyBooking(booking)) {
      AppSnackBar.show(
        context,
        'Les annulations sont possibles au moins 12 heures avant le rendez-vous.',
      );
      return;
    }

    bool isLoading = false;
    final cancelled = await showDialog<bool>(
      context: context,
      barrierDismissible: !isLoading,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _cardBackground,
              title: const Text(
                'Annuler le RDV ?',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Cette action est irreversible. Vous devrez reprendre un nouveau rendez-vous.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Non'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setDialogState(() => isLoading = true);
                          try {
                            await ref
                                .read(reservationRepositoryProvider)
                                .cancelBooking(
                                  bookingId: booking.id,
                                  cancelToken: booking.cancelToken,
                                  salonId: booking.salonId,
                                );
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop(true);
                          } catch (error) {
                            if (dialogContext.mounted) {
                              setDialogState(() => isLoading = false);
                              final message = error is ApiError
                                  ? error.getFriendlyMessage()
                                  : 'Impossible d\'annuler le rendez-vous.';
                              AppSnackBar.show(
                                context,
                                message,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                                foregroundColor: Colors.white,
                                icon: Icons.error_outline_rounded,
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A1717),
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Oui, annuler'),
                ),
              ],
            );
          },
        );
      },
    );
    if (cancelled == true) {
      ref.invalidate(reservationClientBookingsProvider(salonFilter));
    }
  }
}
