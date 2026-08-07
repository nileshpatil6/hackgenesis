import 'package:hive/hive.dart';

part 'note.g.dart';

enum NoteType {
  pdf,
  image,
  text,
  video,
  url,
}

@HiveType(typeId: 2)
class Note extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String subjectId;

  @HiveField(2)
  String title;

  @HiveField(3)
  String? description;

  @HiveField(4)
  @HiveField(4)
  int noteType; // 0: pdf, 1: image, 2: text, 3: video, 4: url

  @HiveField(5)
  String filePath; // Local path or URL

  @HiveField(6)
  String? geminiFileId; // Gemini File ID after upload

  @HiveField(7)
  String? fileSearchDocumentId; // Document ID in File Search Store

  @HiveField(8)
  DateTime uploadedAt;

  @HiveField(9)
  DateTime updatedAt;

  @HiveField(10)
  int? pageCount; // For PDFs

  @HiveField(11)
  int? fileSize; // In bytes

  @HiveField(12)
  bool isProcessed; // Whether it's been indexed in RAG

  @HiveField(13)
  Map<String, dynamic>? metadata; // Custom metadata for filtering

  @HiveField(14)
  List<String>? tags;

  Note({
    required this.id,
    required this.subjectId,
    required this.title,
    this.description,
    required this.noteType,
    required this.filePath,
    this.geminiFileId,
    this.fileSearchDocumentId,
    required this.uploadedAt,
    required this.updatedAt,
    this.pageCount,
    this.fileSize,
    this.isProcessed = false,
    this.metadata,
    this.tags,
  });

  NoteType get type => NoteType.values[noteType];

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject_id': subjectId,
        'title': title,
        'description': description,
        'note_type': noteType,
        'file_path': filePath,
        'gemini_file_id': geminiFileId,
        'file_search_document_id': fileSearchDocumentId,
        'uploaded_at': uploadedAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'page_count': pageCount,
        'file_size': fileSize,
        'is_processed': isProcessed,
        'metadata': metadata,
        'tags': tags,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'],
        subjectId: json['subject_id'],
        title: json['title'],
        description: json['description'],
        noteType: json['note_type'],
        filePath: json['file_path'],
        geminiFileId: json['gemini_file_id'],
        fileSearchDocumentId: json['file_search_document_id'],
        uploadedAt: DateTime.parse(json['uploaded_at']),
        updatedAt: DateTime.parse(json['updated_at']),
        pageCount: json['page_count'],
        fileSize: json['file_size'],
        isProcessed: json['is_processed'] ?? false,
        metadata: json['metadata'],
        tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      );
}
