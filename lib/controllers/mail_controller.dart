import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/mail_account.dart';
import '../models/mail_message.dart';
import '../services/account_parser.dart';
import '../services/account_store.dart';
import '../services/microsoft_mail_service.dart';

enum AccountFilter { favorite, success, all, failed }

class MailController extends ChangeNotifier with WidgetsBindingObserver {
  MailController(this._store, this._mailService, {AccountImportParser? parser})
    : _parser = parser ?? AccountImportParser();

  final AccountStore _store;
  final MicrosoftMailService _mailService;
  final AccountImportParser _parser;
  final Map<String, List<MailMessage>> _messageCache = {};
  final Map<String, MailMessage> _messageDetailCache = {};
  final Map<String, String> _plainMessageCache = {};
  final Set<String> _loadingFolders = {};

  List<MailAccount> _accounts = [];
  AccountFilter _filter = AccountFilter.success;
  Timer? _pollTimer;
  bool _syncingAll = false;
  bool _importing = false;
  bool _isForeground = true;

  List<MailAccount> get accounts => List.unmodifiable(_accounts);
  AccountFilter get filter => _filter;
  bool get importing => _importing;
  bool get syncingAll => _syncingAll;

  int get successCount => _accounts
      .where((account) => account.status == AccountStatus.success)
      .length;
  int get failedCount => _accounts
      .where((account) => account.status == AccountStatus.failed)
      .length;
  int get validatingCount => _accounts
      .where((account) => account.status == AccountStatus.validating)
      .length;

  List<MailAccount> get filteredAccounts => switch (_filter) {
    AccountFilter.favorite =>
      _accounts.where((account) => account.isFavorite).toList(),
    AccountFilter.success =>
      _accounts
          .where((account) => account.status == AccountStatus.success)
          .toList(),
    AccountFilter.failed =>
      _accounts
          .where((account) => account.status == AccountStatus.failed)
          .toList(),
    AccountFilter.all => List.of(_accounts),
  };

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    _accounts = await _store.readAccounts();
    final cachedMessages = await _store.readMessageCache();
    for (final entry in cachedMessages.entries) {
      if (entry.key.contains(':detailHtml:')) {
        final message = entry.value.isEmpty ? null : entry.value.first;
        if (message != null) _messageDetailCache[entry.key] = message;
      } else if (entry.key.contains(':detail:')) {
        continue;
      } else if (entry.key.contains(':plainText:')) {
        final plain = entry.value.isEmpty ? null : entry.value.first.body;
        if (plain != null && plain.isNotEmpty) {
          _plainMessageCache[entry.key] = plain;
        }
      } else {
        _messageCache[entry.key] = entry.value;
      }
    }
    notifyListeners();
    _startPolling();
    unawaited(syncSuccessfulAccounts());
  }

  void setFilter(AccountFilter value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  void toggleFavorite(String accountId) {
    final account = accountById(accountId);
    if (account == null) return;
    _replaceAccount(account.copyWith(isFavorite: !account.isFavorite));
    unawaited(_persist());
    notifyListeners();
  }

  Future<void> importAccounts(String input) async {
    final parsed = _parser.parse(input);
    if (parsed.isEmpty) return;

    final latestByEmail = <String, MailAccount>{};
    final additions = <MailAccount>[];
    for (final account in parsed) {
      final normalized = account.email.trim().toLowerCase();
      if (normalized.isEmpty) {
        additions.add(account);
      } else {
        latestByEmail[normalized] = account;
      }
    }
    additions.addAll(latestByEmail.values);

    final replacementEmails = latestByEmail.keys.toSet();
    final replacedIds = _accounts
        .where(
          (account) =>
              replacementEmails.contains(account.email.trim().toLowerCase()),
        )
        .map((account) => account.id)
        .toSet();
    _messageCache.removeWhere(
      (key, _) => replacedIds.any((id) => key.startsWith('$id:')),
    );
    _messageDetailCache.removeWhere(
      (key, _) => replacedIds.any((id) => key.startsWith('$id:')),
    );

    _accounts = [
      ...additions,
      ..._accounts.where((account) => !replacedIds.contains(account.id)),
    ];
    _importing = true;
    notifyListeners();
    await _persist();
    await _persistMessageCache();

    final candidates = additions
        .where((account) => account.status == AccountStatus.validating)
        .toList();
    for (var offset = 0; offset < candidates.length; offset += 3) {
      final end = (offset + 3).clamp(0, candidates.length);
      await Future.wait(
        candidates.sublist(offset, end).map(_validateImportedAccount),
      );
    }
    _importing = false;
    notifyListeners();
  }

  Future<void> _validateImportedAccount(MailAccount account) async {
    try {
      final result = await _mailService.validateAccount(account);
      final updated = account.copyWith(
        refreshToken: result.refreshToken,
        status: AccountStatus.success,
        clearError: true,
        lastCheckedAt: DateTime.now(),
        unreadCount: result.messages.where((message) => !message.isRead).length,
      );
      _replaceAccount(updated);
      _messageCache[_cacheKey(account.id, MailFolder.inbox)] = result.messages;
      unawaited(_persistMessageCache());
    } on MailServiceException catch (error) {
      _replaceAccount(
        account.copyWith(
          status: AccountStatus.failed,
          errorMessage: error.message,
          lastCheckedAt: DateTime.now(),
        ),
      );
    } catch (error) {
      _replaceAccount(
        account.copyWith(
          status: AccountStatus.failed,
          errorMessage: '验证失败：$error',
          lastCheckedAt: DateTime.now(),
        ),
      );
    }
    await _persist();
    notifyListeners();
  }

  Future<void> retryAccount(String accountId) async {
    final account = accountById(accountId);
    if (account == null ||
        account.clientId.isEmpty ||
        account.refreshToken.isEmpty) {
      return;
    }
    final validating = account.copyWith(
      status: AccountStatus.validating,
      clearError: true,
    );
    _replaceAccount(validating);
    notifyListeners();
    await _validateImportedAccount(validating);
  }

  Future<void> syncSuccessfulAccounts() async {
    if (_syncingAll || !_isForeground) return;
    final successful = _accounts.where((account) => account.isUsable).toList();
    if (successful.isEmpty) return;
    _syncingAll = true;
    notifyListeners();
    try {
      for (var offset = 0; offset < successful.length; offset += 4) {
        final end = (offset + 4).clamp(0, successful.length);
        await Future.wait(
          successful
              .sublist(offset, end)
              .map(
                (account) =>
                    loadFolder(account.id, MailFolder.inbox, silent: true),
              ),
        );
      }
    } finally {
      _syncingAll = false;
      notifyListeners();
    }
  }

  Future<void> loadFolder(
    String accountId,
    MailFolder folder, {
    bool silent = false,
  }) async {
    final account = accountById(accountId);
    if (account == null || !account.isUsable) return;
    final key = _cacheKey(accountId, folder);
    if (_loadingFolders.contains(key)) return;
    _loadingFolders.add(key);
    if (!silent) notifyListeners();
    try {
      final result = await _mailService.fetchFolder(account, folder);
      _messageCache[key] = result.messages;
      unawaited(_persistMessageCache());
      _replaceAccount(
        account.copyWith(
          refreshToken: result.refreshToken,
          clearError: true,
          lastCheckedAt: DateTime.now(),
          unreadCount: folder == MailFolder.inbox
              ? result.messages.where((message) => !message.isRead).length
              : account.unreadCount,
        ),
      );
      await _persist();
    } on MailServiceException catch (error) {
      _replaceAccount(
        account.copyWith(
          errorMessage: error.message,
          lastCheckedAt: DateTime.now(),
        ),
      );
    } finally {
      _loadingFolders.remove(key);
      notifyListeners();
    }
  }

  Future<MailMessage> loadMessageDetail(
    String accountId,
    MailMessage message,
  ) async {
    final account = accountById(accountId);
    if (account == null) {
      throw const MailServiceException('账号不存在');
    }
    final detailKey = _detailCacheKey(accountId, message.id);
    final cached = _messageDetailCache[detailKey];
    if (cached != null && (cached.body?.trim().isNotEmpty ?? false)) {
      await markMessageRead(accountId, cached);
      return _messageDetailCache[detailKey] ?? cached;
    }

    await markMessageRead(accountId, message);
    final detail = await _mailService.fetchMessageDetail(account, message);
    final normalized = _messageDetailCache[detailKey]?.isRead == true
        ? detail.copyWith(isRead: true)
        : detail;
    _messageDetailCache[detailKey] = normalized;
    unawaited(_persistMessageCache());
    return normalized;
  }

  Future<String> loadPlainMessage(String accountId, MailMessage message) async {
    final plainKey = _plainCacheKey(accountId, message.id);
    final cached = _plainMessageCache[plainKey];
    if (cached != null && cached.isNotEmpty) return cached;
    final account = accountById(accountId);
    if (account == null) throw const MailServiceException('账号不存在');
    final plain = await _mailService.fetchPlainMessage(account, message);
    _plainMessageCache[plainKey] = plain;
    unawaited(_persistMessageCache());
    return plain;
  }

  Future<void> markMessageRead(String accountId, MailMessage message) async {
    if (message.isRead) return;
    final account = accountById(accountId);
    if (account == null) return;
    try {
      await _mailService.markMessageRead(account, message);
    } on MailServiceException {
      return;
    }

    final updated = message.copyWith(isRead: true);
    for (final entry in _messageCache.entries.toList()) {
      final index = entry.value.indexWhere((item) => item.id == message.id);
      if (index < 0) continue;
      final messages = [...entry.value]..[index] = updated;
      _messageCache[entry.key] = messages;
    }
    final detailKey = _detailCacheKey(accountId, message.id);
    final cachedDetail = _messageDetailCache[detailKey];
    if (cachedDetail != null) {
      _messageDetailCache[detailKey] = cachedDetail.copyWith(isRead: true);
    }
    _replaceAccount(
      account.copyWith(
        unreadCount: message.isRead
            ? account.unreadCount
            : (account.unreadCount - 1).clamp(0, 1 << 30).toInt(),
      ),
    );
    await _persist();
    await _persistMessageCache();
    notifyListeners();
  }

  Future<void> markMessagesRead(
    String accountId,
    Iterable<MailMessage> messages,
  ) async {
    for (final message in messages) {
      if (!message.isRead) await markMessageRead(accountId, message);
    }
  }

  Future<void> markAllMessagesReadForAccounts(
    Iterable<String> accountIds,
  ) async {
    for (final accountId in accountIds) {
      final messages = <String, MailMessage>{};
      for (final folder in MailFolder.values) {
        for (final message in messagesFor(accountId, folder)) {
          messages[message.id] = message;
        }
      }
      await markMessagesRead(accountId, messages.values);
    }
  }

  Future<void> deleteMessages(
    String accountId,
    Iterable<MailMessage> messages,
  ) async {
    final account = accountById(accountId);
    if (account == null) return;
    for (final message in messages) {
      try {
        await deleteMessage(accountId, message);
      } on MailServiceException {
        continue;
      }
    }
  }

  Future<void> deleteMessage(String accountId, MailMessage message) async {
    final account = accountById(accountId);
    if (account == null) {
      throw const MailServiceException('账号不存在');
    }
    await _mailService.deleteMessage(account, message);
    var foundCachedMessage = false;
    var cachedRead = false;
    var cachedUnread = false;
    for (final entry in _messageCache.entries.toList()) {
      final cached = entry.value.where((item) => item.id == message.id);
      if (cached.isNotEmpty) {
        foundCachedMessage = true;
        cachedRead = cachedRead || cached.any((item) => item.isRead);
        cachedUnread = cachedUnread || cached.any((item) => !item.isRead);
      }
      _messageCache[entry.key] = entry.value
          .where((item) => item.id != message.id)
          .toList();
    }
    final detailKey = _detailCacheKey(accountId, message.id);
    final cachedDetail = _messageDetailCache[detailKey];
    if (cachedDetail != null) {
      foundCachedMessage = true;
      cachedRead = cachedRead || cachedDetail.isRead;
      cachedUnread = cachedUnread || !cachedDetail.isRead;
    }
    final wasUnread = foundCachedMessage
        ? cachedUnread && !cachedRead
        : !message.isRead;
    _messageDetailCache.remove(detailKey);
    _plainMessageCache.remove(_plainCacheKey(accountId, message.id));
    if (wasUnread) {
      _replaceAccount(
        account.copyWith(
          unreadCount: (account.unreadCount - 1).clamp(0, 1 << 30).toInt(),
        ),
      );
    }
    await _persist();
    await _persistMessageCache();
    notifyListeners();
  }

  List<MailMessage> messagesFor(String accountId, MailFolder folder) {
    return List.unmodifiable(
      _messageCache[_cacheKey(accountId, folder)] ?? const [],
    );
  }

  bool isFolderLoading(String accountId, MailFolder folder) {
    return _loadingFolders.contains(_cacheKey(accountId, folder));
  }

  MailAccount? accountById(String id) {
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  MailAccount? removeAccount(String id) {
    final index = _accounts.indexWhere((account) => account.id == id);
    if (index < 0) return null;
    final removed = _accounts[index];
    _accounts = [..._accounts]..removeAt(index);
    _messageCache.removeWhere((key, _) => key.startsWith('$id:'));
    _messageDetailCache.removeWhere((key, _) => key.startsWith('$id:'));
    unawaited(_persist());
    unawaited(_persistMessageCache());
    notifyListeners();
    return removed;
  }

  void restoreAccount(MailAccount account) {
    _accounts = [account, ..._accounts];
    unawaited(_persist());
    notifyListeners();
  }

  List<MailAccount> accountsForFilter(AccountFilter value) => switch (value) {
    AccountFilter.favorite =>
      _accounts.where((account) => account.isFavorite).toList(),
    AccountFilter.success =>
      _accounts
          .where((account) => account.status == AccountStatus.success)
          .toList(),
    AccountFilter.failed =>
      _accounts
          .where((account) => account.status == AccountStatus.failed)
          .toList(),
    AccountFilter.all => List.of(_accounts),
  };

  void _replaceAccount(MailAccount updated) {
    final index = _accounts.indexWhere((account) => account.id == updated.id);
    if (index < 0) return;
    _accounts = [..._accounts]..[index] = updated;
  }

  Future<void> _persist() => _store.writeAccounts(_accounts);

  String _cacheKey(String accountId, MailFolder folder) =>
      '$accountId:${folder.name}';

  String _detailCacheKey(String accountId, String messageId) =>
      '$accountId:detailHtml:$messageId';

  String _plainCacheKey(String accountId, String messageId) =>
      '$accountId:plainText:$messageId';

  Future<void> _persistMessageCache() {
    final cache = <String, List<MailMessage>>{..._messageCache};
    for (final entry in _messageDetailCache.entries) {
      cache[entry.key] = [entry.value];
    }
    for (final entry in _plainMessageCache.entries) {
      cache[entry.key] = [
        MailMessage(
          id: entry.key.split(':').last,
          folder: MailFolder.inbox,
          subject: '纯文本正文',
          sender: '',
          recipients: '',
          receivedAt: null,
          isRead: true,
          hasAttachments: false,
          preview: '',
          body: entry.value,
        ),
      ];
    }
    return _store.writeMessageCache(cache);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(syncSuccessfulAccounts()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      _startPolling();
      unawaited(syncSuccessfulAccounts());
    } else {
      _pollTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }
}
