/// 문의 게시판 모델
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

enum InquiryStatus { open, answered, closed }

extension InquiryStatusX on InquiryStatus {
  String get code => name;
  String get label => switch (this) {
        InquiryStatus.open => '대기',
        InquiryStatus.answered => '답변완료',
        InquiryStatus.closed => '종료',
      };
  static InquiryStatus fromCode(String? c) => InquiryStatus.values
      .firstWhere((e) => e.name == c, orElse: () => InquiryStatus.open);
}

class Inquiry {
  final int id;
  final int memberId;
  final String title;
  final InquiryStatus status;
  final String createdAt;
  final String updatedAt;
  final int unreadCount;
  final int messageCount;

  /// 관리자 목록에서만 채워진다
  final String? username;
  final String? name;

  const Inquiry({
    required this.id,
    required this.memberId,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.unreadCount = 0,
    this.messageCount = 0,
    this.username,
    this.name,
  });

  String get writerLabel {
    final n = (name != null && name!.isNotEmpty) ? name! : username;
    return n ?? '';
  }

  factory Inquiry.fromJson(Map<String, dynamic> j) => Inquiry(
        id: (j['id'] as num).toInt(),
        memberId: (j['member_id'] as num?)?.toInt() ?? 0,
        title: (j['title'] as String?) ?? '',
        status: InquiryStatusX.fromCode(j['status'] as String?),
        createdAt: (j['created_at'] as String?) ?? '',
        updatedAt: (j['updated_at'] as String?) ?? '',
        unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
        messageCount: (j['message_count'] as num?)?.toInt() ?? 0,
        username: j['username'] as String?,
        name: j['name'] as String?,
      );
}

class InquiryMessage {
  final int id;
  final bool fromAdmin;
  final String content;
  final String createdAt;

  const InquiryMessage({
    required this.id,
    required this.fromAdmin,
    required this.content,
    required this.createdAt,
  });

  factory InquiryMessage.fromJson(Map<String, dynamic> j) => InquiryMessage(
        id: (j['id'] as num?)?.toInt() ?? 0,
        fromAdmin: (j['sender_type'] as String?) == 'admin',
        content: (j['content'] as String?) ?? '',
        createdAt: (j['created_at'] as String?) ?? '',
      );
}

class InquiryThread {
  final Inquiry inquiry;
  final List<InquiryMessage> messages;
  final bool isAdmin;
  final bool isOwner;

  const InquiryThread({
    required this.inquiry,
    required this.messages,
    required this.isAdmin,
    required this.isOwner,
  });

  /// 종료된 문의에는 답글을 달 수 없다 (서버 규칙과 동일)
  bool get canReply => inquiry.status != InquiryStatus.closed;
}
