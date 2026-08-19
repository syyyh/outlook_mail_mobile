import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/mail_account.dart';
import '../models/mail_message.dart';

class AccountStore {
  AccountStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'outlook_mail_accounts_v1';
  static const _messageCacheKey = 'outlook_mail_message_cache_v1';
  final FlutterSecureStorage _storage;

  Future<List<MailAccount>> readAccounts() async {
    final encoded = await _storage.read(key: _storageKey);
    if (encoded == null || encoded.isEmpty) return [];
    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(MailAccount.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> writeAccounts(List<MailAccount> accounts) {
    final encoded = jsonEncode(
      accounts.map((account) => account.toJson()).toList(),
    );
    return _storage.write(key: _storageKey, value: encoded);
  }

  Future<Map<String, List<MailMessage>>> readMessageCache() async {
    final encoded = await _storage.read(key: _messageCacheKey);
    if (encoded == null || encoded.isEmpty) return {};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return {};
      final result = <String, List<MailMessage>>{};
      for (final entry in decoded.entries) {
        final values = entry.value;
        if (values is! List) continue;
        result[entry.key.toString()] = values
            .whereType<Map>()
            .map(
              (item) => MailMessage.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((message) => message.id.isNotEmpty)
            .toList();
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> writeMessageCache(Map<String, List<MailMessage>> cache) {
    final encoded = jsonEncode(
      cache.map(
        (key, messages) =>
            MapEntry(key, messages.map((message) => message.toJson()).toList()),
      ),
    );
    return _storage.write(key: _messageCacheKey, value: encoded);
  }
}
