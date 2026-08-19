enum MailFolder { inbox, junkemail, deleteditems }

extension MailFolderInfo on MailFolder {
  String get graphName => name;

  String get label => switch (this) {
    MailFolder.inbox => '收件箱',
    MailFolder.junkemail => '垃圾邮件',
    MailFolder.deleteditems => '已删除',
  };
}

class MailMessage {
  const MailMessage({
    required this.id,
    required this.folder,
    required this.subject,
    required this.sender,
    required this.recipients,
    required this.receivedAt,
    required this.isRead,
    required this.hasAttachments,
    required this.preview,
    this.body,
  });

  final String id;
  final MailFolder folder;
  final String subject;
  final String sender;
  final String recipients;
  final DateTime? receivedAt;
  final bool isRead;
  final bool hasAttachments;
  final String preview;
  final String? body;

  Map<String, dynamic> toJson() => {
    'id': id,
    'folder': folder.name,
    'subject': subject,
    'sender': sender,
    'recipients': recipients,
    'receivedAt': receivedAt?.toIso8601String(),
    'isRead': isRead,
    'hasAttachments': hasAttachments,
    'preview': preview,
    'body': body,
  };

  factory MailMessage.fromJson(Map<String, dynamic> json) {
    final folderName = json['folder']?.toString();
    return MailMessage(
      id: json['id']?.toString() ?? '',
      folder: MailFolder.values.firstWhere(
        (value) => value.name == folderName,
        orElse: () => MailFolder.inbox,
      ),
      subject: json['subject']?.toString() ?? '无主题',
      sender: json['sender']?.toString() ?? '',
      recipients: json['recipients']?.toString() ?? '',
      receivedAt: DateTime.tryParse(json['receivedAt']?.toString() ?? ''),
      isRead: json['isRead'] == true,
      hasAttachments: json['hasAttachments'] == true,
      preview: json['preview']?.toString() ?? '',
      body: json['body']?.toString(),
    );
  }

  factory MailMessage.fromGraph(Map<String, dynamic> json, MailFolder folder) {
    final senderNode = json['from'];
    final senderAddress = senderNode is Map
        ? senderNode['emailAddress'] as Map?
        : null;
    final senderName = senderAddress?['name']?.toString().trim() ?? '';
    final senderEmail = senderAddress?['address']?.toString().trim() ?? '';
    final toNodes = json['toRecipients'] as List? ?? const [];
    final recipients = toNodes
        .map((item) {
          if (item is! Map) return '';
          final address = item['emailAddress'];
          if (address is! Map) return '';
          return address['address']?.toString() ?? '';
        })
        .where((value) => value.isNotEmpty)
        .join(', ');
    final bodyNode = json['body'];

    return MailMessage(
      id: json['id']?.toString() ?? '',
      folder: folder,
      subject: (json['subject']?.toString().trim().isNotEmpty ?? false)
          ? json['subject'].toString().trim()
          : '无主题',
      sender: senderName.isNotEmpty ? senderName : senderEmail,
      recipients: recipients,
      receivedAt: DateTime.tryParse(
        json['receivedDateTime']?.toString() ?? '',
      )?.toLocal(),
      isRead: json['isRead'] == true,
      hasAttachments: json['hasAttachments'] == true,
      preview: json['bodyPreview']?.toString().trim() ?? '',
      body: bodyNode is Map ? bodyNode['content']?.toString() : null,
    );
  }

  MailMessage copyWith({String? body, bool? isRead}) => MailMessage(
    id: id,
    folder: folder,
    subject: subject,
    sender: sender,
    recipients: recipients,
    receivedAt: receivedAt,
    isRead: isRead ?? this.isRead,
    hasAttachments: hasAttachments,
    preview: preview,
    body: body ?? this.body,
  );
}
