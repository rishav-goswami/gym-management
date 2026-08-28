import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_core/gym_core.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/invitations/gym_invitation_link.dart';
import '../../data/firebase_session_repository.dart';
import '../../logic/session_cubit.dart';

class GymContextScreen extends StatefulWidget {
  const GymContextScreen({super.key, this.invitation});

  final GymInvitationLink? invitation;

  @override
  State<GymContextScreen> createState() => _GymContextScreenState();
}

class _GymContextScreenState extends State<GymContextScreen> {
  bool _accepting = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionCubit>().state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your fitness spaces'),
        actions: [
          IconButton(
            onPressed: context.read<SessionCubit>().signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Your spaces',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your personal fitness stays yours. Open a gym space only when you need its services.',
          ),
          const SizedBox(height: 20),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.favorite_outline)),
              title: const Text('My Fitness'),
              subtitle: const Text('Personal workouts, routines and progress'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await context.read<SessionCubit>().choosePersonalSpace();
                if (context.mounted) context.go('/personal');
              },
            ),
          ),
          const SizedBox(height: 8),
          ...state.memberships.map(
            (membership) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    membership.gymName.characters.first.toUpperCase(),
                  ),
                ),
                title: Text(membership.gymName),
                subtitle: Text(_gymSpaceDescription(membership)),
                trailing: membership.role == GymRole.member
                    ? const Icon(Icons.chevron_right)
                    : FilledButton.tonalIcon(
                        onPressed: () => _openGym(membership),
                        icon: const Icon(Icons.dashboard_outlined),
                        label: const Text('Open dashboard'),
                      ),
                onTap: () => _openGym(membership),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (widget.invitation != null) ...[
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.mark_email_read_outlined, size: 42),
                    const SizedBox(height: 12),
                    Text(
                      'Join ${widget.invitation!.gymName}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You were invited as a ${widget.invitation!.roleLabel}.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _accepting ? null : _accept,
                      icon: const Icon(Icons.group_add_outlined),
                      label: Text(_accepting ? 'Joining…' : 'Join gym'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The signed-in email must match the invitation.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              leading: const Icon(Icons.add_business_outlined),
              title: const Text(
                'Own a gym?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Create a secure workspace and start a limited free trial.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/start-gym'),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.invitation == null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('Join a gym'),
                subtitle: const Text(
                  'Scan the QR code or use the secure invitation shared by your gym.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openInvitation,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openGym(GymMembership membership) async {
    await context.read<SessionCubit>().selectMembership(membership);
    if (mounted) context.go('/workspace');
  }

  Future<void> _openInvitation() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => const _InvitationScannerDialog(),
    );
    if (value == null || !mounted) return;
    final invitation = GymInvitationLink.fromText(value);
    if (invitation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That is not a valid Gym Management invitation.'),
        ),
      );
      return;
    }
    context.go(invitation.routeLocation);
  }

  Future<void> _accept() async {
    final invitation = widget.invitation;
    if (invitation == null) return;
    setState(() => _accepting = true);
    try {
      await context.read<FirebaseSessionRepository>().acceptInvitation(
        gymId: invitation.gymId,
        token: invitation.token,
      );
      if (!mounted) return;
      final session = context.read<SessionCubit>();
      await session.refreshContexts();
      for (final membership in session.state.memberships) {
        if (membership.gymId == invitation.gymId) {
          if (mounted) await _sharingChoice(membership.gymId);
          if (mounted) context.go('/personal');
          return;
        }
      }
      if (mounted) context.go('/contexts');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _sharingChoice(String gymId) async {
    final values = <String, bool>{
      'profile': false,
      'goals': false,
      'workoutSummaries': false,
      'measurements': false,
      'progress': false,
    };
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Share fitness data?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nothing is shared by default. Gym services still work without sharing.',
                ),
                const SizedBox(height: 12),
                ...values.entries.map(
                  (entry) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: entry.value,
                    title: Text(_sharingLabel(entry.key)),
                    onChanged: (value) =>
                        setDialogState(() => values[entry.key] = value),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep private'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save choices'),
            ),
          ],
        ),
      ),
    );
    if (save == true && mounted) {
      await context
          .read<FirebaseSessionRepository>()
          .functions
          .httpsCallable('updateGymSharing')
          .call<void>({'gymId': gymId, 'categories': values});
    }
  }

  String _sharingLabel(String value) => switch (value) {
    'workoutSummaries' => 'Workout summaries',
    'measurements' => 'Body measurements',
    'progress' => 'Progress records and photos',
    'goals' => 'Fitness goals',
    _ => 'Profile basics',
  };

  String _gymSpaceDescription(GymMembership membership) =>
      membership.role == GymRole.member
      ? 'Gym services · membership, trainer, classes and attendance'
      : '${membership.role.name} operations for this gym';
}

class _InvitationScannerDialog extends StatefulWidget {
  const _InvitationScannerDialog();

  @override
  State<_InvitationScannerDialog> createState() =>
      _InvitationScannerDialogState();
}

class _InvitationScannerDialogState extends State<_InvitationScannerDialog> {
  bool found = false;
  String? clipboardMessage;

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440, maxHeight: 620),
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.qr_code_scanner),
            title: Text('Join your gym'),
            subtitle: Text('Point the camera at the invitation QR code.'),
          ),
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                final value = capture.barcodes.firstOrNull?.rawValue;
                if (!found && value != null) {
                  found = true;
                  Navigator.pop(context, value);
                }
              },
              errorBuilder: (_, _) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Camera scanning is unavailable. Use the invitation link from your clipboard below.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          if (clipboardMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                clipboardMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _useClipboard,
                  icon: const Icon(Icons.content_paste_go_outlined),
                  label: const Text('Use copied invitation'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _useClipboard() async {
    final value = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (!mounted) return;
    if (value == null || GymInvitationLink.fromText(value) == null) {
      setState(
        () => clipboardMessage =
            'Copy the invitation link sent by your gym, then try again.',
      );
      return;
    }
    Navigator.pop(context, value);
  }
}
