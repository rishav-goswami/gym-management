import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'platform_gym_repository.dart';

class PlatformSupportPanel extends StatefulWidget {
  const PlatformSupportPanel({super.key});

  @override
  State<PlatformSupportPanel> createState() => _PlatformSupportPanelState();
}

class _PlatformSupportPanelState extends State<PlatformSupportPanel> {
  final repository = PlatformGymRepository();
  late Future<List<Map<String, dynamic>>> cases = repository.listSupportCases();

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: cases,
    builder: (context, snapshot) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              FilledButton.icon(
                onPressed: _openCase,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Open case'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (snapshot.hasError)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Support cases could not be loaded.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The request was not completed. Refresh after a moment; no case data was changed.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          )
        else if (!snapshot.hasData)
          const LinearProgressIndicator()
        else if (snapshot.data!.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No platform support cases yet.'),
            ),
          )
        else
          ...snapshot.data!.map((item) {
            final identity = Map<String, dynamic>.from(
              item['requesterIdentity'] as Map? ?? const {},
            );
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.support_agent_outlined),
                ),
                title: Text(item['subject'] as String? ?? 'Support case'),
                subtitle: Text(
                  '${identity['displayName'] ?? identity['email'] ?? item['targetUid']} · ${_status(item['status'])}\n${item['lastMessage'] ?? ''}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => _PlatformCaseDialog(
                    repository: repository,
                    item: item,
                    onChanged: _refresh,
                  ),
                ),
              ),
            );
          }),
      ],
    ),
  );

  void _refresh() => setState(() => cases = repository.listSupportCases());

  Future<void> _openCase() async {
    final consumers = await repository.listConsumers(limit: 200);
    if (!mounted) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _OpenPlatformCaseDialog(repository: repository, consumers: consumers),
    );
    if (created == true) _refresh();
  }
}

class _PlatformCaseDialog extends StatefulWidget {
  const _PlatformCaseDialog({
    required this.repository,
    required this.item,
    required this.onChanged,
  });
  final PlatformGymRepository repository;
  final Map<String, dynamic> item;
  final VoidCallback onChanged;

  @override
  State<_PlatformCaseDialog> createState() => _PlatformCaseDialogState();
}

class _PlatformCaseDialogState extends State<_PlatformCaseDialog> {
  final message = TextEditingController();
  bool working = false;
  double? uploadProgress;

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetUid = widget.item['targetUid'] as String;
    final caseId = widget.item['id'] as String;
    return Dialog(
      child: SizedBox(
        width: 680,
        height: 720,
        child: Column(
          children: [
            ListTile(
              title: Text(widget.item['subject'] as String? ?? 'Support case'),
              subtitle: Text(
                'Shown to the user as Gym Management Support · ${_status(widget.item['status'])}',
              ),
              trailing: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.repository.supportMessages(targetUid, caseId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Messages could not be loaded. Close this case and try again.',
                          textAlign: TextAlign.center,
                        ),
                      ),
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
                      final mine = data['senderType'] == 'platform';
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Card(
                          color: mine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (data['attachmentPath'] is String)
                                  FutureBuilder<String>(
                                    future: widget.repository.supportImageUrl(
                                      data['attachmentPath'] as String,
                                    ),
                                    builder: (context, image) => image.hasData
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.network(
                                              image.data!,
                                              width: 260,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const SizedBox(
                                            width: 36,
                                            height: 36,
                                            child: CircularProgressIndicator(),
                                          ),
                                  ),
                                if ((data['text'] as String? ?? '').isNotEmpty)
                                  Text(data['text'] as String),
                              ],
                            ),
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
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Attach image',
                    onPressed: working ? null : _attach,
                    icon: const Icon(Icons.image_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: message,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText: 'Reply as Gym Management Support',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: working ? null : _reply,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: working ? null : _toggleStatus,
                  icon: Icon(
                    const ['resolved', 'closed'].contains(widget.item['status'])
                        ? Icons.refresh
                        : Icons.check_circle_outline,
                  ),
                  label: Text(
                    const ['resolved', 'closed'].contains(widget.item['status'])
                        ? 'Reopen case'
                        : 'Resolve case',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reply() async {
    if (message.text.trim().isEmpty) return;
    setState(() => working = true);
    try {
      await widget.repository.replyToSupportCase(
        targetUid: widget.item['targetUid'] as String,
        caseId: widget.item['id'] as String,
        message: message.text,
      );
      message.clear();
      widget.onChanged();
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _attach() async {
    setState(() {
      working = true;
      uploadProgress = 0;
    });
    try {
      final path = await widget.repository.pickAndUploadSupportImage(
        targetUid: widget.item['targetUid'] as String,
        caseId: widget.item['id'] as String,
        onProgress: (value) {
          if (mounted) setState(() => uploadProgress = value);
        },
      );
      if (path != null) {
        await widget.repository.replyToSupportCase(
          targetUid: widget.item['targetUid'] as String,
          caseId: widget.item['id'] as String,
          message: message.text,
          attachmentPath: path,
        );
        message.clear();
        widget.onChanged();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to attach image: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          working = false;
          uploadProgress = null;
        });
      }
    }
  }

  Future<void> _toggleStatus() async {
    setState(() => working = true);
    try {
      final isResolved = const [
        'resolved',
        'closed',
      ].contains(widget.item['status']);
      await widget.repository.resolveSupportCase(
        targetUid: widget.item['targetUid'] as String,
        caseId: widget.item['id'] as String,
        status: isResolved ? 'open' : 'resolved',
      );
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }
}

class _OpenPlatformCaseDialog extends StatefulWidget {
  const _OpenPlatformCaseDialog({
    required this.repository,
    required this.consumers,
  });
  final PlatformGymRepository repository;
  final List<Map<String, dynamic>> consumers;

  @override
  State<_OpenPlatformCaseDialog> createState() =>
      _OpenPlatformCaseDialogState();
}

class _OpenPlatformCaseDialogState extends State<_OpenPlatformCaseDialog> {
  final formKey = GlobalKey<FormState>();
  final reason = TextEditingController();
  final subject = TextEditingController();
  final message = TextEditingController();
  String category = 'account';
  String? targetUid;
  bool working = false;

  @override
  void dispose() {
    reason.dispose();
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Open user-visible support case'),
    content: Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: targetUid,
              decoration: const InputDecoration(labelText: 'Consumer'),
              items: widget.consumers
                  .map(
                    (consumer) => DropdownMenuItem(
                      value: consumer['uid'] as String,
                      child: Text(
                        consumer['displayName'] as String? ??
                            consumer['email'] as String? ??
                            consumer['uid'] as String,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => targetUid = value,
              validator: (value) => value == null ? 'Choose a consumer.' : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items:
                  const {
                        'account': 'Account',
                        'privacy': 'Privacy',
                        'bug': 'Product issue',
                        'exerciseContent': 'Exercise content',
                        'onboarding': 'Onboarding',
                        'other': 'Other',
                      }.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
              onChanged: (value) => category = value ?? category,
            ),
            TextFormField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Internal reason'),
              maxLength: 500,
              validator: (value) => (value?.trim().length ?? 0) < 12
                  ? 'Enter at least 12 characters.'
                  : null,
            ),
            TextFormField(
              controller: subject,
              decoration: const InputDecoration(labelText: 'Subject'),
              maxLength: 120,
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Enter at least 3 characters.'
                  : null,
            ),
            TextFormField(
              controller: message,
              decoration: const InputDecoration(labelText: 'Message'),
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Enter a message.' : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: working ? null : _create,
        child: working
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Open case'),
      ),
    ],
  );

  Future<void> _create() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => working = true);
    try {
      await widget.repository.createSupportCase(
        targetUid: targetUid!,
        category: category,
        subject: subject.text.trim(),
        message: message.text.trim(),
        reason: reason.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }
}

class PlatformServiceNoticesPanel extends StatefulWidget {
  const PlatformServiceNoticesPanel({super.key});

  @override
  State<PlatformServiceNoticesPanel> createState() =>
      _PlatformServiceNoticesPanelState();
}

class _PlatformServiceNoticesPanelState
    extends State<PlatformServiceNoticesPanel> {
  final repository = PlatformGymRepository();
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final body = TextEditingController();
  String audience = 'all';
  bool working = false;

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send service notice',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Use notices for one-way service information. Use Support for a conversation.',
                ),
                DropdownButtonFormField<String>(
                  initialValue: audience,
                  decoration: const InputDecoration(labelText: 'Audience'),
                  items:
                      const {
                            'all': 'All consumers',
                            'standalone': 'Standalone users',
                            'gymConnected': 'Gym-connected members',
                            'owners': 'Gym owners',
                          }.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => audience = value ?? audience,
                ),
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                  maxLength: 100,
                  validator: (value) => (value?.trim().length ?? 0) < 3
                      ? 'Enter at least 3 characters.'
                      : null,
                ),
                TextFormField(
                  controller: body,
                  decoration: const InputDecoration(labelText: 'Message'),
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 500,
                  validator: (value) => (value?.trim().length ?? 0) < 3
                      ? 'Enter at least 3 characters.'
                      : null,
                ),
                FilledButton.icon(
                  onPressed: working ? null : _send,
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Send notice'),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text('Recent notices', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('platform_service_notices')
            .orderBy('createdAt', descending: true)
            .limit(30)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LinearProgressIndicator();
          return Column(
            children: snapshot.data!.docs
                .map(
                  (document) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.campaign_outlined),
                      title: Text(
                        document.data()['title'] as String? ?? 'Notice',
                      ),
                      subtitle: Text(
                        '${document.data()['audience']} · ${document.data()['recipientCount'] ?? 0} recipients\n${document.data()['body'] ?? ''}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );

  Future<void> _send() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => working = true);
    try {
      final result = await repository.sendServiceNotice(
        audience: audience,
        title: title.text,
        body: body.text,
      );
      if (!mounted) return;
      title.clear();
      body.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notice sent to ${result['recipientCount']} consumers.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => working = false);
    }
  }
}

String _status(dynamic value) => switch (value) {
  'waitingOnSupport' => 'Waiting for support',
  'waitingOnUser' => 'Waiting for user',
  'resolved' => 'Resolved',
  'closed' => 'Closed',
  _ => 'Open',
};
