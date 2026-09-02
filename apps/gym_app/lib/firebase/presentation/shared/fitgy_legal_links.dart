import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const fitGyPublicBaseUrl = 'https://createmix-gym-app.web.app';
const fitGyPrivacyUrl = '$fitGyPublicBaseUrl/privacy/';
const fitGyTermsUrl = '$fitGyPublicBaseUrl/terms/';

class FitGyLegalLinks extends StatelessWidget {
  const FitGyLegalLinks({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        leading: const Icon(Icons.privacy_tip_outlined),
        title: const Text('Privacy Policy'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _open(context, '/privacy/'),
      ),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.description_outlined),
        title: const Text('Terms of Service'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _open(context, '/terms/'),
      ),
    ],
  );

  Future<void> _open(BuildContext context, String path) async {
    final opened = await launchUrl(
      Uri.parse('$fitGyPublicBaseUrl$path'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this policy page.')),
      );
    }
  }
}
