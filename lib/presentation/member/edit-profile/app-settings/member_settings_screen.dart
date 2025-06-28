import 'package:fit_and_fine/core/widgets/custom_appbar.dart';
import 'package:flutter/material.dart';

class MemberSettingsScreen extends StatelessWidget {
  const MemberSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const CustomAppBar(title: 'App Settings'),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- Notifications Section ---
          _SettingsGroup(
            title: 'Notifications',
            children: [
              SwitchListTile(
                title: const Text('Push Notifications'),
                subtitle: const Text('Receive alerts for classes and updates'),
                value: true, // Placeholder value
                onChanged: (bool value) {
                  // Handle toggle logic
                },
                secondary: const Icon(Icons.notifications_active_outlined),
              ),
              SwitchListTile(
                title: const Text('Email Notifications'),
                subtitle: const Text('Get newsletters and promotional offers'),
                value: false, // Placeholder value
                onChanged: (bool value) {
                  // Handle toggle logic
                },
                secondary: const Icon(Icons.email_outlined),
              ),
            ],
          ),
          const Divider(height: 32),

          // --- Legal & Privacy Section ---
          _SettingsGroup(
            title: 'Legal & Privacy',
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  /* Navigate to Privacy Policy screen/URL */
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  /* Navigate to Terms of Service screen/URL */
                },
              ),
            ],
          ),
          const Divider(height: 32),

          // --- Help & Support Section ---
          _SettingsGroup(
            title: 'Help & Support',
            children: [
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help Center'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  /* Navigate to Help Center */
                },
              ),
              ListTile(
                leading: const Icon(Icons.feedback_outlined),
                title: const Text('Contact Us & Feedback'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  /* Navigate to Contact Us screen */
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// A helper widget to group related settings together with a title.
class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          child: Column(children: children),
        ),
      ],
    );
  }
}
