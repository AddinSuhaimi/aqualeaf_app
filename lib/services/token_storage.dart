import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _keyToken = 'auth_token';
  static const _keySpecies = 'seaweed_species';

  // Save token
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  // Read token
  static Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  // Delete token (logout)
  static Future<void> clearToken() async {
    await _storage.delete(key: _keyToken);
  }

  // Seaweed species methods
  static Future<void> saveSpecies(String species) async =>
      _storage.write(key: _keySpecies, value: species);

  static Future<String?> getSpecies() async =>
      _storage.read(key: _keySpecies);

  static Future<void> clearSpecies() async =>
      _storage.delete(key: _keySpecies);

  static Future<void> clearAll() async =>
      _storage.deleteAll();
}
