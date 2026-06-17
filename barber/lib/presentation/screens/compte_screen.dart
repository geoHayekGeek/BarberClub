import 'dart:convert';
import 'dart:typed_data';

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
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../domain/models/api_error.dart';
import '../../domain/models/reservation_models.dart';
import '../../domain/models/reservation_session.dart';
import '../../domain/models/user.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo de profil mise a jour.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_avatarUploadErrorMessage(error)),
          backgroundColor: Colors.redAccent,
        ),
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
    return bookingDate.difference(DateTime.now()).inHours >= 12;
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
        if (context.mounted) context.go('/home');
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  message.isEmpty
                                      ? 'Impossible de supprimer le compte. Veuillez réessayer.'
                                      : message,
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre compte a été supprimé avec succès.'),
        ),
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
                          Navigator.pop(ctx);
                          await ref
                              .read(authStateProvider.notifier)
                              .updateProfile(
                                fullName: nameCtrl.text,
                                email: emailCtrl.text,
                                phoneNumber: completePhoneNumber,
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profil mis à jour'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur: $e'),
                                backgroundColor: Colors.red,
                              ),
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
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Mot de passe modifié avec succès',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
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
                child: Column(
                  children: [
                    Padding(
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
                    Padding(
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
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
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
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const BottomNavBar(
        key: ValueKey('account-bottom-nav'),
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
                label: 'Decaler',
                icon: Icons.open_in_new_rounded,
                onPressed: () async {
                  await launchUrl(
                    _buildManageBookingUri(booking),
                    mode: LaunchMode.externalApplication,
                  );
                },
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
              _buildActionButton(
                label: 'Calendrier',
                icon: Icons.calendar_month_outlined,
                onPressed: () async {
                  await launchUrl(
                    _buildBookingIcsUri(booking),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
            ],
          ),
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
    return bookingDate.difference(DateTime.now()).inHours >= 12;
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

  Future<void> _showCancelBookingDialog(
    BuildContext context,
    WidgetRef ref,
    ReservationBooking booking,
    String? salonFilter,
  ) async {
    if (!_canModifyBooking(booking)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Les annulations sont possibles au moins 12h avant le rendez-vous.',
          ),
        ),
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(message),
                                  backgroundColor: Colors.redAccent,
                                ),
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
