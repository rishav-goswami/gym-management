class BillingAmount {
  const BillingAmount._();

  static int parseMinor(String value) {
    final normalized = value.trim().replaceAll(',', '');
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(normalized)) {
      throw const FormatException('Enter a valid amount with up to 2 decimals');
    }
    final parts = normalized.split('.');
    final rupees = int.parse(parts.first);
    final paise = parts.length == 1
        ? 0
        : int.parse(parts.last.padRight(2, '0'));
    return rupees * 100 + paise;
  }
}

enum SubscriptionHealth { active, expiringSoon, expired, paused, cancelled }

SubscriptionHealth subscriptionHealth({
  required String storedStatus,
  required DateTime? endsAt,
  required DateTime now,
  int expiringWithinDays = 7,
}) {
  if (storedStatus == 'paused') return SubscriptionHealth.paused;
  if (storedStatus == 'cancelled') return SubscriptionHealth.cancelled;
  if (endsAt == null || !endsAt.isAfter(now)) {
    return SubscriptionHealth.expired;
  }
  if (!endsAt.isAfter(now.add(Duration(days: expiringWithinDays)))) {
    return SubscriptionHealth.expiringSoon;
  }
  return SubscriptionHealth.active;
}
