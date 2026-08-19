import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/mail_account.dart';

class ExportService {
  Future<void> exportAccounts(
    List<MailAccount> accounts, {
    required String category,
  }) async {
    if (accounts.isEmpty) {
      throw StateError('当前分类没有可导出的账号');
    }
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File('${directory.path}/outlook_${category}_$timestamp.txt');
    await file.writeAsString(
      '${accounts.map((account) => account.exportLine).join('\n')}\n',
      flush: true,
    );
    await SharePlus.instance.share(
      ShareParams(
        title: '导出邮箱账号',
        subject: 'Outlook 邮箱账号导出',
        files: [XFile(file.path, mimeType: 'text/plain')],
        fileNameOverrides: [file.uri.pathSegments.last],
      ),
    );
  }
}
