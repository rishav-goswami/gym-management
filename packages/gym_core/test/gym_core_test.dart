import 'package:gym_core/gym_core.dart';
import 'package:test/test.dart';

void main() {
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

  test('membership pricing uses integer minor units and expiry', () {
    final quote = MembershipQuote.create(
      amount: '1499.50',
      startsAt: DateTime.utc(2026, 8, 25),
      durationDays: 30,
    );
    expect(quote.amountMinor, 149950);
    expect(quote.endsAt, DateTime.utc(2026, 9, 24));
  });

  test('billing parsing and subscription health are deterministic', () {
    expect(BillingAmount.parseMinor('1,499.50'), 149950);
    expect(() => BillingAmount.parseMinor('12.345'), throwsFormatException);
    final now = DateTime.utc(2026, 8, 26);
    expect(
      subscriptionHealth(
        storedStatus: 'active',
        endsAt: now.add(const Duration(days: 3)),
        now: now,
      ),
      SubscriptionHealth.expiringSoon,
    );
  });

  test('workout parsing and goal progress are reusable', () {
    final target = WorkoutSetTarget.parse('4x8@62.5');
    expect((target.sets, target.reps, target.weightKg), (4, 8, 62.5));
    expect(goalProgress(start: 100, current: 90, target: 80), .5);
  });

  test('gym branding and business profile load from tenant data', () {
    const membership = GymMembership(
      id: 'gym_uid',
      gymId: 'gym',
      uid: 'uid',
      role: GymRole.member,
      status: 'active',
      permissions: {},
    );
    final branded = membership.withGym({
      'name': 'Lift House',
      'currency': 'INR',
      'city': 'Jaipur',
      'branding': {
        'logoUrl': 'https://example.com/logo.png',
        'primaryColor': '#112233',
        'secondaryColor': '#223344',
        'accentColor': '#FF6600',
        'tagline': 'Train with purpose',
      },
    });
    expect(branded.gymName, 'Lift House');
    expect(branded.logoUrl, 'https://example.com/logo.png');
    expect(branded.primaryColor, '#112233');
    expect(branded.secondaryColor, '#223344');
    expect(branded.accentColor, '#FF6600');
    expect(branded.tagline, 'Train with purpose');
    expect(branded.city, 'Jaipur');
  });
}
