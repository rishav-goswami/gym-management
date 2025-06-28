import 'package:fit_and_fine/data/models/user_model.dart';
import 'package:fit_and_fine/logic/auth/auth_bloc.dart';
import 'package:fit_and_fine/logic/auth/auth_event.dart';
import 'package:fit_and_fine/logic/auth/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = state.user as Member;

        // The main build method is now very clean and readable.
        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 20.0,
            ),
            children: [
              _ProfileHeader(user: user),
              const SizedBox(height: 32),

              _PersonalInfoSection(user: user),
              const SizedBox(height: 16),

              _FitnessGoalsSection(user: user),
              const SizedBox(height: 16),

              _PreferencesSection(),
              const SizedBox(height: 16),

              _PaymentsSection(),
              const SizedBox(height: 16),

              _AppSettingsSection(),
              const SizedBox(height: 32),

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
    final theme = Theme.of(context);
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: theme.colorScheme.secondaryContainer,
          backgroundImage: (user as Member).avatarUrl != null
              ? AssetImage((user as Member).avatarUrl ?? "")
              : null,
          child: (user as Member).avatarUrl == null
              ? Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                )
              : null,
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
          'Member since ${user.createdAt?.year ?? "2024"}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// Each section is now a reusable and tappable widget.
class _PersonalInfoSection extends StatelessWidget {
  final Member user;
  const _PersonalInfoSection({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Personal Information'),
        _TappableSectionCard(
          onTap: () => context.push('/member/edit-personal-info'),
          children: [
            _ProfileListItem(label: 'Email', value: user.email),
            _ProfileListItem(
              label: 'Phone Number',
              value: user.phone ?? "Not set",
            ),
            _ProfileListItem(
              label: 'Gender',
              value: user.gender?.name ?? 'Not set',
            ),
            _ProfileListItem(
              label: 'Date of Birth',
              // Assuming 'dateOfBirth' would be added to your Member model
              value: user.dob?.toIso8601String() ?? 'Not set', // Placeholder
            ),
          ],
        ),
      ],
    );
  }
}

class _FitnessGoalsSection extends StatelessWidget {
  final User user;
  const _FitnessGoalsSection({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Fitness Goals'),
        _TappableSectionCard(
          onTap: () => context.push('/member/fitness-goals'),
          children: [
            _ProfileListItem(
              label: 'Primary Goal',
              value: (user as Member).healthGoals ?? 'Weight Loss',
            ),
            _ProfileListItem(
              label: 'Workout Frequency',
              value: '3-4 times a week',
            ),
          ],
        ),
      ],
    );
  }
}

class _PreferencesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Preferences'),
        _TappableSectionCard(
          onTap: () {
            /* Navigate to edit preferences screen */
          },
          children: [
            _ProfileListItem(
              label: 'Preferred Workouts',
              value: 'Cardio, Strength Training',
            ),
            _ProfileListItem(label: 'Preferred Workout Time', value: 'Morning'),
          ],
        ),
      ],
    );
  }
}

class _PaymentsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Payments & Subscriptions'),
        _TappableSectionCard(
          onTap: () => context.push('/member/payments'),
          children: [
            _ProfileListItem(label: 'Subscription Status', value: 'Active'),
            _ProfileListItem(label: 'Payment Method', value: 'Visa **** 1234'),
          ],
        ),
      ],
    );
  }
}

class _AppSettingsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'App Settings'),
        _TappableSectionCard(
          onTap: () => context.push('/member/settings'),
          children: [
            _ProfileListItem(label: 'Notifications', value: ''),
            _ProfileListItem(label: 'Privacy Settings', value: ''),
            _ProfileListItem(label: 'Help & Support', value: ''),
          ],
        ),
      ],
    );
  }
}

// A generic display item. It no longer needs an onTap property.
class _ProfileListItem extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileListItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
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
    );
  }
}

// A reusable card that makes its children tappable as a group.
class _TappableSectionCard extends StatelessWidget {
  final VoidCallback onTap;
  final List<Widget> children;

  const _TappableSectionCard({required this.onTap, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      clipBehavior: Clip
          .antiAlias, // Ensures the InkWell ripple effect is clipped to the card's shape
      child: InkWell(
        onTap: onTap,
        child: Column(children: children),
      ),
    );
  }
}

// The logout button
class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          context.read<AuthBloc>().add(AuthLogoutRequested());
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.surfaceVariant,
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
