import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gym_core/gym_core.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../data/support_repository.dart';
import '../../logic/session_cubit.dart';

class SupportHubScreen extends StatelessWidget {
  const SupportHubScreen({
    this.membership,
    this.initialRoute,
    this.supportContext,
    super.key,
  });

  final GymMembership? membership;
  final String? initialRoute;
  final Map<String, dynamic>? supportContext;

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<SessionCubit>().state.user!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: context.read<SupportRepository>().inbox(uid),
        builder: (context, snapshot) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (initialRoute != null)
              _AutoOpenSupportRoute(
                route: initialRoute!,
                membership: membership,
                supportContext: supportContext,
              ),
            Text(
              'How can we help?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose the right team so your question reaches someone who can act on it.',
            ),
            const SizedBox(height: 18),
            if (membership != null && AppFeatureFlags.gymSupport) ...[
              _SupportRouteCard(
                icon: Icons.sports_gymnastics_outlined,
                title: 'Ask your trainer',
                subtitle:
                    'Exercise technique, routines, and trainer assignments.',
                onTap: () => _createGymCase(
                  context,
                  membership!,
                  coaching: true,
                  supportContext: supportContext,
                ),
              ),
              _SupportRouteCard(
                icon: Icons.storefront_outlined,
                title: 'Contact ${membership!.gymName}',
                subtitle:
                    'Membership, payments, attendance, classes, or facilities.',
                onTap: () =>
                    _createGymCase(context, membership!, coaching: false),
              ),
            ],
            if (AppFeatureFlags.platformSupport)
              _SupportRouteCard(
                icon: Icons.support_agent_outlined,
                title: 'App support',
                subtitle:
                    'Account access, privacy, bugs, or exercise-content reports.',
                onTap: () => _createPlatformCase(
                  context,
                  supportContext: supportContext,
                ),
              ),
            const SizedBox(height: 10),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const ListTile(
                leading: Icon(Icons.health_and_safety_outlined),
                title: Text('Not an emergency service'),
                subtitle: Text(
                  'Stop exercising for pain, dizziness, or unusual discomfort. Contact local emergency services or a qualified healthcare professional when needed.',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your conversations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (snapshot.hasError)
              Text('Unable to load support: ${snapshot.error}')
            else if (!snapshot.hasData)
              const LinearProgressIndicator()
            else if (snapshot.data!.docs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No support conversations yet.'),
                ),
              )
            else
              ...snapshot.data!.docs.map((document) {
                final data = document.data();
                final unread = data['unread'] == true;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        data['scopeType'] == 'gym'
                            ? Icons.storefront_outlined
                            : Icons.support_agent_outlined,
                      ),
                    ),
                    title: Text(
                      data['subject'] as String? ?? 'Support conversation',
                      style: unread
                          ? const TextStyle(fontWeight: FontWeight.bold)
                          : null,
                    ),
                    subtitle: Text(
                      '${_statusLabel(data['status'])} · ${data['lastMessage'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: unread
                        ? const Badge(child: Icon(Icons.chevron_right))
                        : const Icon(Icons.chevron_right),
                    onTap: () => _openThread(context, uid, data),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _openThread(
    BuildContext context,
    String uid,
    Map<String, dynamic> data,
  ) async {
    final gymId = data['gymId'] as String?;
    final threadId = data['threadId'] as String;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportConversationScreen(
          scopeType: data['scopeType'] as String? ?? 'platform',
          ownerUid: uid,
          threadId: threadId,
          gymId: gymId,
          subject: data['subject'] as String? ?? 'Support conversation',
          initialStatus: data['status'] as String? ?? 'open',
          featureId: data['scopeType'] == 'platform'
              ? 'supportPlatform'
              : data['category'] == 'coaching'
              ? 'supportTrainer'
              : 'supportGym',
        ),
      ),
    );
  }
}

class _AutoOpenSupportRoute extends StatefulWidget {
  const _AutoOpenSupportRoute({
    required this.route,
    required this.membership,
    required this.supportContext,
  });

  final String route;
  final GymMembership? membership;
  final Map<String, dynamic>? supportContext;

  @override
  State<_AutoOpenSupportRoute> createState() => _AutoOpenSupportRouteState();
}

class _AutoOpenSupportRouteState extends State<_AutoOpenSupportRoute> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.route == 'trainer' && widget.membership != null) {
        await _createGymCase(
          context,
          widget.membership!,
          coaching: true,
          supportContext: widget.supportContext,
        );
      } else if (widget.route == 'platform') {
        await _createPlatformCase(
          context,
          supportContext: widget.supportContext,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _SupportRouteCard extends StatelessWidget {
  const _SupportRouteCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

Future<void> _createGymCase(
  BuildContext context,
  GymMembership membership, {
  required bool coaching,
  Map<String, dynamic>? supportContext,
}) async {
  final result = await showDialog<_NewSupportCase>(
    context: context,
    builder: (_) => _NewSupportDialog(
      title: coaching ? 'Ask your trainer' : 'Contact ${membership.gymName}',
      categories: coaching
          ? const {'coaching': 'Exercise or routine guidance'}
          : const {
              'membership': 'Membership',
              'payment': 'Payment',
              'attendance': 'Attendance',
              'classes': 'Classes',
              'facility': 'Gym facility',
              'other': 'Something else',
            },
      initialCategory: coaching ? 'coaching' : null,
      supportContext: supportContext,
    ),
  );
  if (result == null || !context.mounted) return;
  try {
    final id = await context.read<SupportRepository>().createGymThread(
      gymId: membership.gymId,
      category: result.category,
      subject: result.subject,
      message: result.message,
      supportContext: supportContext,
    );
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportConversationScreen(
          scopeType: 'gym',
          ownerUid: membership.uid,
          gymId: membership.gymId,
          threadId: id,
          subject: result.subject,
          initialStatus: 'waitingOnSupport',
          featureId: coaching ? 'supportTrainer' : 'supportGym',
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) _showError(context, error);
  }
}

Future<void> _createPlatformCase(
  BuildContext context, {
  Map<String, dynamic>? supportContext,
}) async {
  final result = await showDialog<_NewSupportCase>(
    context: context,
    builder: (_) => _NewSupportDialog(
      title: 'App support',
      categories: const {
        'account': 'Account access',
        'privacy': 'Privacy or data',
        'bug': 'Something is not working',
        'exerciseContent': 'Exercise content',
        'onboarding': 'Getting started',
        'other': 'Something else',
      },
      initialCategory: supportContext?['type'] == 'exercise'
          ? 'exerciseContent'
          : null,
      supportContext: supportContext,
    ),
  );
  if (result == null || !context.mounted) return;
  try {
    final id = await context.read<SupportRepository>().createPlatformCase(
      category: result.category,
      subject: result.subject,
      message: result.message,
      supportContext: supportContext,
    );
    if (!context.mounted) return;
    final uid = context.read<SessionCubit>().state.user!.uid;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportConversationScreen(
          scopeType: 'platform',
          ownerUid: uid,
          threadId: id,
          subject: result.subject,
          initialStatus: 'waitingOnSupport',
          featureId: 'supportPlatform',
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) _showError(context, error);
  }
}

class _NewSupportCase {
  const _NewSupportCase(this.category, this.subject, this.message);
  final String category;
  final String subject;
  final String message;
}

class _NewSupportDialog extends StatefulWidget {
  const _NewSupportDialog({
    required this.title,
    required this.categories,
    this.initialCategory,
    this.supportContext,
  });
  final String title;
  final Map<String, String> categories;
  final String? initialCategory;
  final Map<String, dynamic>? supportContext;

  @override
  State<_NewSupportDialog> createState() => _NewSupportDialogState();
}

class _NewSupportDialogState extends State<_NewSupportDialog> {
  final formKey = GlobalKey<FormState>();
  final subject = TextEditingController();
  final message = TextEditingController();
  late String category = widget.initialCategory ?? widget.categories.keys.first;

  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Topic'),
              items: widget.categories.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) => category = value ?? category,
            ),
            if (widget.supportContext != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link),
                title: Text('${widget.supportContext!['label']}'),
                subtitle: const Text(
                  'Only this reference is attached—not your workout or health data.',
                ),
              ),
            TextFormField(
              controller: subject,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Short subject'),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Enter at least 3 characters.'
                  : null,
            ),
            TextFormField(
              controller: message,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'How can we help?',
                alignLabelWithHint: true,
              ),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Enter a message.' : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _NewSupportCase(category, subject.text.trim(), message.text.trim()),
          );
        },
        child: const Text('Send request'),
      ),
    ],
  );
}

class SupportConversationScreen extends StatefulWidget {
  const SupportConversationScreen({
    required this.scopeType,
    required this.ownerUid,
    required this.threadId,
    required this.subject,
    required this.initialStatus,
    this.gymId,
    this.targetUid,
    this.featureId,
    this.staffMode = false,
    super.key,
  });
  final String scopeType;
  final String ownerUid;
  final String threadId;
  final String subject;
  final String initialStatus;
  final String? gymId;
  final String? targetUid;
  final String? featureId;
  final bool staffMode;

  @override
  State<SupportConversationScreen> createState() =>
      _SupportConversationScreenState();
}

class _SupportConversationScreenState extends State<SupportConversationScreen> {
  final message = TextEditingController();
  bool sending = false;
  double? uploadProgress;
  late String status = widget.initialStatus;

  @override
  void initState() {
    super.initState();
    context
        .read<SupportRepository>()
        .markRead(
          scopeType: widget.scopeType,
          gymId: widget.gymId,
          targetUid: widget.targetUid,
          threadId: widget.threadId,
        )
        .catchError((_) {});
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stream = widget.scopeType == 'gym'
        ? context.read<SupportRepository>().gymMessages(
            widget.gymId!,
            widget.threadId,
          )
        : context.read<SupportRepository>().platformMessages(
            widget.targetUid ?? widget.ownerUid,
            widget.threadId,
          );
    final currentUid = context.read<SessionCubit>().state.user!.uid;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () async {
            if (await Navigator.of(context).maybePop()) return;
            if (!context.mounted) return;
            context.go(widget.staffMode ? '/workspace' : '/support');
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.subject, overflow: TextOverflow.ellipsis),
            Text(
              _statusLabel(status),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          if (widget.staffMode &&
              !const ['resolved', 'closed'].contains(status))
            TextButton(
              onPressed: () => _setStatus('resolved'),
              child: const Text('Resolve'),
            ),
          if (widget.staffMode && const ['resolved', 'closed'].contains(status))
            TextButton(
              onPressed: () => _setStatus('open'),
              child: const Text('Reopen'),
            ),
          if (!widget.staffMode &&
              const ['resolved', 'closed'].contains(status))
            IconButton(
              tooltip: 'Rate this resolution',
              onPressed: _rateResolution,
              icon: const Icon(Icons.star_outline),
            ),
          if (!widget.staffMode &&
              const ['resolved', 'closed'].contains(status))
            TextButton(
              onPressed: () => _setStatus('open'),
              child: const Text('Reopen'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Unable to load messages: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final data = snapshot.data!.docs[index].data();
                    final mine = data['senderUid'] == currentUid;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 520),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: mine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (data['attachmentPath'] is String)
                              _SupportImage(
                                path: data['attachmentPath'] as String,
                              ),
                            if ((data['text'] as String? ?? '').isNotEmpty)
                              Text(data['text'] as String),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (uploadProgress != null)
            LinearProgressIndicator(value: uploadProgress),
          if (!const ['resolved', 'closed'].contains(status))
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    if (AppFeatureFlags.supportImages)
                      IconButton(
                        tooltip: 'Attach image',
                        onPressed: sending ? null : _attach,
                        icon: const Icon(Icons.image_outlined),
                      ),
                    Expanded(
                      child: TextField(
                        controller: message,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          hintText: 'Write a message',
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Send',
                      onPressed: sending ? null : () => _send(),
                      icon: sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            )
          else
            const SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'This conversation is resolved. Reopen it to send another message.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _send({String? attachmentPath}) async {
    if (message.text.trim().isEmpty && attachmentPath == null) return;
    setState(() => sending = true);
    try {
      await context.read<SupportRepository>().sendMessage(
        scopeType: widget.scopeType,
        gymId: widget.gymId,
        targetUid: widget.targetUid,
        threadId: widget.threadId,
        text: message.text,
        attachmentPath: attachmentPath,
      );
      message.clear();
      setState(
        () => status = widget.staffMode ? 'waitingOnUser' : 'waitingOnSupport',
      );
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _attach() async {
    setState(() {
      sending = true;
      uploadProgress = 0;
    });
    try {
      final path = await context.read<SupportRepository>().pickAndUploadImage(
        scopeType: widget.scopeType,
        ownerId: widget.scopeType == 'gym' ? widget.gymId! : widget.ownerUid,
        threadId: widget.threadId,
        onProgress: (value) {
          if (mounted) setState(() => uploadProgress = value);
        },
      );
      if (path != null) await _send(attachmentPath: path);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
          uploadProgress = null;
        });
      }
    }
  }

  Future<void> _rateResolution() async {
    final rating = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Was this helpful?'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var value = 1; value <= 5; value++)
              IconButton(
                tooltip: '$value out of 5',
                onPressed: () => Navigator.pop(dialogContext, value),
                icon: const Icon(Icons.star_outline),
              ),
          ],
        ),
      ),
    );
    if (rating == null || !mounted) return;
    try {
      await context.read<SupportRepository>().submitResolutionRating(
        featureId:
            widget.featureId ??
            (widget.scopeType == 'platform' ? 'supportPlatform' : 'supportGym'),
        rating: rating,
        gymId: widget.gymId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for your feedback.')),
        );
      }
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }

  Future<void> _setStatus(String value) async {
    try {
      await context.read<SupportRepository>().updateStatus(
        scopeType: widget.scopeType,
        gymId: widget.gymId,
        targetUid: widget.targetUid,
        threadId: widget.threadId,
        status: value,
      );
      if (mounted) setState(() => status = value);
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }
}

class _SupportImage extends StatelessWidget {
  const _SupportImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: context.read<SupportRepository>().imageUrl(path),
    builder: (context, snapshot) => Container(
      constraints: const BoxConstraints(maxHeight: 280, minHeight: 100),
      margin: const EdgeInsets.only(bottom: 8),
      child: snapshot.hasData
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(snapshot.data!, fit: BoxFit.cover),
            )
          : const Center(child: CircularProgressIndicator()),
    ),
  );
}

String _statusLabel(dynamic status) => switch (status) {
  'waitingOnSupport' => 'Waiting for support',
  'waitingOnUser' => 'Waiting for you',
  'resolved' => 'Resolved',
  'closed' => 'Closed',
  _ => 'Open',
};

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Unable to complete support action: $error')),
  );
}
