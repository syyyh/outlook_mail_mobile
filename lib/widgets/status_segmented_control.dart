import 'package:flutter/material.dart';

import '../controllers/mail_controller.dart';
import '../theme/app_theme.dart';

class StatusSegmentedControl extends StatelessWidget {
  const StatusSegmentedControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AccountFilter value;
  final ValueChanged<AccountFilter> onChanged;

  static const _items = [
    (AccountFilter.favorite, '收藏'),
    (AccountFilter.success, '成功'),
    (AccountFilter.all, '全部'),
    (AccountFilter.failed, '失败'),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _items.indexWhere((item) => item.$1 == value);
    return Material(
      color: AppColors.surfaceSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.line),
      ),
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(3),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / _items.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: itemWidth * selectedIndex,
                  top: 0,
                  bottom: 0,
                  width: itemWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                ),
                Row(
                  children: _items.map((item) {
                    final selected = item.$1 == value;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: selected,
                        label: '${item.$2}账号',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(19),
                          onTap: () => onChanged(item.$1),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              style: TextStyle(
                                color: selected
                                    ? AppColors.accent
                                    : AppColors.muted,
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              child: Text(item.$2),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
