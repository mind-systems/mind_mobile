import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mind/User/Infrastructure/ISecureStorage.dart';

class SecureStorage implements ISecureStorage {
  final _inner = const FlutterSecureStorage();

  @override
  Future<void> write(String key, String value) => _inner.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _inner.read(key: key);

  @override
  Future<void> delete(String key) => _inner.delete(key: key);
}
