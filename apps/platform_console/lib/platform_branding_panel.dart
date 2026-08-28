import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'platform_gym_repository.dart';

class PlatformBrandingPanel extends StatefulWidget {
  const PlatformBrandingPanel({super.key});

  @override
  State<PlatformBrandingPanel> createState() => _PlatformBrandingPanelState();
}

class _PlatformBrandingPanelState extends State<PlatformBrandingPanel> {
  final repository = PlatformGymRepository();
  final name = TextEditingController(text: 'Gym Management');
  final logo = TextEditingController();
  final primary = TextEditingController(text: '#2563EB');
  final secondary = TextEditingController(text: '#0F172A');
  final accent = TextEditingController(text: '#F97316');
  final terms = TextEditingController(text: 'https://example.com/terms');
  final privacy = TextEditingController(text: 'https://example.com/privacy');
  final titles = [
    TextEditingController(text: 'Build workouts around your goals'),
    TextEditingController(text: 'Log every set and understand your progress'),
    TextEditingController(text: 'Connect with your gym whenever you choose'),
  ];
  final bodies = [
    TextEditingController(text: 'Create routines that fit your life.'),
    TextEditingController(text: 'See consistent progress over time.'),
    TextEditingController(text: 'Add gym services without losing control.'),
  ];
  final introImages = List.generate(3, (_) => TextEditingController());
  bool personalSpaces = true;
  bool initialized = false;
  bool saving = false;
  String? uploadingSlot;
  double uploadProgress = 0;
  String uploadStage = 'Choose an image…';
  final pendingUploads = <String>{};
  final savedUploads = <String>{};

  bool get busy => saving || uploadingSlot != null;

  @override
  void dispose() {
    for (final controller in [
      name,
      logo,
      primary,
      secondary,
      accent,
      terms,
      privacy,
      ...titles,
      ...bodies,
      ...introImages,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .doc('platform_public/app_branding')
            .snapshots(),
        builder: (context, snapshot) {
          if (!initialized && snapshot.hasData) {
            initialized = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _load(snapshot.data!.data() ?? const {}),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _field(name, 'Product name'),
                      SizedBox(
                        width: 330,
                        child: _imageField(
                          controller: logo,
                          label: 'Platform logo URL',
                          slot: 'logo',
                          uploadLabel: 'Upload logo',
                          onUpload: _uploadLogo,
                        ),
                      ),
                      _field(primary, 'Primary color'),
                      _field(secondary, 'Secondary color'),
                      _field(accent, 'Accent color'),
                      _field(terms, 'Terms URL'),
                      _field(privacy, 'Privacy URL'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Introduction screens',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              for (var index = 0; index < 3; index++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Screen ${index + 1}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: titles[index],
                          decoration: const InputDecoration(labelText: 'Title'),
                        ),
                        const SizedBox(height: 10),
                        _imageField(
                          controller: introImages[index],
                          label: 'Image URL (optional)',
                          slot: 'intro-$index',
                          uploadLabel: 'Upload screen ${index + 1} image',
                          onUpload: () => _uploadIntro(index),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: bodies[index],
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Supporting copy',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SwitchListTile(
                value: personalSpaces,
                onChanged: (value) => setState(() => personalSpaces = value),
                title: const Text('Personal fitness spaces V1'),
                subtitle: const Text(
                  'Remote rollout switch for the consumer-first experience',
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: busy ? null : _save,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    saving ? 'Saving changes…' : 'Save public branding',
                  ),
                ),
              ),
            ],
          );
        },
      );

  Widget _field(TextEditingController controller, String label) => SizedBox(
    width: 330,
    child: TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _imageField({
    required TextEditingController controller,
    required String label,
    required String slot,
    required String uploadLabel,
    required VoidCallback onUpload,
  }) {
    final isUploading = uploadingSlot == slot;
    final value = controller.text.trim();
    final hasPreview = value.isNotEmpty && _isWebUrl(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isUploading,
                decoration: InputDecoration(
                  labelText: label,
                  helperText: 'Upload an image or paste an HTTPS URL',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: uploadLabel,
              onPressed: busy ? null : onUpload,
              icon: isUploading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
            ),
          ],
        ),
        if (isUploading) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: uploadProgress > 0 ? uploadProgress : null,
          ),
          const SizedBox(height: 6),
          Text(
            uploadProgress > 0
                ? 'Uploading… ${(uploadProgress * 100).round()}%'
                : uploadStage,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ] else if (pendingUploads.contains(slot)) ...[
          const SizedBox(height: 8),
          _uploadStatus(
            Icons.cloud_done_outlined,
            'Uploaded. Save public branding to publish it.',
            Theme.of(context).colorScheme.primary,
          ),
        ] else if (savedUploads.contains(slot)) ...[
          const SizedBox(height: 8),
          _uploadStatus(
            Icons.check_circle_outline,
            'Uploaded and published.',
            Colors.green,
          ),
        ],
        if (hasPreview) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: SizedBox(
                height: 92,
                child: Image.network(
                  value,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined),
                        SizedBox(width: 8),
                        Text('Preview unavailable'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _uploadStatus(IconData icon, String message, Color color) => Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ),
    ],
  );

  void _load(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      name.text = data['name'] as String? ?? name.text;
      logo.text = data['logoUrl'] as String? ?? '';
      primary.text = data['primaryColor'] as String? ?? primary.text;
      secondary.text = data['secondaryColor'] as String? ?? secondary.text;
      accent.text = data['accentColor'] as String? ?? accent.text;
      terms.text = data['termsUrl'] as String? ?? terms.text;
      privacy.text = data['privacyUrl'] as String? ?? privacy.text;
      final intro = data['introduction'] as List? ?? const [];
      for (var index = 0; index < intro.length && index < 3; index++) {
        final item = Map<String, dynamic>.from(intro[index] as Map);
        titles[index].text = item['title'] as String? ?? titles[index].text;
        bodies[index].text = item['body'] as String? ?? bodies[index].text;
        introImages[index].text = item['imageUrl'] as String? ?? '';
      }
      final features = Map<String, dynamic>.from(
        data['consumerFeatures'] as Map? ?? const {},
      );
      personalSpaces = features['personalSpacesV1'] as bool? ?? true;
    });
  }

  Future<void> _save() async {
    final logoValue = logo.text.trim();
    if (logoValue.isNotEmpty && !_isWebUrl(logoValue)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Platform logo must be uploaded or provided as an HTTPS URL.',
          ),
        ),
      );
      return;
    }
    for (var index = 0; index < introImages.length; index++) {
      final imageValue = introImages[index].text.trim();
      if (imageValue.isNotEmpty && !_isWebUrl(imageValue)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Screen ${index + 1} image must be uploaded or provided as an HTTPS URL.',
            ),
          ),
        );
        return;
      }
    }
    setState(() => saving = true);
    try {
      await repository.updatePlatformBranding({
        'name': name.text.trim(),
        'logoUrl': logoValue.isEmpty ? null : logoValue,
        'primaryColor': primary.text.trim(),
        'secondaryColor': secondary.text.trim(),
        'accentColor': accent.text.trim(),
        'termsUrl': terms.text.trim(),
        'privacyUrl': privacy.text.trim(),
        'introduction': List.generate(
          3,
          (index) => {
            'title': titles[index].text.trim(),
            'body': bodies[index].text.trim(),
            'imageUrl': introImages[index].text.trim().isEmpty
                ? null
                : introImages[index].text.trim(),
          },
        ),
        'consumerFeatures': {'personalSpacesV1': personalSpaces},
      });
      if (mounted) {
        setState(() {
          savedUploads
            ..clear()
            ..addAll(pendingUploads);
          pendingUploads.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Platform branding saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to save branding: ${_message(error)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  bool _isWebUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  Future<void> _uploadLogo() async {
    await _upload(
      slot: 'logo',
      area: 'branding',
      controller: logo,
      errorLabel: 'logo',
    );
  }

  Future<void> _uploadIntro(int index) async {
    await _upload(
      slot: 'intro-$index',
      area: 'onboarding',
      controller: introImages[index],
      errorLabel: 'screen ${index + 1} image',
    );
  }

  Future<void> _upload({
    required String slot,
    required String area,
    required TextEditingController controller,
    required String errorLabel,
  }) async {
    setState(() {
      uploadingSlot = slot;
      uploadProgress = 0;
      uploadStage = 'Choose an image…';
      pendingUploads.remove(slot);
      savedUploads.remove(slot);
    });
    try {
      final url = await repository.pickAndUploadPlatformImage(
        area: area,
        onProgress: (progress) {
          if (mounted && uploadingSlot == slot) {
            setState(() => uploadProgress = progress);
          }
        },
        onStage: (stage) {
          if (mounted && uploadingSlot == slot) {
            setState(() => uploadStage = stage);
          }
        },
      );
      if (url != null && mounted) {
        setState(() {
          controller.text = url;
          pendingUploads.add(slot);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_capitalize(errorLabel)} uploaded. Save public branding to publish it.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to upload $errorLabel: ${_message(error)}'),
          ),
        );
      }
    } finally {
      if (mounted && uploadingSlot == slot) {
        setState(() {
          uploadingSlot = null;
          uploadProgress = 0;
          uploadStage = 'Choose an image…';
        });
      }
    }
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  String _message(Object error) {
    if (error is TimeoutException) return error.message ?? 'Request timed out.';
    if (error is FirebaseFunctionsException) {
      return error.message ??
          'The server rejected the request (${error.code}).';
    }
    if (error is FirebaseException) {
      return error.message ?? 'Firebase request failed (${error.code}).';
    }
    return error.toString();
  }
}
