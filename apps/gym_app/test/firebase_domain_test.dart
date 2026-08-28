import 'package:gym_core/gym_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management/firebase/logic/session_cubit.dart';

void main() {
  test('consumer routing waits for public branding configuration', () {
    expect(const SessionState().platformBrandingLoaded, isFalse);
    const loaded = SessionState(
      platformBranding: {
        '_configurationLoaded': true,
        'consumerFeatures': {'personalSpacesV1': true},
      },
    );
    expect(loaded.platformBrandingLoaded, isTrue);
    expect(loaded.personalSpacesEnabled, isTrue);
  });

  test('role permissions honor explicit per-user overrides', () {
    const membership = GymMembership(
      id: 'gym_uid',
      gymId: 'gym',
      uid: 'uid',
      role: GymRole.receptionist,
      status: 'active',
      permissions: {'payments.write': true, 'staff.manage': false},
    );
    expect(membership.can('payments.write'), isTrue);
    expect(membership.can('staff.manage'), isFalse);
  });

  test('membership pricing uses integer minor units and calculates expiry', () {
    final quote = MembershipQuote.create(
      amount: '1499.50',
      startsAt: DateTime.utc(2026, 8, 25),
      durationDays: 30,
    );
    expect(quote.amountMinor, 149950);
    expect(quote.endsAt, DateTime.utc(2026, 9, 24));
  });

  test('billing amount parsing avoids floating point money errors', () {
    expect(BillingAmount.parseMinor('1,499.50'), 149950);
    expect(BillingAmount.parseMinor('99.9'), 9990);
    expect(() => BillingAmount.parseMinor('12.345'), throwsFormatException);
    expect(() => BillingAmount.parseMinor('-1'), throwsFormatException);
  });

  test('subscription health derives expiry without trusting stale status', () {
    final now = DateTime.utc(2026, 8, 26);
    expect(
      subscriptionHealth(
        storedStatus: 'active',
        endsAt: now.add(const Duration(days: 3)),
        now: now,
      ),
      SubscriptionHealth.expiringSoon,
    );
    expect(
      subscriptionHealth(
        storedStatus: 'active',
        endsAt: now.subtract(const Duration(seconds: 1)),
        now: now,
      ),
      SubscriptionHealth.expired,
    );
  });

  test('workout parser handles sets, reps, and weight', () {
    final target = WorkoutSetTarget.parse('4x8@62.5');
    expect((target.sets, target.reps, target.weightKg), (4, 8, 62.5));
    expect(() => WorkoutSetTarget.parse('four sets'), throwsFormatException);
  });

  test('goal progress works for increasing and decreasing targets', () {
    expect(goalProgress(start: 100, current: 90, target: 80), .5);
    expect(goalProgress(start: 50, current: 70, target: 60), 1);
  });
}
