import 'package:flutter/material.dart';

import '../core/models/poi.dart';
import 'photos.dart';

/// Hero tag shared by an expandable [PlaceArt] and the full-screen viewer.
String photoHeroTag(Poi poi) => 'photo-${poi.id}';

/// Opens the destination's photo full screen (pinch or double-tap to zoom).
/// Does nothing when the place has no bundled photo or illustration.
Future<void> openPhotoViewer(BuildContext context, Poi poi) async {
  final photo = Photos.of(poi.id);
  if (photo == null) return;
  await Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, anim, __) => FadeTransition(opacity: anim, child: PhotoViewerScreen(poi: poi, photo: photo)),
  ));
}

class PhotoViewerScreen extends StatefulWidget {
  final Poi poi;
  final PhotoCredit photo;
  const PhotoViewerScreen({super.key, required this.poi, required this.photo});

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  final _zoom = TransformationController();
  TapDownDetails? _tap;

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_zoom.value.getMaxScaleOnAxis() > 1.01) {
      _zoom.value = Matrix4.identity();
      return;
    }
    final p = _tap?.localPosition ?? Offset.zero;
    const s = 2.5;
    _zoom.value = Matrix4.diagonal3Values(s, s, 1)..setTranslationRaw(-p.dx * (s - 1), -p.dy * (s - 1), 0);
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        Positioned.fill(
          child: GestureDetector(
            onDoubleTapDown: (d) => _tap = d,
            onDoubleTap: _toggleZoom,
            child: InteractiveViewer(
              transformationController: _zoom,
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Hero(
                  tag: photoHeroTag(widget.poi),
                  child: Image.asset(
                    photo.asset,
                    fit: BoxFit.contain,
                    semanticLabel: photo.isIllustration
                        ? 'Illustration of ${widget.poi.name}, not a photo'
                        : 'Photo of ${widget.poi.name}',
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Close photo',
                  iconSize: 28,
                  color: Colors.white,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xCC000000)],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.poi.name,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(photo.line, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    const Text('Pinch or double-tap to zoom',
                        style: TextStyle(color: Colors.white60, fontSize: 12.5)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
