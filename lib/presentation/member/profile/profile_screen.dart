import 'package:fit_and_fine/data/models/user_model.dart';
import 'package:fit_and_fine/logic/auth/auth_bloc.dart';
import 'package:fit_and_fine/logic/auth/auth_event.dart';
import 'package:fit_and_fine/logic/auth/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
// import 'package:intl/intl.dart'; // For formatting the date

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // This BlocBuilder rebuilds the UI whenever the auth state changes.
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        // Show a loading indicator or empty state if not authenticated.
        if (state is! AuthAuthenticated) {
          return const Center(child: CircularProgressIndicator());
        }

        // We are sure the user is authenticated, so we can access their data.
        final user = state.user;

        // The main UI for the profile screen.
        return Scaffold(
          // The AppBar will be handled by the parent DashboardScreen.
          body: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 20.0,
            ),
            children: [
              // --- Profile Header ---
              _ProfileHeader(user: user),
              const SizedBox(height: 32),

              // --- Personal Information Section ---
              const _SectionHeader(title: 'Personal Information'),
              _ProfileListItem(
                label: 'Email',
                value: user.email,
                onTap: () {
                  /* Navigate to edit email screen */
                  context.push('/member/edit-profile');
                },
              ),
              // Assuming 'phone' and 'dateOfBirth' would be added to your Member model
              _ProfileListItem(
                label: 'Phone Number',
                value: '(555) 123 - 4567', // Placeholder
                onTap: () {
                  /* Navigate to edit phone screen */
                },
              ),
              if (user is Member) ...[
                _ProfileListItem(
                  label: 'Gender',
                  value: user.gender?.name ?? 'Not set',
                  onTap: () {
                    /* Navigate to edit gender screen */
                  },
                ),
                _ProfileListItem(
                  label: 'Date of Birth',
                  // Assuming 'dateOfBirth' would be added to your Member model
                  value: '1990-05-15', // Placeholder
                  onTap: () {
                    /* Navigate to edit dob screen */
                  },
                ),
              ],
              const SizedBox(height: 24),

              // --- Fitness Goals Section ---
              if (user is Member) ...[
                const _SectionHeader(title: 'Fitness Goals'),
                _ProfileListItem(
                  label: 'Primary Goal',
                  value: user.healthGoals ?? 'Weight Loss', // Using placeholder
                  onTap: () {
                    /* Navigate to edit goals screen */
                    context.push('/member/fitness-goals');
                  },
                ),
                _ProfileListItem(
                  label: 'Workout Frequency',
                  value: '3-4 times a week', // Placeholder
                  onTap: () {
                    /* Navigate to edit frequency screen */
                  },
                ),
              ],
              const SizedBox(height: 24),

              // --- Preferences Section ---
              const _SectionHeader(title: 'Preferences'),
              _ProfileListItem(
                label: 'Preferred Workouts',
                value: 'Cardio, Strength Training', // Placeholder
                onTap: () {
                  /* Navigate to edit preferences */
                },
              ),
              _ProfileListItem(
                label: 'Preferred Workout Time',
                value: 'Morning', // Placeholder
                onTap: () {
                  /* Navigate to edit preferences */
                },
              ),
              const SizedBox(height: 24),

              // --- Payments & Subscriptions Section ---
              const _SectionHeader(title: 'Payments & Subscriptions'),

              _ProfileListItem(
                label: 'Subscription Status',
                value: 'Active', // Placeholder
                onTap: () {
                  /* Navigate to manage subscription */
                  context.push('/member/payments');
                },
              ),
              _ProfileListItem(
                label: 'Payment Method',
                value: 'Visa **** 1234', // Placeholder
                onTap: () {
                  /* Navigate to manage payment */
                },
              ),
              const SizedBox(height: 24),

              // --- App Settings Section ---
              const _SectionHeader(title: 'App Settings'),
              _ProfileListItem(
                label: 'Notifications',
                value: '',
                onTap: () {
                  context.push("/member/settings");
                },
              ),
              _ProfileListItem(
                label: 'Privacy Settings',
                value: '',
                onTap: () {},
              ),
              _ProfileListItem(
                label: 'Help & Support',
                value: '',
                onTap: () {},
              ),
              const SizedBox(height: 32),

              // --- Logout Button ---
              _LogoutButton(),
            ],
          ),
        );
      },
    );
  }
}

// A reusable widget for section headers.
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    // Using theme for text style
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

// The header part with the user's avatar and name.
class _ProfileHeader extends StatelessWidget {
  final User user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    // Using theme for colors and text styles
    final theme = Theme.of(context);
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: theme.colorScheme.secondaryContainer,
          // You can use a NetworkImage here if you have an avatarUrl
          // Assuming user.avatarUrl is a field in your model
          // backgroundImage: (user as Member).avatarUrl != null ? NetworkImage((user as Member).avatarUrl!) : null,
          child: Icon(
            Icons.person,
            size: 50,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          // Assuming user model will have 'joinDate' or similar
          'Member since ${user.createdAt?.year ?? "2024"}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// A reusable widget for each item in the profile list.
class _ProfileListItem extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ProfileListItem({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Using theme for colors and text styles
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyLarge),
                if (value.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// The logout button at the bottom.
class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Using theme for button styling
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          // Dispatch the logout event to the AuthBloc.
          context.read<AuthBloc>().add(AuthLogoutRequested());
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: theme
              .colorScheme
              .surfaceVariant, // Changed from errorContainer for a softer look
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text(
          'Logout',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
