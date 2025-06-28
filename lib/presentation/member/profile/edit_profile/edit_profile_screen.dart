import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:getwidget/getwidget.dart';
import '../../../../logic/auth/auth_bloc.dart';
import '../../../../logic/auth/auth_state.dart';
import '../../../../logic/member/profile/profile_bloc.dart';
import '../../../../logic/member/profile/profile_event.dart';
import '../../../../logic/member/profile/profile_state.dart';
import '../../../../core/theme/theme.dart';

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

  @override
  void initState() {
    super.initState();
    // Use ProfileBloc for profile data
    final profileState = context.read<ProfileBloc>().state;
    if (profileState is ProfileLoaded) {
      final user = profileState.user;
      _nameController.text = user.name;
      _emailController.text = user.email;
      _profileImage = user.avatarUrl ?? _profileImage;
      _heightController.text = user.height?.toString() ?? '';
      _weightController.text = user.weight?.toString() ?? '';
      _ageController.text = user.age?.toString() ?? '';
      _targetController.text = user.bio ?? '';
    }
  }

  void _updateProfile() {
    final update = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'avatarUrl': _profileImage,
      'height': int.tryParse(_heightController.text),
      'weight': int.tryParse(_weightController.text),
      'age': int.tryParse(_ageController.text),
      'bio': _targetController.text.trim(),
    };
    context.read<ProfileBloc>().add(UpdateProfile(update));
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
    return BlocListener<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileLoaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated!')),
          );
          Navigator.pop(context);
        } else if (state is ProfileError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
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
      ),
    );
  }
}
