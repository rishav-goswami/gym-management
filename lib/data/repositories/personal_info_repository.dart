// lib/data/repositories/personal_info_repository.dart

import 'package:fit_and_fine/data/datasources/personal_info_data_source.dart';
import 'package:fit_and_fine/data/models/member_profile_model.dart';

class PersonalInfoRepository {
  final PersonalInfoDataSource _dataSource;

  PersonalInfoRepository({required PersonalInfoDataSource dataSource})
    : _dataSource = dataSource;

  Future<PersonalInfo> getPersonalInfo(String token) async {
    final data = await _dataSource.fetchPersonalInfo(token);
    return PersonalInfo.fromJson(data);
  }

  Future<PersonalInfo> updatePersonalInfo(
    String token,
    Map<String, dynamic> updates,
  ) async {
    final data = await _dataSource.updatePersonalInfo(token, updates);
    return PersonalInfo.fromJson(data);
  }
}
