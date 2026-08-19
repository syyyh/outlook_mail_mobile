import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/mail_controller.dart';
import '../models/mail_account.dart';
import '../models/mail_message.dart';
import '../theme/app_theme.dart';
import 'mail_detail_screen.dart';

class MailboxScreen extends StatefulWidget {
  const MailboxScreen({
    super.key,
    required this.controller,
    required this.accountId,
  });

  final MailController controller;
  final String accountId;

  @override
  State<MailboxScreen> createState() => _MailboxScreenState();
}

class _MailboxScreenState extends State<MailboxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _folders = MailFolder.values;
  final Set<String> _selectedMessageIds = <String>{};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _folders.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadFolder(widget.accountId, MailFolder.inbox);
    });
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    if (_selectionMode) _exitSelection();
    widget.controller.loadFolder(
      widget.accountId,
      _folders[_tabController.index],
    );
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final account = widget.controller.accountById(widget.accountId);
        if (account == null) {
          return const Scaffold(
            backgroundColor: AppColors.canvas,
            body: Center(child: Text('账号已删除')),
          );
        }
        return PopScope<void>(
          canPop: !_selectionMode,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _selectionMode) _exitSelection();
          },
          child: Scaffold(
            backgroundColor: AppColors.canvas,
            body: Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                        child: Row(
                          children: [
                            _RoundIconButton(
                              icon: Icons.arrow_back,
                              tooltip: '返回',
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onLongPress: () =>
                                    _showCredentialSheet(account),
                                child: Hero(
                                  tag: 'account-email-${account.id}',
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: Text(
                                      account.email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _RoundIconButton(
                              icon: account.isFavorite
                                  ? Icons.star
                                  : Icons.star_border,
                              tooltip: account.isFavorite ? '取消收藏' : '收藏账号',
                              accent: true,
                              onPressed: () =>
                                  widget.controller.toggleFavorite(account.id),
                            ),
                          ],
                        ),
                      ),
                      TabBar(
                        controller: _tabController,
                        labelColor: AppColors.accent,
                        unselectedLabelColor: AppColors.muted,
                        labelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        indicatorColor: AppColors.accent,
                        indicatorWeight: 3,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: AppColors.line,
                        tabs: const [
                          Tab(text: '收件箱'),
                          Tab(text: '垃圾邮件'),
                          Tab(text: '已删除'),
                        ],
                      ),
                      if (account.errorMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          color: AppColors.errorSoft,
                          child: Text(
                            account.errorMessage!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: _folders
                              .map(
                                (folder) => _FolderView(
                                  controller: widget.controller,
                                  accountId: account.id,
                                  folder: folder,
                                  selectionMode: _selectionMode,
                                  selectedMessageIds: _selectedMessageIds,
                                  onTapMessage: _handleMessageTap,
                                  onLongPressMessage: _enterSelection,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 18,
                  bottom: 24,
                  child: IgnorePointer(
                    ignoring: !_selectionMode,
                    child: AnimatedSlide(
                      offset: _selectionMode ? Offset.zero : const Offset(0, 1),
                      duration: const Duration(milliseconds: 180),
                      child: AnimatedOpacity(
                        opacity: _selectionMode ? 1 : 0,
                        duration: const Duration(milliseconds: 160),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _RoundIconButton(
                              icon: _isAllSelected()
                                  ? Icons.deselect
                                  : Icons.select_all,
                              tooltip: _isAllSelected() ? '取消全选' : '全选',
                              accent: false,
                              onPressed: _toggleSelectAll,
                            ),
                            const SizedBox(height: 12),
                            _RoundIconButton(
                              icon: Icons.more_horiz,
                              tooltip: '邮件批量操作',
                              accent: true,
                              onPressed: _showMessageActions,
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
        );
      },
    );
  }

  void _enterSelection(MailMessage message) {
    setState(() {
      _selectionMode = true;
      _selectedMessageIds.add(message.id);
    });
  }

  void _handleMessageTap(MailMessage message) {
    if (_selectionMode) {
      setState(() {
        if (!_selectedMessageIds.add(message.id)) {
          _selectedMessageIds.remove(message.id);
        }
      });
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MailDetailScreen(
          controller: widget.controller,
          accountId: widget.accountId,
          message: message,
        ),
      ),
    );
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  bool _isAllSelected() {
    final messages = _currentMessages();
    return messages.isNotEmpty &&
        messages.every((message) => _selectedMessageIds.contains(message.id));
  }

  void _toggleSelectAll() {
    final messages = _currentMessages();
    setState(() {
      if (_isAllSelected()) {
        _selectedMessageIds.removeAll(messages.map((message) => message.id));
      } else {
        _selectedMessageIds.addAll(messages.map((message) => message.id));
      }
    });
  }

  Future<void> _showMessageActions() async {
    if (_selectedMessageIds.isEmpty) return;
    final messages = _currentMessages()
        .where((message) => _selectedMessageIds.contains(message.id))
        .toList();
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
              leading: const Icon(Icons.mark_email_read_outlined),
              title: Text('标记已读 (${messages.length})'),
              onTap: () => Navigator.pop(context, 'read'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('删除邮件 (${messages.length})'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'read') {
      await widget.controller.markMessagesRead(widget.accountId, messages);
      if (mounted) _exitSelection();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除所选邮件？'),
        content: Text('将删除 ${messages.length} 封邮件。'),
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
      await widget.controller.deleteMessages(widget.accountId, messages);
      if (mounted) _exitSelection();
    }
  }

  List<MailMessage> _currentMessages() => widget.controller.messagesFor(
    widget.accountId,
    _folders[_tabController.index],
  );

  Future<void> _showCredentialSheet(MailAccount account) async {
    final copied = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _CredentialSheet(account: account),
    );
    if (copied == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
    }
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.accent = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: accent ? AppColors.accentSoft : AppColors.surfaceSecondary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 21,
              color: accent ? AppColors.accent : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderView extends StatelessWidget {
  const _FolderView({
    required this.controller,
    required this.accountId,
    required this.folder,
    required this.selectionMode,
    required this.selectedMessageIds,
    required this.onTapMessage,
    required this.onLongPressMessage,
  });

  final MailController controller;
  final String accountId;
  final MailFolder folder;
  final bool selectionMode;
  final Set<String> selectedMessageIds;
  final ValueChanged<MailMessage> onTapMessage;
  final ValueChanged<MailMessage> onLongPressMessage;

  @override
  Widget build(BuildContext context) {
    final messages = controller.messagesFor(accountId, folder);
    final loading = controller.isFolderLoading(accountId, folder);
    if (messages.isEmpty && loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (messages.isEmpty) {
      return RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () => controller.loadFolder(accountId, folder),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.28),
            Icon(
              folder == MailFolder.deleteditems
                  ? Icons.delete_sweep_outlined
                  : Icons.mark_email_read_outlined,
              size: 36,
              color: AppColors.accent,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '${folder.label}为空',
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => controller.loadFolder(accountId, folder),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        itemCount: messages.length + (loading ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == messages.length) {
            return const Padding(
              padding: EdgeInsets.all(14),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final message = messages[index];
          return _MessageRow(
            message: message,
            onTap: () => onTapMessage(message),
            onLongPress: () => onLongPressMessage(message),
            selectionMode: selectionMode,
            selected: selectedMessageIds.contains(message.id),
          );
        },
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.onTap,
    required this.onLongPress,
    required this.selectionMode,
    required this.selected,
  });

  final MailMessage message;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentSoft : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              selectionMode
                  ? _MessageSelectionMark(selected: selected)
                  : _SenderMark(message: message),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.sender.isEmpty ? '未知发件人' : message.sender,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 14,
                              fontWeight: message.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(message.receivedAt),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Hero(
                      tag: 'mail-subject-${message.id}',
                      child: Material(
                        type: MaterialType.transparency,
                        child: Text(
                          message.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            fontWeight: message.isRead
                                ? FontWeight.w500
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (message.hasAttachments) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.attach_file,
                            size: 17,
                            color: AppColors.accent,
                          ),
                        ],
                        if (!message.isRead) ...[
                          const SizedBox(width: 12),
                          const _UnreadDot(),
                        ],
                      ],
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

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    final now = DateTime.now();
    if (value.year == now.year &&
        value.month == now.month &&
        value.day == now.day) {
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }
    return '${value.month}/${value.day}';
  }
}

class _SenderMark extends StatelessWidget {
  const _SenderMark({required this.message});

  final MailMessage message;

  @override
  Widget build(BuildContext context) {
    final initial = message.sender.isEmpty
        ? '?'
        : message.sender.characters.first.toUpperCase();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MessageSelectionMark extends StatelessWidget {
  const _MessageSelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.muted,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, color: Colors.white, size: 20)
          : null,
    );
  }
}

class _CredentialSheet extends StatelessWidget {
  const _CredentialSheet({required this.account});

  final MailAccount account;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '账号凭据',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
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
            _CredentialRow(label: '邮箱', value: account.email),
            _CredentialRow(label: '密码', value: account.password),
            _CredentialRow(label: 'Client ID', value: account.clientId),
            _CredentialRow(label: 'Refresh Token', value: account.refreshToken),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _copyAndClose(context, account.exportLine),
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('复制完整账号'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _copyAndClose(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) Navigator.pop(context, true);
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        value.isEmpty ? '无' : value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: '复制$label',
        onPressed: value.isEmpty
            ? null
            : () => _CredentialSheet._copyAndClose(context, value),
        icon: const Icon(Icons.copy_outlined),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
    );
  }
}
