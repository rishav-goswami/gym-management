import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/exercise_guide.dart';

/// Resolves core guidance media from the active project's Storage bucket and
/// lets cached_network_image persist it on-device. The pinned public-domain
/// source is a bootstrap fallback until a new project runs `catalog:sync`.
class ExerciseMediaImage extends StatefulWidget {
  const ExerciseMediaImage({
    required this.exercise,
    this.imageIndex = 0,
    this.fit = BoxFit.contain,
    this.color,
    this.colorBlendMode,
    this.errorIconSize = 52,
    super.key,
  });

  final ExerciseGuide exercise;
  final int imageIndex;
  final BoxFit fit;
  final Color? color;
  final BlendMode? colorBlendMode;
  final double errorIconSize;

  @override
  State<ExerciseMediaImage> createState() => _ExerciseMediaImageState();
}

class _ExerciseMediaImageState extends State<ExerciseMediaImage> {
  static final Map<String, Future<String>> _resolvedUrls = {};
  late Future<String> _url;
  bool _usingSourceFallback = false;

  bool get _hasStorage =>
      widget.imageIndex < widget.exercise.storagePaths.length;
  bool get _hasSource => widget.imageIndex < widget.exercise.imageUrls.length;
  String get _storagePath => _hasStorage
      ? widget.exercise.storagePaths[widget.imageIndex]
      : 'external/${widget.exercise.id}/${widget.imageIndex}';
  String get _cacheKey => '${Firebase.app().options.projectId}::$_storagePath';
  String get _preferenceKey => 'exercise_media_url::$_cacheKey';

  @override
  void initState() {
    super.initState();
    _url = _resolve();
  }

  @override
  void didUpdateWidget(covariant ExerciseMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.id != widget.exercise.id ||
        oldWidget.imageIndex != widget.imageIndex) {
      _usingSourceFallback = false;
      _url = _resolve();
    }
  }

  Future<String> _resolve() {
    final cacheKey = _cacheKey;
    return _resolvedUrls.putIfAbsent(cacheKey, () async {
      if (!_hasStorage) {
        _usingSourceFallback = true;
        return _hasSource ? widget.exercise.imageUrls[widget.imageIndex] : '';
      }
      final preferences = await SharedPreferences.getInstance();
      final cachedUrl = preferences.getString(_preferenceKey);
      if (cachedUrl != null && cachedUrl.isNotEmpty) return cachedUrl;
      try {
        final url = await FirebaseStorage.instance
            .ref(_storagePath)
            .getDownloadURL();
        await preferences.setString(_preferenceKey, url);
        return url;
      } catch (_) {
        _usingSourceFallback = true;
        return _hasSource ? widget.exercise.imageUrls[widget.imageIndex] : '';
      }
    });
  }

  void _retryFromSource() {
    if (_usingSourceFallback || !_hasSource) return;
    _usingSourceFallback = true;
    _resolvedUrls.remove(_cacheKey);
    SharedPreferences.getInstance().then(
      (preferences) => preferences.remove(_preferenceKey),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _url = Future.value(widget.exercise.imageUrls[widget.imageIndex]);
      });
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _url,
    builder: (context, snapshot) {
      final url = snapshot.data;
      if (url == null) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }
      if (url.isEmpty) {
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: Icon(Icons.fitness_center, size: widget.errorIconSize),
          ),
        );
      }
      return CachedNetworkImage(
        imageUrl: url,
        fit: widget.fit,
        color: widget.color,
        colorBlendMode: widget.colorBlendMode,
        placeholder: (_, _) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, _, _) {
          if (!_usingSourceFallback) {
            _retryFromSource();
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          return ColoredBox(
            color: const Color(0x11000000),
            child: Center(
              child: Icon(Icons.fitness_center, size: widget.errorIconSize),
            ),
          );
        },
      );
    },
  );
}
