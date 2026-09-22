// ignore_for_file: public_member_api_docs

import '../entities/user.dart';
import '../hlc.dart';

abstract interface class UserRepository {
  Future<User?> findById(String id);
  Future<User?> findByDeviceId(String deviceId);
  Future<void> save(User user);
}
