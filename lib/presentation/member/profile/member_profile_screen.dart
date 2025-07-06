// lib/presentation/member/profile/profile_screen.dart

import 'package:fit_and_fine/data/datasources/profile_data_source.dart';
import 'package:fit_and_fine/data/models/member_profile_model.dart';
import 'package:fit_and_fine/data/repositories/profile_repository.dart';
import 'package:fit_and_fine/logic/auth/auth_bloc.dart';
import 'package:fit_and_fine/logic/auth/auth_event.dart';
import 'package:fit_and_fine/logic/member/profile/profile_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// This is the entry point for your profile tab
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileBloc(
        profileRepository: ProfileRepository(dataSource: ProfileDataSource()),
        authBloc: BlocProvider.of<AuthBloc>(context),
      )..add(FetchProfileData()),
      child: const MemberProfileScreen(),
    );
  }
}

class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        if (state is ProfileLoading || state is ProfileInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ProfileError) {
          return Center(child: Text(state.message));
        }
        if (state is ProfileLoaded) {
          // The entire UI is now driven by the composite 'profileData' object
          final profileData = state.profileData;
          return Scaffold(
            body: RefreshIndicator(
              onRefresh: () async {
                context.read<ProfileBloc>().add(FetchProfileData());
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 20.0,
                ),
                children: [
                  _ProfileHeader(personalInfo: profileData.personalInfo),
                  const SizedBox(height: 32),
                  _PersonalInfoSection(personalInfo: profileData.personalInfo),
                  const SizedBox(height: 16),
                  _FitnessGoalsSection(fitnessInfo: profileData.fitnessInfo),
                  const SizedBox(height: 16),
                  _PreferencesSection(fitnessInfo: profileData.fitnessInfo),
                  const SizedBox(height: 16),
                  _PaymentsSection(paymentInfo: profileData.paymentInfo),
                  const SizedBox(height: 16),
                  _AppSettingsSection(),
                  const SizedBox(height: 32),
                  _LogoutButton(),
                ],
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// --- Each Section Widget now takes its own specific data model ---

class _ProfileHeader extends StatelessWidget {
  final PersonalInfo personalInfo;
  const _ProfileHeader({required this.personalInfo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: theme.colorScheme.secondaryContainer,
          backgroundImage: personalInfo.avatarUrl != null
              ? AssetImage(personalInfo.avatarUrl!)
              : null,
          child: personalInfo.avatarUrl == null
              ? Icon(
                  Icons.person,
                  size: 50,
                  color: theme.colorScheme.onSecondaryContainer,
                )
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          personalInfo.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Member since ${personalInfo.memberSince ?? "2024"}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PersonalInfoSection extends StatelessWidget {
  final PersonalInfo personalInfo;
  const _PersonalInfoSection({required this.personalInfo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            await context.push('/member/edit-personal-info');
            if (context.mounted) {
              context.read<ProfileBloc>().add(FetchProfileData());
              debugPrint('Personal Info Updated');
            }
          },
          child: const _SectionHeader(title: 'Personal Information'),
        ),
        _ProfileListItem(label: 'Email', value: personalInfo.email),
        _ProfileListItem(
          label: 'Phone Number',
          value: personalInfo.phone?.toString() ?? "Not set",
        ),
        _ProfileListItem(
          label: 'Gender',
          value: personalInfo.gender?.name ?? 'Not set',
        ),
        _ProfileListItem(
          label: 'Date of Birth',
          value: personalInfo.dob != null
              ? DateFormat.yMMMd().format(personalInfo.dob!)
              : 'Not set',
        ),
      ],
    );
  }
}

class _FitnessGoalsSection extends StatelessWidget {
  final FitnessInfo fitnessInfo;
  const _FitnessGoalsSection({required this.fitnessInfo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            await context.push('/member/fitness-goals');
            if (context.mounted) {
              context.read<ProfileBloc>().add(FetchProfileData());
            }
          },
          child: const _SectionHeader(title: 'Fitness Goals'),
        ),
        _ProfileListItem(
          label: 'Primary Goal',
          value: fitnessInfo.healthGoals ?? 'Not set',
        ),
        _ProfileListItem(
          label: 'Workout Frequency',
          value: fitnessInfo.workoutFrequency ?? 'Not set',
        ),
      ],
    );
  }
}

class _PreferencesSection extends StatelessWidget {
  final FitnessInfo fitnessInfo;
  const _PreferencesSection({required this.fitnessInfo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            /* Navigate to edit preferences screen */
          },
          child: const _SectionHeader(title: 'Preferences'),
        ),
        _ProfileListItem(
          label: 'Preferred Workouts',
          value: fitnessInfo.preferredWorkouts.join(', '),
        ),
        _ProfileListItem(
          label: 'Preferred Workout Time',
          value: fitnessInfo.preferredWorkoutTime ?? 'Not set',
        ),
      ],
    );
  }
}

class _PaymentsSection extends StatelessWidget {
  final PaymentInfo paymentInfo;
  const _PaymentsSection({required this.paymentInfo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => context.push('/member/payments'),
          child: const _SectionHeader(title: 'Payments & Subscriptions'),
        ),
        _ProfileListItem(
          label: 'Subscription Status',
          value: paymentInfo.subscriptionStatus,
        ),
        _ProfileListItem(
          label: 'Payment Method',
          value: paymentInfo.paymentMethod,
        ),
      ],
    );
  }
}

// A reusable widget for section headers.
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Icon(Icons.edit, size: 16, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _AppSettingsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => context.push('/member/settings'),
          child: const _SectionHeader(title: 'App Settings'),
        ),
        _ProfileListItem(label: 'Notifications', value: ''),
        _ProfileListItem(label: 'Privacy Settings', value: ''),
        _ProfileListItem(label: 'Help & Support', value: ''),
      ],
    );
  }
}

// A generic display item.
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
          // const Spacer(),
          // Icon(
          //   Icons.arrow_forward_ios,
          //   size: 16,
          //   color: theme.colorScheme.onSurfaceVariant,
          // ),
        ],
      ),
    );
  }
}

// The logout button
class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
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
