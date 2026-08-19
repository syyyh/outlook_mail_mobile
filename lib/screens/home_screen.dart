import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../controllers/mail_controller.dart';
import '../models/mail_account.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_account_list.dart';
import '../widgets/status_segmented_control.dart';
import 'mailbox_screen.dart';
import 'about_screen.dart';
import 'details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final MailController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _exportService = ExportService();
  late final PageController _headerPageController;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  final Set<String> _selectedAccountIds = <String>{};
  bool _selectionMode = false;
  bool _searchMode = false;
  String _searchQuery = '';
  bool _headerVisible = true;

  static const _filterOrder = [
    AccountFilter.favorite,
    AccountFilter.success,
    AccountFilter.all,
    AccountFilter.failed,
  ];

  @override
  void initState() {
    super.initState();
    _headerPageController = PageController();
    _searchFocusNode = FocusNode();
    _searchController = TextEditingController()
      ..addListener(() {
        if (mounted) {
          setState(() => _searchQuery = _searchController.text.trim());
        }
      });
  }

  @override
  void dispose() {
    _headerPageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return PopScope<void>(
          canPop: !_selectionMode && !_searchMode,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_selectionMode) {
              _exitSelection();
            } else if (_searchMode) {
              _closeSearch();
            }
          },
          child: Scaffold(
            key: _scaffoldKey,
            resizeToAvoidBottomInset: false,
            drawer: _SettingsDrawer(onExport: _showExportSheet),
            backgroundColor: AppColors.canvas,
            body: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _handleScrollNotification,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragEnd: (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          if (velocity.abs() < 250) return;
                          final current = _filterOrder.indexOf(
                            widget.controller.filter,
                          );
                          final direction = velocity < 0 ? 1 : -1;
                          final next = (current + direction).clamp(
                            0,
                            _filterOrder.length - 1,
                          );
                          if (next != current) {
                            _selectFilter(_filterOrder[next]);
                          }
                        },
                        child: _buildAccountPage(),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 14,
                    right: 14,
                    child: _buildFloatingHeader(),
                  ),
                  Positioned(
                    right: 18,
                    bottom: 24,
                    child: IgnorePointer(
                      ignoring: !_selectionMode,
                      child: AnimatedScale(
                        scale: _selectionMode ? 1 : 0.7,
                        duration: const Duration(milliseconds: 180),
                        child: AnimatedOpacity(
                          opacity: _selectionMode ? 1 : 0,
                          duration: const Duration(milliseconds: 160),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _CircleAction(
                                icon: _isAllAccountsSelected()
                                    ? Icons.deselect
                                    : Icons.select_all,
                                tooltip: _isAllAccountsSelected()
                                    ? '取消全选'
                                    : '全选',
                                onPressed: _toggleSelectAllAccounts,
                              ),
                              const SizedBox(height: 12),
                              _CircleAction(
                                icon: Icons.more_horiz,
                                tooltip: '批量操作',
                                accent: true,
                                onPressed: _showSelectionActions,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse &&
          notification.metrics.pixels > 12) {
        _setHeaderVisibility(false);
      } else if (notification.direction == ScrollDirection.forward) {
        _setHeaderVisibility(true);
      }
    } else if (notification is OverscrollNotification &&
        notification.metrics.pixels <= 0) {
      _setHeaderVisibility(true);
    }
    return false;
  }

  void _setHeaderVisibility(bool visible) {
    if (_headerVisible == visible || !mounted) return;
    setState(() => _headerVisible = visible);
  }

  Widget _buildFloatingHeader() {
    return IgnorePointer(
      ignoring: !_headerVisible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: _headerVisible ? Offset.zero : const Offset(0, -1.15),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          opacity: _headerVisible ? 1 : 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    _CircleAction(
                      icon: Icons.settings_outlined,
                      tooltip: '设置',
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _selectionMode
                          ? _SelectionSummary(
                              count: _selectedAccountIds.length,
                              onClose: _exitSelection,
                            )
                          : SizedBox(
                              height: 42,
                              child: PageView(
                                controller: _headerPageController,
                                onPageChanged: _handleHeaderPageChanged,
                                children: [
                                  StatusSegmentedControl(
                                    value: widget.controller.filter,
                                    onChanged: _selectFilter,
                                  ),
                                  _SearchControl(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    _CircleAction(
                      icon: Icons.add,
                      tooltip: '批量添加邮箱',
                      accent: true,
                      busy:
                          widget.controller.syncingAll ||
                          widget.controller.importing,
                      onPressed: _showImportSheet,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectFilter(AccountFilter filter) {
    _setHeaderVisibility(true);
    widget.controller.setFilter(filter);
  }

  Widget _buildAccountPage() {
    final query = _searchQuery.toLowerCase();
    final source = _searchMode
        ? widget.controller.accounts
        : widget.controller.filteredAccounts;
    final accounts = source
        .where(
          (account) =>
              query.isEmpty || account.email.toLowerCase().contains(query),
        )
        .toList();
    if (accounts.isEmpty) {
      return _EmptyAccounts(
        filter: widget.controller.filter,
        onAdd: _showImportSheet,
      );
    }
    return AnimatedAccountList(
      accounts: accounts,
      onRefresh: widget.controller.syncSuccessfulAccounts,
      onTap: _handleAccountTap,
      onRetry: (account) => widget.controller.retryAccount(account.id),
      onLongPress: _enterSelection,
      selectionMode: _selectionMode,
      selectedIds: _selectedAccountIds,
    );
  }

  void _handleHeaderPageChanged(int page) {
    final search = page == 1;
    setState(() => _searchMode = search);
    if (search) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    } else {
      _searchFocusNode.unfocus();
      _searchController.clear();
    }
  }

  void _closeSearch() {
    if (!_searchMode) return;
    _headerPageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleAccountTap(MailAccount account) {
    if (!_selectionMode) {
      _openMailbox(account);
      return;
    }
    setState(() {
      if (!_selectedAccountIds.add(account.id)) {
        _selectedAccountIds.remove(account.id);
      }
    });
  }

  void _enterSelection(MailAccount account) {
    setState(() {
      _selectionMode = true;
      _selectedAccountIds.add(account.id);
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedAccountIds.clear();
    });
  }

  List<MailAccount> _visibleAccounts() {
    final query = _searchQuery.toLowerCase();
    final source = _searchMode
        ? widget.controller.accounts
        : widget.controller.filteredAccounts;
    return source
        .where(
          (account) =>
              query.isEmpty || account.email.toLowerCase().contains(query),
        )
        .toList();
  }

  bool _isAllAccountsSelected() {
    final accounts = _visibleAccounts();
    return accounts.isNotEmpty &&
        accounts.every((account) => _selectedAccountIds.contains(account.id));
  }

  void _toggleSelectAllAccounts() {
    final accounts = _visibleAccounts();
    setState(() {
      if (_isAllAccountsSelected()) {
        _selectedAccountIds.removeAll(accounts.map((account) => account.id));
      } else {
        _selectedAccountIds.addAll(accounts.map((account) => account.id));
      }
    });
  }

  Future<void> _showSelectionActions() async {
    if (_selectedAccountIds.isEmpty) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: Text('导出所选 (${_selectedAccountIds.length})'),
              onTap: () => Navigator.pop(context, 'export'),
            ),
            ListTile(
              leading: const Icon(Icons.mark_email_read_outlined),
              title: const Text('全部标记已读'),
              onTap: () => Navigator.pop(context, 'read'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('删除所选'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final selected = widget.controller.accounts
        .where((account) => _selectedAccountIds.contains(account.id))
        .toList();
    if (action == 'read') {
      await widget.controller.markAllMessagesReadForAccounts(
        selected.map((account) => account.id),
      );
      if (mounted) _exitSelection();
      return;
    }
    if (action == 'export') {
      try {
        await _exportService.exportAccounts(selected, category: 'selected');
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
      if (mounted) _exitSelection();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除所选账号？'),
        content: Text('将删除 ${selected.length} 个本地账号及其缓存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      for (final account in selected) {
        widget.controller.removeAccount(account.id);
      }
      if (mounted) _exitSelection();
    }
  }

  void _openMailbox(MailAccount account) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MailboxScreen(controller: widget.controller, accountId: account.id),
      ),
    );
  }

  Future<void> _showImportSheet() async {
    final input = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      requestFocus: false,
      backgroundColor: AppColors.surface,
      barrierColor: const Color(0x61202825),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const RepaintBoundary(child: _ImportSheet()),
    );
    if (input != null && mounted) {
      await widget.controller.importAccounts(input);
    }
  }

  Future<void> _showExportSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      barrierColor: const Color(0x61202825),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '导出账号',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _ExportOption(
                icon: Icons.description_outlined,
                title: '导出全部',
                subtitle: '导出当前列表中的所有账号',
                count: widget.controller.accounts.length,
                onTap: () => _export(AccountFilter.all, 'all'),
              ),
              _ExportOption(
                icon: Icons.check_circle_outline,
                title: '导出成功',
                subtitle: '仅导出已成功连接的账号',
                count: widget.controller.successCount,
                onTap: () => _export(AccountFilter.success, 'success'),
              ),
              _ExportOption(
                icon: Icons.error_outline,
                title: '导出失败',
                subtitle: '仅导出验证失败的账号',
                count: widget.controller.failedCount,
                failed: true,
                onTap: () => _export(AccountFilter.failed, 'failed'),
              ),
              const SizedBox(height: 6),
              const Text(
                '按当前状态导出为文本文件',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export(AccountFilter filter, String category) async {
    Navigator.pop(context);
    try {
      await _exportService.exportAccounts(
        widget.controller.accountsForFilter(filter),
        category: category,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }
}

class _ImportSheet extends StatefulWidget {
  const _ImportSheet();

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  final _textController = TextEditingController();
  late final Widget _content;

  @override
  void initState() {
    super.initState();
    _content = _ImportSheetContent(controller: _textController);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetKeyboardPadding(child: _content);
  }
}

class _SheetKeyboardPadding extends StatelessWidget {
  const _SheetKeyboardPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: RepaintBoundary(child: child),
      ),
    );
  }
}

class _ImportSheetContent extends StatelessWidget {
  const _ImportSheetContent({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetHandle(),
        Row(
          children: [
            const Expanded(
              child: Text(
                '批量导入',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: '关闭',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '每行一个账号，支持批量解析和一次验证',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 210,
          child: TextField(
            controller: controller,
            expands: true,
            maxLines: null,
            minLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              height: 1.65,
            ),
            decoration: InputDecoration(
              hintText:
                  '每行一个账号\nemail----password----client_id----refresh_token',
              hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFFAFCF9),
              contentPadding: const EdgeInsets.all(14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.accent,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(context, value);
              }
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('添加并验证'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 54,
        height: 5,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFC6CFCA),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _SearchControl extends StatelessWidget {
  const _SearchControl({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.line),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: '搜索邮箱',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: IconButton(
            tooltip: '清空搜索',
            onPressed: controller.clear,
            icon: const Icon(Icons.close, size: 18),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({required this.count, required this.onClose});

  final int count;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.line),
      ),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            IconButton(
              tooltip: '退出多选',
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 19),
            ),
            Expanded(
              child: Text(
                '已选择 $count 个账号',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 42),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.accent = false,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool accent;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: accent ? AppColors.accentSoft : AppColors.surfaceSecondary,
        shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (busy)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(1.5),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(
                          accent ? AppColors.accent : AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                Icon(
                  icon,
                  size: 21,
                  color: accent ? AppColors.accent : AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsDrawer extends StatelessWidget {
  const _SettingsDrawer({required this.onExport});

  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 320,
      backgroundColor: AppColors.surface,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(22, 28, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '设置',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            const Text(
              '本地邮箱',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.ios_share_outlined,
                color: AppColors.accent,
              ),
              title: const Text('导出账号'),
              subtitle: const Text('导出全部、成功或失败账号'),
              onTap: () {
                Navigator.pop(context);
                onExport();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.lightbulb_outline,
                color: AppColors.accent,
              ),
              title: const Text('小细节'),
              subtitle: const Text('查看不明显的手势和缓存功能'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DetailsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline, color: AppColors.accent),
              title: const Text('关于'),
              subtitle: const Text('技术栈、隐私和使用声明'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts({required this.filter, required this.onAdd});

  final AccountFilter filter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final isAll = filter == AccountFilter.all;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAll ? Icons.mark_email_unread_outlined : Icons.filter_alt_off,
              color: AppColors.accent,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              isAll ? '还没有邮箱' : '当前分类为空',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isAll) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('批量添加'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  const _ExportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.onTap,
    this.failed = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final VoidCallback onTap;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final color = failed ? AppColors.error : AppColors.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: count > 0 ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  color: count > 0 ? AppColors.text : AppColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
