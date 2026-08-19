import 'package:flutter_test/flutter_test.dart';
import 'package:outlook_mail_mobile/models/mail_account.dart';
import 'package:outlook_mail_mobile/services/account_parser.dart';

void main() {
  const clientId = '24d9a0ed-8787-4584-883c-2fd79308940a';

  test('parses the standard Outlook account order', () {
    final result = AccountImportParser().parse(
      'user@outlook.com----password----$clientId----refresh-token',
    );

    expect(result, hasLength(1));
    expect(result.single.clientId, clientId);
    expect(result.single.refreshToken, 'refresh-token');
    expect(result.single.status, AccountStatus.validating);
  });

  test('detects reversed refresh token and client id columns', () {
    final result = AccountImportParser().parse(
      'user@outlook.com----password----refresh-token----$clientId',
    );

    expect(result.single.clientId, clientId);
    expect(result.single.refreshToken, 'refresh-token');
  });

  test('keeps malformed source lines for failed export', () {
    final result = AccountImportParser().parse('broken----line');

    expect(result.single.status, AccountStatus.failed);
    expect(result.single.exportLine, 'broken----line');
  });

  test('parses multiple non-empty lines', () {
    final result = AccountImportParser().parse('''
one@outlook.com----p1----$clientId----r1

two@outlook.com----p2----r2----$clientId
''');

    expect(result, hasLength(2));
    expect(result.map((item) => item.email), [
      'one@outlook.com',
      'two@outlook.com',
    ]);
  });
}
