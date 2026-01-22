import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SecureStore {
  static const _kKeyName = 'secure_store.key.v1';
  static const _magic = 'IRISENC1'; // 8 bytes
  static final _algo = Chacha20.poly1305Aead();
  static const _storage = FlutterSecureStorage();

  static Future<SecretKey> _getKey() async {
    var b64 = await _storage.read(key: _kKeyName);
    if (b64 == null || b64.isEmpty) {
      final rnd = Random.secure();
      final keyBytes = List<int>.generate(32, (_) => rnd.nextInt(256));
      b64 = base64UrlEncode(keyBytes);
      await _storage.write(key: _kKeyName, value: b64);
    }
    return SecretKey(base64Url.decode(b64));
  }

  static Future<Uint8List> encrypt(Uint8List plain) async {
    final key = await _getKey();
    final rnd = Random.secure();
    final nonce = List<int>.generate(12, (_) => rnd.nextInt(256));
    final sb = await _algo.encrypt(plain, secretKey: key, nonce: nonce);
    final out = BytesBuilder();
    out.add(utf8.encode(_magic));
    out.add(nonce);
    out.add(sb.cipherText);
    out.add(sb.mac.bytes); // 16B
    return Uint8List.fromList(out.toBytes());
  }

  static Future<Uint8List> decrypt(Uint8List packed) async {
    final magic = utf8.encode(_magic);
    if (packed.length < magic.length + 12 + 16) {
      throw StateError('Encrypted blob too short');
    }
    for (int i = 0; i < magic.length; i++) {
      if (packed[i] != magic[i]) throw StateError('Bad magic');
    }
    final nonce = packed.sublist(magic.length, magic.length + 12);
    final macStart = packed.length - 16;
    final cipherText = packed.sublist(magic.length + 12, macStart);
    final mac = Mac(packed.sublist(macStart));
    final key = await _getKey();
    final clear = await _algo.decrypt(SecretBox(cipherText, nonce: nonce, mac: mac), secretKey: key);
    return Uint8List.fromList(clear);
  }

  static Future<String> writeEncrypted(String path, Uint8List plain) async {
    final enc = await encrypt(plain);
    final f = File(path);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(enc, flush: true);
    return path;
  }

  static Future<Uint8List> readDecrypted(String path) async {
    final packed = await File(path).readAsBytes();
    return await decrypt(packed);
  }

  /// Делает временный расшифрованный JPG рядом с кешем (для шаринга/отправки)
  static Future<String> createTempPlainFromEncrypted(String encPath) async {
    final bytes = await readDecrypted(encPath);
    final cache = await getTemporaryDirectory();
    final out = p.join(
      cache.path,
      'tmp_${DateTime.now().millisecondsSinceEpoch}_${p.basename(encPath).replaceAll(".enc", ".jpg")}',
    );
    await File(out).writeAsBytes(bytes, flush: true);
    return out;
  }
}
