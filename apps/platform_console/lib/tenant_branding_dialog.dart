import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'platform_gym_repository.dart';

class TenantBrandingDialog extends StatefulWidget {
  const TenantBrandingDialog({required this.document, super.key});

  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  @override
  State<TenantBrandingDialog> createState() => _TenantBrandingDialogState();
}

class _TenantBrandingDialogState extends State<TenantBrandingDialog> {
  late final Map<String, dynamic> gym = widget.document.data();
  late final Map<String, dynamic> branding = Map<String, dynamic>.from(
    gym['branding'] as Map? ?? const {},
  );
  late final name = TextEditingController(text: gym['name'] as String? ?? '');
  late final tagline = TextEditingController(
    text: branding['tagline'] as String? ?? 'Stronger every day',
  );
  late final primary = TextEditingController(
    text: branding['primaryColor'] as String? ?? '#2563EB',
  );
  late final secondary = TextEditingController(
    text: branding['secondaryColor'] as String? ?? '#0F172A',
  );
  late final accent = TextEditingController(
    text: branding['accentColor'] as String? ?? '#F97316',
  );
  late final phone = TextEditingController(text: gym['phone'] as String? ?? '');
  late final city = TextEditingController(text: gym['city'] as String? ?? '');
  late final website = TextEditingController(
    text: gym['website'] as String? ?? '',
  );
  late final currency = TextEditingController(
    text: gym['currency'] as String? ?? 'INR',
  );
  late final timezone = TextEditingController(
    text: gym['timezone'] as String? ?? 'Asia/Kolkata',
  );
  late final locale = TextEditingController(
    text: gym['locale'] as String? ?? 'en-IN',
  );
  late final PlatformGymRepository repository = PlatformGymRepository();
  String? logoUrl;
  bool uploading = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    logoUrl = branding['logoUrl'] as String?;
  }

  @override
  void dispose() {
    for (final controller in [
      name,
      tagline,
      primary,
      secondary,
      accent,
      phone,
      city,
      website,
      currency,
      timezone,
      locale,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Manage gym branding'),
    content: SizedBox(
      width: 680,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BrandPreview(
              name: name.text.isEmpty ? 'Gym name' : name.text,
              tagline: tagline.text,
              logoUrl: logoUrl,
              primary: _parseColor(primary.text, const Color(0xFF2563EB)),
              accent: _parseColor(accent.text, const Color(0xFFF97316)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: uploading ? null : _uploadLogo,
              icon: const Icon(Icons.upload_outlined),
              label: Text(uploading ? 'Uploading logo…' : 'Upload gym logo'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Public gym name'),
            ),
            TextField(
              controller: tagline,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Member tagline'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ColorField(
                  label: 'Primary',
                  controller: primary,
                  onChanged: _refresh,
                ),
                _ColorField(
                  label: 'Secondary',
                  controller: secondary,
                  onChanged: _refresh,
                ),
                _ColorField(
                  label: 'Accent',
                  controller: accent,
                  onChanged: _refresh,
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              'Business profile',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            TextField(
              controller: city,
              decoration: const InputDecoration(labelText: 'City'),
            ),
            TextField(
              controller: website,
              decoration: const InputDecoration(
                labelText: 'Website (https://…)',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _CompactField(label: 'Currency', controller: currency),
                _CompactField(label: 'Timezone', controller: timezone),
                _CompactField(label: 'Locale', controller: locale),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving || uploading ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: saving || uploading ? null : _save,
        icon: const Icon(Icons.save_outlined),
        label: Text(saving ? 'Saving…' : 'Save branding'),
      ),
    ],
  );

  void _refresh(String _) => setState(() {});

  Future<void> _uploadLogo() async {
    setState(() => uploading = true);
    try {
      final next = await repository.pickAndUploadLogo(widget.document.id);
      if (mounted && next != null) setState(() => logoUrl = next);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await repository.updateConfiguration(
        gymId: widget.document.id,
        name: name.text,
        tagline: tagline.text,
        primaryColor: primary.text,
        secondaryColor: secondary.text,
        accentColor: accent.text,
        logoUrl: logoUrl,
        phone: phone.text,
        city: city.text,
        website: website.text,
        currency: currency.text,
        timezone: timezone.text,
        locale: locale.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Unable to save branding: $error')));
}

class _BrandPreview extends StatelessWidget {
  const _BrandPreview({
    required this.name,
    required this.tagline,
    required this.logoUrl,
    required this.primary,
    required this.accent,
  });

  final String name;
  final String tagline;
  final String? logoUrl;
  final Color primary;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [primary, accent]),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox.square(
            dimension: 72,
            child: logoUrl == null
                ? const ColoredBox(
                    color: Colors.white,
                    child: Icon(Icons.fitness_center, size: 36),
                  )
                : Image.network(
                    logoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Colors.white,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(tagline, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ColorField extends StatelessWidget {
  const _ColorField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: '$label #RRGGBB',
        prefixIcon: Padding(
          padding: const EdgeInsets.all(13),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _parseColor(controller.text, Colors.grey),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    ),
  );
}

class _CompactField extends StatelessWidget {
  const _CompactField({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

Color _parseColor(String value, Color fallback) {
  final hex = value.replaceFirst('#', '');
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) return fallback;
  return Color(int.parse('FF$hex', radix: 16));
}
