import 'package:hive/hive.dart';

part 'chat_message.g.dart';

@HiveType(
    typeId:
        20) // Ensure typeId is unique and matches what was used before (checking g.dart would help but I can't read it. checking DatabaseService registration might help. It registers ChatMessageAdapter. I'll pick a safe ID or check other models)
class ChatMessage {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String subjectId;

  @HiveField(2)
  final String userId;

  @HiveField(3)
  final String message;

  @HiveField(4)
  final bool isUser;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime updatedAt;

  @HiveField(7)
  final String? attachmentUrl; // For future support/docs

  ChatMessage({
    required this.id,
    required this.subjectId,
    required this.userId,
    required this.message,
    required this.isUser,
    required this.createdAt,
    required this.updatedAt,
    this.attachmentUrl,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      userId: json['user_id'] as String,
      message: json['message'] as String,
      isUser: json['is_user'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(
          json['updated_at'] as String? ?? json['created_at'] as String),
      attachmentUrl: json['attachment_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_id': subjectId,
      'user_id': userId,
      'message': message,
      'is_user': isUser,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'attachment_url': attachmentUrl,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? subjectId,
    String? userId,
    String? message,
    bool? isUser,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? attachmentUrl,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      userId: userId ?? this.userId,
      message: message ?? this.message,
      isUser: isUser ?? this.isUser,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
    );
  }
}
