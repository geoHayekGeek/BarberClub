import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Website galleries mix photos and videos. Load video only after a deliberate
/// tap so a team profile does not download all haircut videos at once.
class WebsiteMediaTile extends StatefulWidget {
  const WebsiteMediaTile({super.key, required this.url});
  final String url;

  @override
  State<WebsiteMediaTile> createState() => _WebsiteMediaTileState();
}

class _WebsiteMediaTileState extends State<WebsiteMediaTile> {
  VideoPlayerController? _video;
  bool _loading = false;
  bool _failed = false;

  Future<void> _play() async {
    if (_loading) return;
    if (_video?.value.isInitialized == true) {
      if (_video!.value.isPlaying) {
        await _video!.pause();
      } else {
        await _video!.play();
      }
      if (mounted) setState(() {});
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    final previous = _video;
    _video = null;
    await previous?.dispose();
    if (!mounted) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _video = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
    } catch (_) {
      if (mounted) _failed = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = RegExp(
      r'\.(mp4|webm|mov)$',
      caseSensitive: false,
    ).hasMatch(Uri.parse(widget.url).path);
    if (!isVideo)
      return Image.network(
        widget.url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image_outlined, color: Colors.white38),
      );
    return Material(
      color: const Color(0xFF181818),
      child: InkWell(
        onTap: _play,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_video?.value.isInitialized == true)
              Center(
                child: AspectRatio(
                  aspectRatio: _video!.value.aspectRatio,
                  child: VideoPlayer(_video!),
                ),
              ),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading && _video?.value.isPlaying != true)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _failed ? Icons.refresh : Icons.play_circle_outline,
                      color: Colors.white70,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _failed ? 'Réessayer' : 'Voir la vidéo',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
