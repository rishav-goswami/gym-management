// lib/data/repositories/personal_info_repository.dart

import 'package:fit_and_fine/data/datasources/personal_info_data_source.dart';
import 'package:fit_and_fine/data/models/user_model.dart';

class PersonalInfoRepository {
  final PersonalInfoDataSource _dataSource;

  PersonalInfoRepository({required PersonalInfoDataSource dataSource})
      : _dataSource = dataSource;

  Future<Member> getPersonalInfo(String token) async {
    final data = await _dataSource.fetchPersonalInfo(token);
    return Member.fromJson(data);
  }

  Future<Member> updatePersonalInfo(
    String token,
    Map<String, dynamic> updates,
  ) async {
    final data = await _dataSource.updatePersonalInfo(token, updates);
    return Member.fromJson(data);
  }
}
