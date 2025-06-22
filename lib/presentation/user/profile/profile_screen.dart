import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:getwidget/getwidget.dart';
import '../../../logic/user/profile/profile_bloc.dart';
import '../../../logic/user/profile/profile_state.dart';
import '../../../theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        if (state is ProfileLoading || state is ProfileInitial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (state is ProfileLoaded) {
          final user = state.user;
          final String name = user.name;
          final String bio = user.bio ?? '';
          final String target = user.bio ?? '';
          final double heightCm = (user.height ?? 0).toDouble();
          final double weightKg = (user.weight ?? 0).toDouble();
          final int age = user.age ?? 0;
          final String avatarUrl = user.avatarUrl ?? '';

          double heightM = heightCm / 100;
          double bmi = (heightM > 0) ? weightKg / (heightM * heightM) : 0;

          String bmiCategory;
          if (bmi < 18.5) {
            bmiCategory = 'Underweight';
          } else if (bmi < 25) {
            bmiCategory = 'Normal';
          } else if (bmi < 30) {
            bmiCategory = 'Overweight';
          } else {
            bmiCategory = 'Obese';
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text('Profile'),
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
              elevation: Theme.of(context).appBarTheme.elevation,
              titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle,
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(30),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: Theme.of(context).cardColor,
                          backgroundImage: avatarUrl.isNotEmpty ? AssetImage(avatarUrl) : null,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/edit-profile');
                            },
                            child: avatarUrl.isEmpty
                                ? Icon(Icons.person, size: 50, color: Theme.of(context).colorScheme.secondary)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bio,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 10),
                        GFButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/edit-profile');
                          },
                          text: "Edit Profile",
                          color: Theme.of(context).colorScheme.secondary,
                          textColor: Theme.of(context).colorScheme.onSecondary,
                          shape: GFButtonShape.pills,
                          size: GFSize.SMALL,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Card(
                      elevation: 3,
                      color: Theme.of(context).cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 18,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _profileStat(
                                  'Height',
                                  '${heightCm.toStringAsFixed(0)} cm',
                                  Icons.height,
                                ),
                                _profileStat(
                                  'Weight',
                                  '${weightKg.toStringAsFixed(1)} kg',
                                  Icons.monitor_weight,
                                ),
                                _profileStat('Age', '$age', Icons.cake),
                              ],
                            ),
                            const Divider(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _profileStat('Target', target, Icons.flag),
                                _profileStat(
                                  'BMI',
                                  bmi.toStringAsFixed(1),
                                  Icons.fitness_center,
                                ),
                                _profileStat(
                                  'Category',
                                  bmiCategory,
                                  Icons.info_outline,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: GFButton(
                      onPressed: () {},
                      text: "View Progress",
                      color: Theme.of(context).colorScheme.onSecondary,
                      fullWidthButton: true,
                      size: GFSize.LARGE,
                      shape: GFButtonShape.pills,
                      icon: Icon(
                        Icons.show_chart,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (state is ProfileError) {
          return Scaffold(
            body: Center(child: Text(state.message)),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }
}

Widget _profileStat(String label, String value, IconData icon) {
  return Column(
    children: [
      Icon(icon, color: Colors.deepPurple, size: 28),
      const SizedBox(height: 6),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
    ],
  );
}
