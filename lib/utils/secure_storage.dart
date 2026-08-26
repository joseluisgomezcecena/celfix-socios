import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el bearer token.
///
/// En Android/iOS usa Keystore/Keychain. En Web no existe almacenamiento seguro
/// de plataforma: el plugin cae a localStorage cifrado con AES (WebCrypto). Es
/// una limitación del browser, no del código.
class SecureStorage {
  static const _tokenKey = 'celfix_api_token';
  static const _defaultPasswordFlagKey = 'celfix_using_default_password';

  final FlutterSecureStorage _storage;

  /// v11 usa EncryptedSharedPreferences en Android por default; ya no hace
  /// falta pasar AndroidOptions.
  SecureStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _defaultPasswordFlagKey);
  }

  /// La API no expone si el cliente sigue con la password del backfill.
  /// El único proxy posible es recordar que el login se hizo con "password1".
  Future<bool> readUsingDefaultPassword() async =>
      await _storage.read(key: _defaultPasswordFlagKey) == '1';

  Future<void> writeUsingDefaultPassword(bool value) => value
      ? _storage.write(key: _defaultPasswordFlagKey, value: '1')
      : _storage.delete(key: _defaultPasswordFlagKey);
}
