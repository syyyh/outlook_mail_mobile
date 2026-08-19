import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DetailsScreen extends StatelessWidget {
  const DetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InfoPage(
      title: '小细节',
      eyebrow: '使用提示',
      sections: [
        _InfoSection(
          icon: Icons.swipe_outlined,
          title: '切换邮件正文',
          body: '邮件详情默认显示纯文本。向左滑动进入渲染邮件，向右滑动返回纯文本。渲染邮件内部可独立上下滑动。',
        ),
        _InfoSection(
          icon: Icons.touch_app_outlined,
          title: '长按进入多选',
          body: '首页长按邮箱，邮件列表长按邮件，可进入多选模式。选择器里的全选、已读、删除和导出会针对当前页面生效。',
        ),
        _InfoSection(
          icon: Icons.search_outlined,
          title: '搜索栏的切换',
          body: '首页顶部中间区域左右滑动可以在邮箱筛选和邮箱搜索之间切换，不需要额外占用一行空间。',
        ),
        _InfoSection(
          icon: Icons.cached_outlined,
          title: '缓存与刷新',
          body: '邮件正文成功读取后会缓存在本地。打开应用会轮询成功账号，刷新期间仍然可以导入账号。',
        ),
      ],
    );
  }
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({
    required this.title,
    required this.eyebrow,
    required this.sections,
  });

  final String title;
  final String eyebrow;
  final List<_InfoSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: section,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 22),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
