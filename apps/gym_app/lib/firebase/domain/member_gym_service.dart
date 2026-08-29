import 'package:gym_core/gym_core.dart';

enum MemberGymService { attendance, classes }

List<MemberGymService> availableMemberGymServices({
  required GymMembership membership,
  required bool attendancePlatformEnabled,
}) => [
  if (attendancePlatformEnabled && membership.feature('attendanceQr'))
    MemberGymService.attendance,
  if (membership.feature('classes')) MemberGymService.classes,
];
