import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _keyToken = 'auth_token';
  static const _keySpecies = 'seaweed_species';
  static const _keyFarmName = 'farm_name';
  static const _keyFarmLocation = 'farm_location';
  static const _keyManagerName = 'manager_name';
  static const _keyManagerEmail = 'manager_email';

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

  // Save farm details from API response
  static Future<void> saveFarmDetails(Map<String, dynamic> data) async {
    await _storage.write(key: _keyFarmName, value: data['farmName']);
    await _storage.write(key: _keyFarmLocation, value: data['farmLocation']);
    await _storage.write(key: _keyManagerName, value: data['managerName']);
    await _storage.write(key: _keyManagerEmail, value: data['managerEmail']);
  }

  // Read farm details (offline)
  static Future<Map<String, String?>> getFarmDetails() async {
    return {
      'farmName': await _storage.read(key: _keyFarmName),
      'farmLocation': await _storage.read(key: _keyFarmLocation),
      'managerName': await _storage.read(key: _keyManagerName),
      'managerEmail': await _storage.read(key: _keyManagerEmail),
    };
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
