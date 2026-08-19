import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
        children: const [
          _AboutHeader(),
          SizedBox(height: 14),
          _AboutBlock(
            title: '技术栈',
            icon: Icons.code_outlined,
            lines: [
              'Flutter / Dart：跨平台界面与本地状态管理',
              'Microsoft Graph API：读取邮件、标记已读和删除邮件',
              'WebView：隔离渲染 HTML 邮件正文',
              'flutter_secure_storage：本地保存账号令牌',
              'Dio：网络请求、令牌刷新和错误处理',
            ],
          ),
          SizedBox(height: 12),
          _AboutBlock(
            title: '隐私与声明',
            icon: Icons.shield_outlined,
            lines: [
              '本应用仅供个人本地使用，不提供服务器中转。',
              '账号、刷新令牌和邮件缓存只保存在本机应用存储中。',
              'HTML 邮件会经过标签和链接白名单过滤后再渲染。',
              '应用与 Microsoft、Crypton Future Media 及初音未来官方没有隶属或授权关系。',
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本地邮箱',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '一个面向自用场景的 Outlook 邮件查看工具。',
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _AboutBlock extends StatelessWidget {
  const _AboutBlock({
    required this.title,
    required this.icon,
    required this.lines,
  });

  final String title;
  final IconData icon;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 21),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '· $line',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
