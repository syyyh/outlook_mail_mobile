import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../models/mail_account.dart';
import '../models/mail_message.dart';

class MailServiceException implements Exception {
  const MailServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

class MailFetchResult {
  const MailFetchResult({required this.messages, required this.refreshToken});

  final List<MailMessage> messages;
  final String refreshToken;
}

class ValidationResult extends MailFetchResult {
  const ValidationResult({
    required super.messages,
    required super.refreshToken,
  });
}

class _TokenSession {
  const _TokenSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool get isFresh =>
      expiresAt.isAfter(DateTime.now().add(const Duration(minutes: 1)));
}

class MicrosoftMailService {
  MicrosoftMailService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 20),
              validateStatus: (_) => true,
            ),
          );

  static const _tokenUrl =
      'https://login.microsoftonline.com/common/oauth2/v2.0/token';
  static const _graphRoot = 'https://graph.microsoft.com/v1.0';
  static const _scopeCandidates = [
    'https://graph.microsoft.com/Mail.Read https://graph.microsoft.com/Mail.ReadWrite offline_access',
    'https://graph.microsoft.com/Mail.Read offline_access',
    'https://graph.microsoft.com/.default',
  ];

  final Dio _dio;
  final Map<String, _TokenSession> _sessions = {};

  Future<ValidationResult> validateAccount(MailAccount account) async {
    _sessions.remove(account.id);
    final result = await fetchFolder(account, MailFolder.inbox, top: 20);
    return ValidationResult(
      messages: result.messages,
      refreshToken: result.refreshToken,
    );
  }

  Future<MailFetchResult> fetchFolder(
    MailAccount account,
    MailFolder folder, {
    int top = 50,
  }) async {
    var session = await _ensureToken(account);
    for (var attempt = 0; attempt < 2; attempt++) {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_graphRoot/me/mailFolders/${folder.graphName}/messages',
        queryParameters: {
          r'$top': math.max(1, math.min(top, 50)),
          r'$select':
              'id,subject,from,toRecipients,receivedDateTime,isRead,hasAttachments,bodyPreview',
          r'$orderby': 'receivedDateTime desc',
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Prefer': "outlook.body-content-type='text'",
          },
        ),
      );

      if (response.statusCode == 200) {
        final values = response.data?['value'] as List? ?? const [];
        final messages = values
            .whereType<Map>()
            .map(
              (item) => MailMessage.fromGraph(
                Map<String, dynamic>.from(item),
                folder,
              ),
            )
            .where((message) => message.id.isNotEmpty)
            .toList();
        return MailFetchResult(
          messages: messages,
          refreshToken: session.refreshToken,
        );
      }

      if (response.statusCode == 401 && attempt == 0) {
        _sessions.remove(account.id);
        session = await _ensureToken(
          account.copyWith(refreshToken: session.refreshToken),
        );
        continue;
      }
      throw MailServiceException(_graphError(response));
    }
    throw const MailServiceException('邮件请求失败');
  }

  Future<MailMessage> fetchMessageDetail(
    MailAccount account,
    MailMessage message,
  ) async {
    final session = await _ensureToken(account);
    final response = await _dio.get<Map<String, dynamic>>(
      '$_graphRoot/me/messages/${Uri.encodeComponent(message.id)}',
      queryParameters: {
        r'$select':
            'id,subject,from,toRecipients,receivedDateTime,isRead,hasAttachments,body,bodyPreview',
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Prefer': "outlook.body-content-type='html'",
        },
      ),
    );
    if (response.statusCode != 200 || response.data == null) {
      throw MailServiceException(_graphError(response));
    }
    return MailMessage.fromGraph(response.data!, message.folder);
  }

  Future<String> fetchPlainMessage(
    MailAccount account,
    MailMessage message,
  ) async {
    var session = await _ensureToken(account);
    for (var attempt = 0; attempt < 2; attempt++) {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_graphRoot/me/messages/${Uri.encodeComponent(message.id)}',
        queryParameters: {r'$select': 'id,body,bodyPreview'},
        options: Options(
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Prefer': "outlook.body-content-type='text'",
          },
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        final body = response.data!['body'];
        if (body is Map &&
            body['content']?.toString().trim().isNotEmpty == true) {
          return _normalizePlainText(body['content'].toString());
        }
        return _normalizePlainText(
          response.data!['bodyPreview']?.toString() ?? '',
        );
      }
      if (response.statusCode == 401 && attempt == 0) {
        _sessions.remove(account.id);
        session = await _ensureToken(
          account.copyWith(refreshToken: session.refreshToken),
        );
        continue;
      }
      throw MailServiceException(_graphError(response));
    }
    throw const MailServiceException('获取纯文本正文失败');
  }

  String _normalizePlainText(String value) {
    return value.replaceAllMapped(
      RegExp(r'<(https?://[^>\s]+)>', caseSensitive: false),
      (match) => match.group(1) ?? '',
    );
  }

  Future<void> markMessageRead(MailAccount account, MailMessage message) async {
    var session = await _ensureToken(account);
    for (var attempt = 0; attempt < 2; attempt++) {
      final response = await _dio.patch<Map<String, dynamic>>(
        '$_graphRoot/me/messages/${Uri.encodeComponent(message.id)}',
        data: const {'isRead': true},
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        ),
      );
      if (response.statusCode == 200 ||
          response.statusCode == 202 ||
          response.statusCode == 204) {
        return;
      }
      if (response.statusCode == 401 && attempt == 0) {
        _sessions.remove(account.id);
        session = await _ensureToken(
          account.copyWith(refreshToken: session.refreshToken),
        );
        continue;
      }
      throw MailServiceException(_graphError(response));
    }
    throw const MailServiceException('标记邮件已读失败');
  }

  Future<void> deleteMessage(MailAccount account, MailMessage message) async {
    var session = await _ensureToken(account);
    for (var attempt = 0; attempt < 2; attempt++) {
      final response = await _dio.delete<void>(
        '$_graphRoot/me/messages/${Uri.encodeComponent(message.id)}',
        options: Options(
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        ),
      );
      if (response.statusCode == 200 ||
          response.statusCode == 202 ||
          response.statusCode == 204) {
        return;
      }
      if (response.statusCode == 401 && attempt == 0) {
        _sessions.remove(account.id);
        session = await _ensureToken(
          account.copyWith(refreshToken: session.refreshToken),
        );
        continue;
      }
      throw MailServiceException(_graphError(response));
    }
    throw const MailServiceException('删除邮件失败');
  }

  Future<_TokenSession> _ensureToken(MailAccount account) async {
    final cached = _sessions[account.id];
    if (cached != null && cached.isFresh) return cached;
    final token = await _exchangeRefreshToken(account);
    _sessions[account.id] = token;
    return token;
  }

  Future<_TokenSession> _exchangeRefreshToken(MailAccount account) async {
    String lastError = '无法获取访问令牌';
    for (final scope in _scopeCandidates) {
      Response<Map<String, dynamic>> response;
      try {
        response = await _dio.post<Map<String, dynamic>>(
          _tokenUrl,
          data: {
            'client_id': account.clientId,
            'grant_type': 'refresh_token',
            'refresh_token': account.refreshToken,
            'scope': scope,
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
      } on DioException catch (error) {
        throw MailServiceException(_networkError(error));
      }

      final data = response.data ?? const <String, dynamic>{};
      final accessToken = data['access_token']?.toString() ?? '';
      if (response.statusCode == 200 && accessToken.isNotEmpty) {
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
        return _TokenSession(
          accessToken: accessToken,
          refreshToken:
              data['refresh_token']?.toString().trim().isNotEmpty == true
              ? data['refresh_token'].toString().trim()
              : account.refreshToken,
          expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
        );
      }
      lastError =
          data['error_description']?.toString() ??
          data['error']?.toString() ??
          'Token 请求失败 (${response.statusCode})';
    }
    throw MailServiceException(_cleanMicrosoftError(lastError));
  }

  String _graphError(Response<dynamic> response) {
    final data = response.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map && error['message'] != null) {
        return _cleanMicrosoftError(error['message'].toString());
      }
    }
    return 'Microsoft Graph 请求失败 (${response.statusCode})';
  }

  String _networkError(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout => '连接 Microsoft 超时',
      DioExceptionType.connectionError => '无法连接 Microsoft，请检查网络',
      _ => '网络请求失败：${error.message ?? '未知错误'}',
    };
  }

  String _cleanMicrosoftError(String value) {
    final firstLine = value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    return firstLine.length > 180
        ? '${firstLine.substring(0, 180)}…'
        : firstLine;
  }
}
