import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController(text: 'John Doe');
  final _emailController = TextEditingController(text: 'john@example.com');
  String _profileImage =
      'https://cdn.pixabay.com/photo/2017/12/03/18/04/christmas-balls-2995437_960_720.jpg';

  void _updateProfile() {
    // Placeholder logic - you can connect this to your backend
    debugPrint("Updated name: ${_nameController.text}");
    debugPrint("Updated email: ${_emailController.text}");
    Navigator.pop(context); // Go back to sidebar or profile screen
  }

  void _changeProfileImage() {
    // TODO: Replace with image picker logic
    setState(() {
      _profileImage =
          'https://cdn.pixabay.com/photo/2019/12/20/00/03/road-4707345_960_720.jpg';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _changeProfileImage,
              child: GFAvatar(
                size: GFSize.LARGE * 2,
                backgroundImage: NetworkImage(_profileImage),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 20),
            GFButton(
              onPressed: _updateProfile,
              text: "Save Changes",
              blockButton: true,
              size: GFSize.LARGE,
              icon: const Icon(Icons.save),
            )
          ],
        ),
      ),
    );
  }
}
