import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import '../theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Beautifully designed profile screen name, bio, target, profile picture, height, weight, and age. Also auto calculate BMI and display it.
    // Sample user data
    final String name = 'John Doe';
    final String bio = 'Fitness Enthusiast | Gym Lover';
    final String target = 'Lose 5kg in 2 months';
    final double heightCm = 175;
    final double weightKg = 70;
    final int age = 28;

    // BMI Calculation
    double heightM = heightCm / 100;
    double bmi = weightKg / (heightM * heightM);

    // BMI Category
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
                    child: GestureDetector(
                      onTap: () {
                        // Navigate to profile edit screen
                        Navigator.pushNamed(context, '/edit-profile');
                      },
                      child: GFAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(
                          "https://cdn.pixabay.com/photo/2017/12/03/18/04/christmas-balls-2995437_960_720.jpg",
                        ),
                      ),
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
