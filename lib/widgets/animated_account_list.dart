import 'package:flutter/material.dart';

import '../models/mail_account.dart';
import 'account_tile.dart';

class AnimatedAccountList extends StatefulWidget {
  const AnimatedAccountList({
    super.key,
    required this.accounts,
    required this.onTap,
    required this.onRetry,
    required this.onRefresh,
    required this.onLongPress,
    required this.selectionMode,
    required this.selectedIds,
    this.contentTopPadding = 74,
  });

  final List<MailAccount> accounts;
  final ValueChanged<MailAccount> onTap;
  final ValueChanged<MailAccount> onRetry;
  final Future<void> Function() onRefresh;
  final ValueChanged<MailAccount> onLongPress;
  final bool selectionMode;
  final Set<String> selectedIds;
  final double contentTopPadding;

  @override
  State<AnimatedAccountList> createState() => _AnimatedAccountListState();
}

class _AnimatedAccountListState extends State<AnimatedAccountList> {
  final _listKey = GlobalKey<AnimatedListState>();
  late List<MailAccount> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.accounts);
  }

  @override
  void didUpdateWidget(covariant AnimatedAccountList oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncItems(widget.accounts);
    });
  }

  void _syncItems(List<MailAccount> target) {
    final targetById = {for (final account in target) account.id: account};

    for (var index = _items.length - 1; index >= 0; index--) {
      final item = _items[index];
      if (targetById.containsKey(item.id)) continue;
      final removed = _items.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
        (context, animation) =>
            _buildAnimatedTile(context, removed, animation, removing: true),
        duration: const Duration(milliseconds: 220),
      );
    }

    for (var index = 0; index < target.length; index++) {
      final desired = target[index];
      final existingIndex = _items.indexWhere(
        (account) => account.id == desired.id,
      );
      if (existingIndex < 0) {
        _items.insert(index, desired);
        _listKey.currentState?.insertItem(
          index,
          duration: const Duration(milliseconds: 240),
        );
      } else {
        if (existingIndex != index) {
          final existing = _items.removeAt(existingIndex);
          _items.insert(index, existing);
        }
        _items[index] = desired;
      }
    }

    while (_items.length > target.length) {
      _items.removeLast();
    }
    if (mounted) setState(() {});
  }

  Widget _buildAnimatedTile(
    BuildContext context,
    MailAccount account,
    Animation<double> animation, {
    bool removing = false,
  }) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final offset = Tween<Offset>(
      begin: Offset(0, removing ? -0.08 : 0.08),
      end: Offset.zero,
    ).animate(curved);
    return FadeTransition(
      opacity: curved,
      child: SizeTransition(
        sizeFactor: curved,
        alignment: Alignment(0, removing ? -1 : 1),
        child: SlideTransition(
          position: offset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AccountTile(
                account: account,
                onTap: () => widget.onTap(account),
                onRetry: () => widget.onRetry(account),
                onLongPress: () => widget.onLongPress(account),
                selectionMode: widget.selectionMode,
                selected: widget.selectedIds.contains(account.id),
              ),
              const Divider(height: 1),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF2F6D62),
      onRefresh: widget.onRefresh,
      child: AnimatedList(
        key: _listKey,
        initialItemCount: _items.length,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(18, widget.contentTopPadding, 18, 30),
        itemBuilder: (context, index, animation) {
          if (index >= _items.length) return const SizedBox.shrink();
          return _buildAnimatedTile(context, _items[index], animation);
        },
      ),
    );
  }
}
