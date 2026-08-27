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
      _url = _resolve();
    }
  }

  Future<String> _resolve() {
    final storagePath = widget.exercise.storagePaths[widget.imageIndex];
    final projectId = Firebase.app().options.projectId;
    final cacheKey = '$projectId::$storagePath';
    return _resolvedUrls.putIfAbsent(cacheKey, () async {
      final preferences = await SharedPreferences.getInstance();
      final preferenceKey = 'exercise_media_url::$cacheKey';
      final cachedUrl = preferences.getString(preferenceKey);
      if (cachedUrl != null && cachedUrl.isNotEmpty) return cachedUrl;
      try {
        final url = await FirebaseStorage.instance
            .ref(storagePath)
            .getDownloadURL();
        await preferences.setString(preferenceKey, url);
        return url;
      } catch (_) {
        return widget.exercise.imageUrls[widget.imageIndex];
      }
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
      return CachedNetworkImage(
        imageUrl: url,
        fit: widget.fit,
        color: widget.color,
        colorBlendMode: widget.colorBlendMode,
        placeholder: (_, _) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, _, _) => ColoredBox(
          color: const Color(0x11000000),
          child: Center(
            child: Icon(Icons.fitness_center, size: widget.errorIconSize),
          ),
        ),
      );
    },
  );
}
