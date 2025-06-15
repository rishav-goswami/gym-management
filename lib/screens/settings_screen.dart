import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: Theme.of(context).appBarTheme.elevation,
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(
              Icons.dark_mode,
              color: Theme.of(context).colorScheme.secondary,
            ),
            title: Text(
              'Dark Mode',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            trailing: Switch(
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (val) {
                // This is a placeholder. In a real app, use a state management solution.
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Theme Change'),
                    content: const Text(
                      'Theme change is handled by system settings.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.fitness_center,
              color: Theme.of(context).colorScheme.secondary,
            ),
            title: Text(
              'Workout Reminders',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            trailing: GFButton(
              onPressed: () {},
              text: 'Set',
              size: GFSize.SMALL,
              color: Theme.of(context).colorScheme.secondary,
              textColor: Theme.of(context).colorScheme.onSecondary,
              shape: GFButtonShape.pills,
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.notifications,
              color: Theme.of(context).colorScheme.secondary,
            ),
            title: Text(
              'Push Notifications',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            trailing: Switch(value: true, onChanged: (val) {}),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.secondary,
            ),
            title: Text(
              'About Gym App',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Fit & Fine',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2025 Fit & Fine',
              );
            },
          ),
        ],
      ),
    );
  }
}
