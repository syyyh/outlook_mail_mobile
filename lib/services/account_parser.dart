import '../models/mail_account.dart';

class AccountImportParser {
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  List<MailAccount> parse(String input) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final lines = input.split(RegExp(r'\r?\n'));
    final accounts = <MailAccount>[];

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (line.isEmpty) continue;
      final parts = line.split('----').map((part) => part.trim()).toList();
      final id = '$now-$index';

      if (parts.length < 4 || parts.first.isEmpty) {
        accounts.add(
          MailAccount(
            id: id,
            email: parts.isEmpty ? '' : parts.first,
            password: parts.length > 1 ? parts[1] : '',
            clientId: '',
            refreshToken: '',
            rawLine: line,
            status: AccountStatus.failed,
            errorMessage: '格式错误，需要四段内容',
          ),
        );
        continue;
      }

      final third = parts[2];
      final fourth = parts[3];
      final thirdIsClientId = _uuidPattern.hasMatch(third);
      final fourthIsClientId = _uuidPattern.hasMatch(fourth);
      final clientId = fourthIsClientId && !thirdIsClientId ? fourth : third;
      final refreshToken = fourthIsClientId && !thirdIsClientId
          ? third
          : fourth;
      final email = parts[0];
      final looksValid =
          email.contains('@') && clientId.isNotEmpty && refreshToken.isNotEmpty;

      accounts.add(
        MailAccount(
          id: id,
          email: email,
          password: parts[1],
          clientId: clientId,
          refreshToken: refreshToken,
          rawLine: line,
          status: looksValid ? AccountStatus.validating : AccountStatus.failed,
          errorMessage: looksValid ? null : '邮箱、Client ID 或 Refresh Token 无效',
        ),
      );
    }
    return accounts;
  }
}
