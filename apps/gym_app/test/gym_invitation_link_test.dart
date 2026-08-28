import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management/core/invitations/gym_invitation_link.dart';

void main() {
  test('builds and parses a shareable invitation route', () {
    const invitation = GymInvitationLink(
      gymId: 'gym/with spaces',
      token: 'a-secure-token-that-is-long-enough',
      gymName: 'Fit & Fine',
      role: 'trainer',
    );

    final parsed = GymInvitationLink.fromUri(invitation.routeUri);

    expect(parsed, isNotNull);
    expect(parsed!.gymId, invitation.gymId);
    expect(parsed.token, invitation.token);
    expect(parsed.gymName, invitation.gymName);
    expect(parsed.role, invitation.role);
    expect(invitation.shareUri.host, 'createmix-gym-app.web.app');
    expect(invitation.shareUri.path, '/join');
    expect(invitation.shareUri.queryParameters['token'], invitation.token);
    expect(invitation.shareMessage, contains('can only be used once'));
  });

  test('rejects incomplete or short invitation links', () {
    expect(GymInvitationLink.fromUri(Uri.parse('/join')), isNull);
    expect(
      GymInvitationLink.fromUri(Uri.parse('/join?gymId=gym-a&token=short')),
      isNull,
    );
  });

  test('extracts an invitation from the owner share message', () {
    const invitation = GymInvitationLink(
      gymId: 'gym-a',
      token: 'a-secure-token-that-is-long-enough',
      gymName: 'Fit & Fine',
      role: 'owner',
    );

    final parsed = GymInvitationLink.fromText(invitation.shareMessage);

    expect(parsed, isNotNull);
    expect(parsed!.gymId, invitation.gymId);
    expect(parsed.token, invitation.token);
    expect(parsed.role, invitation.role);
  });
}
