import 'package:fit_and_fine/core/widgets/custom_appbar.dart';
import 'package:flutter/material.dart';

class MemberPaymentsScreen extends StatelessWidget {
  const MemberPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Payments & Subscriptions'),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // --- Current Plan Section ---
          Text(
            'Current Plan',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: theme.colorScheme.primaryContainer.withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premium Monthly', // Placeholder
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$29.99 / month', // Placeholder
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your plan renews on July 28, 2025.', // Placeholder
                     style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                   const SizedBox(height: 20),
                   SizedBox(
                     width: double.infinity,
                     child: FilledButton(
                       onPressed: () { /* Handle change plan logic */ },
                       child: const Text('Change Plan'),
                     ),
                   )
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // --- Payment Method Section ---
           Text(
            'Payment Method',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.credit_card, size: 32),
            title: const Text('Visa **** 1234'),
            subtitle: const Text('Expires 12/26'),
            trailing: TextButton(
              onPressed: () { /* Handle update payment logic */ },
              child: const Text('Update'),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor)
            ),
            tileColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 32),

          // --- Billing History Section ---
           Text(
            'Billing History',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _BillingHistoryItem(date: 'June 28, 2025', amount: '\$29.99', status: 'Paid'),
          _BillingHistoryItem(date: 'May 28, 2025', amount: '\$29.99', status: 'Paid'),
          _BillingHistoryItem(date: 'April 28, 2025', amount: '\$29.99', status: 'Paid'),
        ],
      ),
    );
  }
}

class _BillingHistoryItem extends StatelessWidget {
  final String date;
  final String amount;
  final String status;

  const _BillingHistoryItem({required this.date, required this.amount, required this.status});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
        title: Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(date),
        trailing: Text(
          status,
          style: TextStyle(
            color: Colors.green.shade600,
            fontWeight: FontWeight.bold
          ),
        ),
      ),
    );
  }
}
