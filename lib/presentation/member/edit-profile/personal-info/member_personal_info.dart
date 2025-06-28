import 'package:fit_and_fine/core/widgets/custom_appbar.dart';
import 'package:fit_and_fine/data/models/user_model.dart';
import 'package:fit_and_fine/logic/auth/auth_bloc.dart';
import 'package:fit_and_fine/logic/auth/auth_state.dart';
// Assuming you will create a ProfileBloc based on your example
// import 'package:fit_and_fine/logic/member/profile/profile_bloc.dart';
// import 'package:fit_and_fine/logic/member/profile/profile_event.dart';
// import 'package:fit_and_fine/logic/member/profile/profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EditPersonalInfoScreen extends StatefulWidget {
  const EditPersonalInfoScreen({super.key});

  @override
  State<EditPersonalInfoScreen> createState() => _EditPersonalInfoScreenState();
}

class _EditPersonalInfoScreenState extends State<EditPersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text editing controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _ageController;
  late TextEditingController _bioController;

  // State for the avatar
  String _profileImage = 'assets/images/avatars/avatar1.png'; // Default avatar
  final List<String> _avatarOptions = [
    'assets/images/avatars/avatar1.png',
    'assets/images/avatars/avatar2.png',
    'assets/images/avatars/avatar3.png',
    'assets/images/avatars/avatar4.png',
    'assets/images/avatars/avatar5.png',
  ];

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    Member? currentUser;
    if (authState is AuthAuthenticated) {
      // Assuming the user is a member on this screen
      if (authState.user is Member) {
        currentUser = authState.user as Member;
      }
    }

    // Initialize controllers with user's data or placeholders
    _nameController = TextEditingController(text: currentUser?.name ?? '');
    _emailController = TextEditingController(text: currentUser?.email ?? '');
    _heightController = TextEditingController(
      text: currentUser?.height?.toString() ?? '',
    );
    _weightController = TextEditingController(
      text: currentUser?.weight?.toString() ?? '',
    );
    _ageController = TextEditingController(
      text: currentUser?.age?.toString() ?? '',
    );
    _bioController = TextEditingController(text: currentUser?.bio ?? '');
    _profileImage = currentUser?.avatarUrl ?? _profileImage;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      // In a real app, dispatch an event to ProfileBloc
      // final update = {'name': _nameController.text, 'avatarUrl': _profileImage, ...};
      // context.read<ProfileBloc>().add(UpdateProfile(update));

      print('Saving profile...');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully!')),
      );
      Navigator.of(context).pop();
    }
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose Avatar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _avatarOptions
                  .map(
                    (avatar) => GestureDetector(
                      onTap: () {
                        setState(() {
                          _profileImage = avatar;
                        });
                        Navigator.pop(context);
                      },
                      child: CircleAvatar(
                        radius: 32,
                        backgroundImage: AssetImage(avatar),
                        child: _profileImage == avatar
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                                size: 28,
                              )
                            : null,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // We can add a BlocListener here for the ProfileBloc
    // return BlocListener<ProfileBloc, ProfileState>(
    //   listener: (context, state) {
    //     if (state is ProfileLoaded) { ... }
    //     else if (state is ProfileError) { ... }
    //   },
    //   child: Scaffold(...)
    // );

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Edit Profile',
        actions: [
          TextButton(onPressed: _saveProfile, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // --- Avatar Section ---
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: AssetImage(_profileImage),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _showAvatarPicker,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- Form Fields ---
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Please enter your name'
                  : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) => (value == null || !value.contains('@'))
                  ? 'Please enter a valid email'
                  : null,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _heightController,
                    decoration: const InputDecoration(
                      labelText: 'Height (cm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: 'Age',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Bio / Target',
                hintText: 'e.g., Lose 5kg in 2 months',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
