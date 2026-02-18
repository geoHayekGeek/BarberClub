import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/barber.dart';
import '../constants/barber_ui_constants.dart';
import '../providers/barber_providers.dart';

/// Single Barber Detail: fullscreen video hero, info cards, à propos, CTA, gallery.
class BarberDetailScreen extends ConsumerWidget {
  final String barberId;

  const BarberDetailScreen({
    super.key,
    required this.barberId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barberAsync = ref.watch(barberDetailProvider(barberId));

    return barberAsync.when(
      data: (barber) => _BarberDetailContent(barber: barber),
      loading: () => Scaffold(
        backgroundColor: const Color(0xFF0E0E10),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: const SafeArea(
          child: Center(
            child: CircularProgressIndicator(color: Colors.white70),
          ),
        ),
      ),
      error: (error, stackTrace) {
        final message = getBarberErrorMessage(error, stackTrace);
        return Scaffold(
          backgroundColor: const Color(0xFF0E0E10),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(BarberUIConstants.horizontalGutter),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: BarberUIConstants.sectionSpacing),
                    FilledButton.icon(
                      onPressed: () =>
                          ref.invalidate(barberDetailProvider(barberId)),
                      icon: const Icon(Icons.refresh),
                      label: const Text(BarberStrings.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BarberDetailContent extends StatefulWidget {
  final Barber barber;

  const _BarberDetailContent({required this.barber});

  @override
  State<_BarberDetailContent> createState() => _BarberDetailContentState();
}

class _BarberDetailContentState extends State<_BarberDetailContent> {
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final headerHeight = mediaQuery.size.height * 0.65;
    final paddingH = BarberUIConstants.horizontalGutter;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: headerHeight,
              child: _BarberVideoHeader(
                barber: widget.barber,
                onBack: () => context.pop(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                paddingH,
                24,
                paddingH,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InfoCardsRow(barber: widget.barber),
                  const SizedBox(height: 24),
                  _AProposSection(barber: widget.barber),
                  const SizedBox(height: 24),
                  _CtaButton(barber: widget.barber),
                  const SizedBox(height: 32),
                  _SectionTitleWithDivider(title: 'SES RÉALISATIONS'),
                  const SizedBox(height: 16),
                  _GalleryGrid(imageUrls: widget.barber.galleryImages),
                  SizedBox(height: 24 + mediaQuery.padding.bottom),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarberVideoHeader extends StatefulWidget {
  final Barber barber;
  final VoidCallback onBack;

  const _BarberVideoHeader({
    required this.barber,
    required this.onBack,
  });

  @override
  State<_BarberVideoHeader> createState() => _BarberVideoHeaderState();
}

class _BarberVideoHeaderState extends State<_BarberVideoHeader>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _useVideo = false;

  @override
  void initState() {
    super.initState();
    _initMedia();
  }

  Future<void> _initMedia() async {
    final videoUrl = widget.barber.videoUrl;
    if (videoUrl != null && videoUrl.startsWith('http')) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..setLooping(true)
        ..setVolume(0);
      try {
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _useVideo = true;
            _initialized = true;
          });
          _controller!.play();
        }
      } catch (_) {
        if (mounted) {
          setState(() => _initialized = true);
        }
        await _controller?.dispose();
        _controller = null;
      }
    } else {
      if (mounted) setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final barber = widget.barber;
    final salonLabel = barber.salons.isNotEmpty
        ? barber.salons.first.name.toUpperCase()
        : 'SALON DE GRENOBLE';

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_useVideo && _controller != null && _controller!.value.isInitialized)
          Positioned.fill(
            child: FadeTransition(
              opacity: AlwaysStoppedAnimation(_initialized ? 1.0 : 0.0),
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
          )
        else
          Positioned.fill(
            child: barber.image != null && barber.image!.startsWith('http')
                ? Image.network(
                    barber.image!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.6),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Material(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          onTap: widget.onBack,
                          borderRadius: BorderRadius.circular(24),
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'BARBER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'CLUB',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                barber.displayName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'BARBER',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      salonLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: Icon(Icons.person, size: 80, color: Colors.white24),
      ),
    );
  }
}

class _InfoCardsRow extends StatelessWidget {
  final Barber barber;

  const _InfoCardsRow({required this.barber});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InfoCard(
            value: barber.age != null ? '${barber.age}' : '—',
            label: 'ANS',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _InfoCard(
            value: (barber.origin ?? '').isNotEmpty
                ? barber.origin!.toUpperCase()
                : '—',
            label: 'ORIGINE',
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String value;
  final String label;

  const _InfoCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AProposSection extends StatelessWidget {
  final Barber barber;

  const _AProposSection({required this.barber});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'À PROPOS',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: Text(
            barber.bio.isNotEmpty
                ? barber.bio
                : 'Aucune description disponible.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _CtaButton extends StatelessWidget {
  final Barber barber;

  const _CtaButton({required this.barber});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Material(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            context.go('/rdv');
          },
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, color: Colors.black87, size: 22),
                const SizedBox(width: 12),
                Text(
                  'PRENDRE RDV AVEC ${barber.displayName.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitleWithDivider extends StatelessWidget {
  final String title;

  const _SectionTitleWithDivider({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 16),
            height: 1,
            color: Colors.white.withOpacity(0.2),
          ),
        ),
      ],
    );
  }
}

class _GalleryGrid extends StatelessWidget {
  final List<String> imageUrls;

  const _GalleryGrid({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: imageUrls.length,
      itemBuilder: (context, index) {
        final url = AppConfig.resolveImageUrl(imageUrls[index]);
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: url != null && url.startsWith('http')
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        );
      },
    );
  }

  static Widget _placeholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined,
            color: Colors.white24, size: 40),
      ),
    );
  }
}
