import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:webview_flutter/webview_flutter.dart';

import '../controllers/mail_controller.dart';
import '../models/mail_message.dart';
import '../theme/app_theme.dart';

class MailDetailScreen extends StatefulWidget {
  const MailDetailScreen({
    super.key,
    required this.controller,
    required this.accountId,
    required this.message,
  });

  final MailController controller;
  final String accountId;
  final MailMessage message;

  @override
  State<MailDetailScreen> createState() => _MailDetailScreenState();
}

class _MailDetailScreenState extends State<MailDetailScreen> {
  late final Future<MailMessage> _detailFuture;
  late final Future<String> _plainFuture;
  late final PageController _bodyPageController;
  int _bodyPage = 0;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = widget.controller.loadMessageDetail(
      widget.accountId,
      widget.message,
    );
    _bodyPageController = PageController(initialPage: 0);
    _plainFuture = widget.controller.loadPlainMessage(
      widget.accountId,
      widget.message,
    );
  }

  @override
  void dispose() {
    _bodyPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                children: [
                  _HeaderIcon(
                    icon: Icons.arrow_back,
                    tooltip: '返回',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '邮件详情',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _HeaderIcon(
                    icon: Icons.delete_outline,
                    tooltip: '删除',
                    busy: _deleting,
                    onPressed: _deleteMessage,
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<MailMessage>(
                future: _detailFuture,
                builder: (context, snapshot) {
                  final message = snapshot.data ?? widget.message;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 40),
                    children: [
                      Hero(
                        tag: 'mail-subject-${message.id}',
                        child: Material(
                          type: MaterialType.transparency,
                          child: Text(
                            message.subject,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 25,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _SenderHeader(message: message),
                      const SizedBox(height: 16),
                      Text(
                        '收件人：${message.recipients.isEmpty ? '当前账号' : message.recipients}\n${_formatDate(message.receivedAt)}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      _BodyModeSwitcher(
                        value: _bodyPage,
                        onChanged: (value) {
                          _bodyPageController.animateToPage(
                            value,
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (snapshot.hasError)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.errorSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '正文读取失败：${snapshot.error}',
                            style: const TextStyle(color: AppColors.error),
                          ),
                        )
                      else
                        SizedBox(
                          height: 420,
                          child: PageView(
                            controller: _bodyPageController,
                            onPageChanged: (value) {
                              if (mounted) setState(() => _bodyPage = value);
                            },
                            children: [
                              _PlainMailBody(
                                future: _plainFuture,
                                fallback:
                                    (message.body?.trim().isNotEmpty ?? false)
                                    ? message.body!.trim()
                                    : message.preview,
                              ),
                              _RenderedMailBody(
                                body: (message.body?.trim().isNotEmpty ?? false)
                                    ? message.body!.trim()
                                    : message.preview,
                                onSwipeToPlain: () {
                                  _bodyPageController.animateToPage(
                                    0,
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOutCubic,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      if (message.hasAttachments) ...[
                        const SizedBox(height: 22),
                        const Divider(height: 1),
                        const SizedBox(height: 18),
                        const _AttachmentRow(),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    return '${value.year}年${value.month}月${value.day}日 ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _deleteMessage() async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这封邮件？'),
        content: const Text('邮件将从当前邮箱中删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.controller.deleteMessage(widget.accountId, widget.message);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$error')));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }
}

class _BodyModeSwitcher extends StatelessWidget {
  const _BodyModeSwitcher({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _ModeButton(
            label: '纯文本',
            selected: value == 0,
            onTap: () => onChanged(0),
          ),
          _ModeButton(
            label: '渲染邮件',
            selected: value == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.accent : AppColors.muted,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlainMailBody extends StatelessWidget {
  const _PlainMailBody({required this.future, required this.fallback});

  final Future<String> future;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: FutureBuilder<String>(
        future: future,
        builder: (context, snapshot) {
          final body = snapshot.data ?? fallback;
          if (snapshot.connectionState == ConnectionState.waiting &&
              body.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          if (snapshot.hasError && body.isEmpty) {
            return Text(
              '纯文本正文读取失败：${snapshot.error}',
              style: const TextStyle(color: AppColors.error),
            );
          }
          return SingleChildScrollView(
            child: SelectableText(
              body,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                height: 1.7,
                fontFamily: 'sans-serif',
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RenderedMailBody extends StatefulWidget {
  const _RenderedMailBody({required this.body, required this.onSwipeToPlain});

  final String body;
  final VoidCallback onSwipeToPlain;

  @override
  State<_RenderedMailBody> createState() => _RenderedMailBodyState();
}

class _RenderedMailBodyState extends State<_RenderedMailBody> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'MailGesture',
        onMessageReceived: (message) {
          if (message.message == 'plain') widget.onSwipeToPlain();
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (_) => NavigationDecision.prevent,
        ),
      )
      ..loadHtmlString(_buildEmailDocument(widget.body));
  }

  @override
  void didUpdateWidget(covariant _RenderedMailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.body == widget.body) return;
    _loading = true;
    _controller.loadHtmlString(_buildEmailDocument(widget.body));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.line),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: WebViewWidget(
                controller: _controller,
                gestureRecognizers: {
                  Factory<OneSequenceGestureRecognizer>(
                    EagerGestureRecognizer.new,
                  ),
                },
              ),
            ),
            if (_loading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const _allowedEmailTags = <String>{
  'a',
  'b',
  'blockquote',
  'br',
  'center',
  'code',
  'div',
  'em',
  'font',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'hr',
  'i',
  'img',
  'li',
  'ol',
  'p',
  'pre',
  'small',
  'span',
  'strong',
  'sub',
  'sup',
  'table',
  'tbody',
  'td',
  'th',
  'thead',
  'tr',
  'u',
  'ul',
};

const _allowedEmailAttributes = <String>{
  'align',
  'alt',
  'border',
  'cellpadding',
  'cellspacing',
  'class',
  'colspan',
  'height',
  'href',
  'rowspan',
  'src',
  'style',
  'title',
  'width',
};

String _buildEmailDocument(String source) {
  final fragment = html_parser.parseFragment(source);
  final elements = fragment.querySelectorAll('*').toList().reversed;
  for (final element in elements) {
    final tag = element.localName;
    if (!_allowedEmailTags.contains(tag)) {
      _unwrapElement(element);
      continue;
    }
    for (final attribute in element.attributes.keys.toList()) {
      if (!_allowedEmailAttributes.contains(attribute.toString())) {
        element.attributes.remove(attribute);
      }
    }
    _sanitizeUrlAttribute(element, 'href');
    _sanitizeUrlAttribute(element, 'src');
    final style = element.attributes['style'];
    if (style != null &&
        (style.toLowerCase().contains('javascript:') ||
            style.toLowerCase().contains('expression('))) {
      element.attributes.remove('style');
    }
  }

  final safeBody = fragment.nodes
      .map(
        (node) => node is html_dom.Element ? node.outerHtml : node.text ?? '',
      )
      .join();
  return '''<!doctype html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
  <style>
    html, body { width: 100%; max-width: 100%; min-height: 100%; background: #ffffff; overflow-x: hidden; }
    body {
      box-sizing: border-box;
      margin: 0;
      padding: 16px;
      color: #333333;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
      font-size: 15px;
      line-height: 1.6;
      overflow-wrap: anywhere;
      -webkit-text-size-adjust: 100%;
    }
    img { max-width: 100% !important; height: auto !important; }
    table { max-width: 100% !important; }
    pre { white-space: pre-wrap; overflow-wrap: anywhere; }
    a { color: #0078d4; }
  </style>
</head>
<body>$safeBody</body>
<script>
  (() => {
    let startX = 0;
    let startY = 0;
    document.addEventListener('touchstart', (event) => {
      const touch = event.changedTouches[0];
      startX = touch.clientX;
      startY = touch.clientY;
    }, { passive: true });
    document.addEventListener('touchend', (event) => {
      const touch = event.changedTouches[0];
      const deltaX = touch.clientX - startX;
      const deltaY = touch.clientY - startY;
      if (deltaX > 72 && Math.abs(deltaX) > Math.abs(deltaY) * 1.35) {
        MailGesture.postMessage('plain');
      }
    }, { passive: true });
  })();
</script>
</html>''';
}

void _unwrapElement(html_dom.Element element) {
  final parent = element.parent;
  if (parent == null) {
    element.remove();
    return;
  }
  for (final node in element.nodes.toList()) {
    parent.insertBefore(node, element);
  }
  element.remove();
}

void _sanitizeUrlAttribute(html_dom.Element element, String name) {
  final value = element.attributes[name]?.trim();
  if (value == null || value.isEmpty) return;
  final normalized = value.toLowerCase();
  final allowed =
      normalized.startsWith('https://') ||
      normalized.startsWith('http://') ||
      normalized.startsWith('mailto:') ||
      normalized.startsWith('cid:') ||
      normalized.startsWith('data:image/') ||
      normalized.startsWith('#');
  if (!allowed) element.attributes.remove(name);
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surfaceSecondary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? null : onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, color: AppColors.accent, size: 21),
          ),
        ),
      ),
    );
  }
}

class _SenderHeader extends StatelessWidget {
  const _SenderHeader({required this.message});

  final MailMessage message;

  @override
  Widget build(BuildContext context) {
    final initial = message.sender.isEmpty
        ? '?'
        : message.sender.characters.first.toUpperCase();
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.sender.isEmpty ? '未知发件人' : message.sender,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (message.recipients.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  message.recipients,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.description_outlined,
          color: AppColors.accent,
          size: 28,
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '邮件附件',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 3),
            Text(
              '可下载的附件',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
