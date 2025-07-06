import 'package:fit_and_fine/data/datasources/profile_data_source.dart';
import 'package:fit_and_fine/data/models/member_profile_model.dart';

// Mock DataSource that simulates a more complex API response

class ProfileRepository {
  final ProfileDataSource _dataSource;
  ProfileRepository({required ProfileDataSource dataSource})
    : _dataSource = dataSource;

  // The repository now returns a tuple of our new models
  Future<MemberProfileData> getFullUserProfile(String token) async {
    final data = await _dataSource.fetchFullProfile(token);

    final personalInfo = PersonalInfo.fromJson(data['personal']);
    final fitnessInfo = FitnessInfo.fromJson(data['fitness']);
    final paymentInfo = PaymentInfo.fromJson(data['payment']);

    // Assemble the final composite data model.
    return MemberProfileData(
      personalInfo: personalInfo,
      fitnessInfo: fitnessInfo,
      paymentInfo: paymentInfo,
    );
  }
}
