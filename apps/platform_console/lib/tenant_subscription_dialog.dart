import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'platform_gym_repository.dart';

class TenantSubscriptionDialog extends StatefulWidget {
  const TenantSubscriptionDialog({required this.document, super.key});

  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  @override
  State<TenantSubscriptionDialog> createState() =>
      _TenantSubscriptionDialogState();
}

class _TenantSubscriptionDialogState extends State<TenantSubscriptionDialog> {
  static const featureLabels = <String, String>{
    'classes': 'Classes and bookings',
    'chat': 'Member–trainer chat',
    'attendanceQr': 'QR attendance',
    'dietPlans': 'Diet plans',
    'progressPhotos': 'Progress photos',
  };

  final repository = PlatformGymRepository();
  final duration = TextEditingController(text: '30');
  String? planId;
  late String status = widget.document.data()['status'] as String? ?? 'trial';
  Map<String, bool> planFeatures = {};
  Map<String, bool> effectiveFeatures = {};
  bool saving = false;

  @override
  void dispose() {
    duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Subscription · ${widget.document.data()['name']}'),
    content: SizedBox(
      width: 620,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('saas_plans')
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          final plans = snapshot.data?.docs ?? const [];
          planId ??=
              widget.document.data()['platformPlan'] as String? ??
              (plans.isEmpty ? null : plans.first.id);
          final selected = plans.where((item) => item.id == planId).firstOrNull;
          if (selected != null && planFeatures.isEmpty) {
            planFeatures = Map<String, bool>.from(
              selected.data()['features'] as Map? ?? const {},
            );
            effectiveFeatures = {
              ...planFeatures,
              ...Map<String, bool>.from(
                widget.document.data()['featureOverrides'] as Map? ?? const {},
              ),
            };
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: plans.any((item) => item.id == planId)
                      ? planId
                      : null,
                  decoration: const InputDecoration(labelText: 'SaaS plan'),
                  items: plans
                      .map(
                        (plan) => DropdownMenuItem(
                          value: plan.id,
                          child: Text(
                            '${plan.data()['name']} · v${plan.data()['version'] ?? 1}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    final plan = plans.firstWhere((item) => item.id == value);
                    setState(() {
                      planId = value;
                      planFeatures = Map<String, bool>.from(
                        plan.data()['features'] as Map? ?? const {},
                      );
                      effectiveFeatures = {...planFeatures};
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Tenant status'),
                  items: const [
                    DropdownMenuItem(value: 'trial', child: Text('Trial')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'suspended',
                      child: Text('Suspended'),
                    ),
                  ],
                  onChanged: (value) => setState(() => status = value!),
                ),
                TextField(
                  controller: duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Access duration from today (days)',
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Effective features',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'Changing a switch creates a tenant override on top of the selected plan.',
                ),
                for (final entry in featureLabels.entries)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value),
                    subtitle: Text(
                      planFeatures[entry.key] == true
                          ? 'Included by plan'
                          : 'Not included by plan',
                    ),
                    value: effectiveFeatures[entry.key] == true,
                    onChanged: (value) =>
                        setState(() => effectiveFeatures[entry.key] = value),
                  ),
              ],
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Saving…' : 'Apply subscription'),
      ),
    ],
  );

  Future<void> _save() async {
    final selectedPlan = planId;
    final days = int.tryParse(duration.text.trim());
    if (selectedPlan == null || days == null || days < 1) return;
    setState(() => saving = true);
    try {
      final overrides = <String, bool>{};
      for (final feature in featureLabels.keys) {
        if (effectiveFeatures[feature] != planFeatures[feature]) {
          overrides[feature] = effectiveFeatures[feature] == true;
        }
      }
      await repository.setSubscription(
        gymId: widget.document.id,
        planId: selectedPlan,
        status: status,
        durationDays: days,
        featureOverrides: overrides,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update subscription: $error')),
        );
      }
    }
  }
}
