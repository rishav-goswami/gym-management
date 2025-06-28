// lib/data/repositories/personal_info_repository.dart

import 'package:fit_and_fine/data/datasources/personal_info_data_source.dart';
import 'package:fit_and_fine/data/models/user_model.dart';

class PersonalInfoRepository {
  final PersonalInfoDataSource _dataSource;

  PersonalInfoRepository({required PersonalInfoDataSource dataSource})
    : _dataSource = dataSource;

  Future<Member> getPersonalInfo(String userId) async {
    final data = await _dataSource.fetchPersonalInfo(userId);
    return Member.fromJson(data);
  }

  Future<Member> updatePersonalInfo(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    final data = await _dataSource.updatePersonalInfo(userId, updates);
    return Member.fromJson(data);
  }
}
