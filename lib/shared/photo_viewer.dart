import 'package:flutter/material.dart';

import '../core/models/poi.dart';
import 'photos.dart';

/// Hero tag shared by an expandable [PlaceArt] and the full-screen viewer.
String photoHeroTag(Poi poi) => 'photo-${poi.id}';

/// Opens the destination's photos full screen (pinch or double-tap to zoom,
/// swipe for the next photo), starting at [index]. Returns the index of the
/// photo showing when it closes. Does nothing when the place has no image.
Future<int?> openPhotoViewer(BuildContext context, Poi poi, {int index = 0}) async {
  final photos = Photos.allOf(poi.id);
  if (photos.isEmpty) return null;
  final start = index.clamp(0, photos.length - 1);
  return Navigator.of(context).push<int>(PageRouteBuilder<int>(
    opaque: false,
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, anim, __) =>
        FadeTransition(opacity: anim, child: PhotoViewerScreen(poi: poi, photos: photos, initialIndex: start)),
  ));
}

class PhotoViewerScreen extends StatefulWidget {
  final Poi poi;
  final List<PhotoCredit> photos;
  final int initialIndex;
  const PhotoViewerScreen({super.key, required this.poi, required this.photos, this.initialIndex = 0});

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop(_index);

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];
    final n = widget.photos.length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_index);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pages,
              itemCount: n,
              physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
              onPageChanged: (i) => setState(() {
                _index = i;
                _zoomed = false;
              }),
              itemBuilder: (_, i) => _ZoomablePhoto(
                key: ValueKey(widget.photos[i].asset),
                poi: widget.poi,
                photo: widget.photos[i],
                hero: i == _index,
                onZoom: (z) {
                  if (z != _zoomed) setState(() => _zoomed = z);
                },
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
                    onPressed: _close,
                  ),
                ),
              ),
            ),
          ),
          if (n > 1)
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: Text('${_index + 1} / $n',
                        semanticsLabel: 'Photo ${_index + 1} of $n',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
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
                      if (photo.isSupplied && photo.title.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(photo.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                      const SizedBox(height: 4),
                      Text(photo.line, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(n > 1 ? 'Swipe for more photos · pinch or double-tap to zoom' : 'Pinch or double-tap to zoom',
                          style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// One photo page: pinch or double-tap to zoom. Reports zoom so the pager
/// does not steal the pan while the photo is enlarged.
class _ZoomablePhoto extends StatefulWidget {
  final Poi poi;
  final PhotoCredit photo;
  final bool hero;
  final ValueChanged<bool> onZoom;
  const _ZoomablePhoto({super.key, required this.poi, required this.photo, required this.hero, required this.onZoom});

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final _zoom = TransformationController();
  TapDownDetails? _tap;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(() => widget.onZoom(_zoom.value.getMaxScaleOnAxis() > 1.01));
  }

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
    final Widget image = Image.asset(
      photo.asset,
      fit: BoxFit.contain,
      semanticLabel: photo.isIllustration
          ? 'Illustration of ${widget.poi.name}, not a photo'
          : 'Photo of ${widget.poi.name}',
    );
    return GestureDetector(
      onDoubleTapDown: (d) => _tap = d,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _zoom,
        minScale: 1,
        maxScale: 5,
        child: Center(child: widget.hero ? Hero(tag: photoHeroTag(widget.poi), child: image) : image),
      ),
    );
  }
}
