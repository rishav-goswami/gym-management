import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import '../theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController(text: 'John Doe');
  final _emailController = TextEditingController(text: 'john@example.com');
  final TextEditingController _heightController = TextEditingController(text: '175');
  final TextEditingController _weightController = TextEditingController(text: '70');
  final TextEditingController _ageController = TextEditingController(text: '28');
  final TextEditingController _targetController = TextEditingController(text: 'Lose 5kg in 2 months');
  String _profileImage = 'assets/avatars/avatar1.png';

  final List<String> _avatarOptions = [
    'assets/avatars/avatar1.png',
    'assets/avatars/avatar2.png',
    'assets/avatars/avatar3.png',
    'assets/avatars/avatar4.png',
    'assets/avatars/avatar5.png',
  ];

  void _updateProfile() {
    debugPrint("Updated name: \\${_nameController.text}");
    debugPrint("Updated email: \\${_emailController.text}");
    debugPrint("Avatar: \\${_profileImage}");
    debugPrint("Height: \\${_heightController.text}");
    debugPrint("Weight: \\${_weightController.text}");
    debugPrint("Age: \\${_ageController.text}");
    debugPrint("Target: \\${_targetController.text}");
    Navigator.pop(context);
  }

  void _showAvatarPicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose Avatar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _avatarOptions.map((avatar) => GestureDetector(
                onTap: () {
                  setState(() {
                    _profileImage = avatar;
                  });
                  Navigator.pop(context);
                },
                child: CircleAvatar(
                  radius: 32,
                  backgroundImage: AssetImage(avatar),
                  backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                  child: _profileImage == avatar
                    ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 28)
                    : null,
                ),
              )).toList(),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: Theme.of(context).appBarTheme.elevation,
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          color: Theme.of(context).cardColor,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _showAvatarPicker,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        backgroundImage: AssetImage(_profileImage),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.edit, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person, color: Theme.of(context).colorScheme.secondary),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email, color: Theme.of(context).colorScheme.secondary),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _heightController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Height (cm)',
                          prefixIcon: Icon(Icons.height, color: Theme.of(context).colorScheme.secondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Weight (kg)',
                          prefixIcon: Icon(Icons.monitor_weight, color: Theme.of(context).colorScheme.secondary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Age',
                          prefixIcon: Icon(Icons.cake, color: Theme.of(context).colorScheme.secondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _targetController,
                        decoration: InputDecoration(
                          labelText: 'Target',
                          prefixIcon: Icon(Icons.flag, color: Theme.of(context).colorScheme.secondary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GFButton(
                  onPressed: _updateProfile,
                  text: 'Save Changes',
                  color: Theme.of(context).colorScheme.secondary,
                  textColor: Theme.of(context).colorScheme.onSecondary,
                  shape: GFButtonShape.pills,
                  fullWidthButton: true,
                  size: GFSize.LARGE,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
