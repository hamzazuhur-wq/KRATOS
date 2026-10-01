import 'dart:convert';
import '../../../domain/ids.dart';

/// Available structured block types in KRATOS Idea Editor.
enum IdeaBlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  bulletList,
  numberedList,
  checklist,
  quote,
  code,
  callout,
  toggle,
  divider,
  image,
  file,
  internalLink,
}

extension IdeaBlockTypeExt on IdeaBlockType {
  String get value {
    switch (this) {
      case IdeaBlockType.paragraph:
        return 'paragraph';
      case IdeaBlockType.heading1:
        return 'heading_1';
      case IdeaBlockType.heading2:
        return 'heading_2';
      case IdeaBlockType.heading3:
        return 'heading_3';
      case IdeaBlockType.bulletList:
        return 'bullet_list';
      case IdeaBlockType.numberedList:
        return 'numbered_list';
      case IdeaBlockType.checklist:
        return 'checklist';
      case IdeaBlockType.quote:
        return 'quote';
      case IdeaBlockType.code:
        return 'code';
      case IdeaBlockType.callout:
        return 'callout';
      case IdeaBlockType.toggle:
        return 'toggle';
      case IdeaBlockType.divider:
        return 'divider';
      case IdeaBlockType.image:
        return 'image';
      case IdeaBlockType.file:
        return 'file';
      case IdeaBlockType.internalLink:
        return 'internal_link';
    }
  }

  static IdeaBlockType fromString(String val) {
    switch (val) {
      case 'heading_1':
        return IdeaBlockType.heading1;
      case 'heading_2':
        return IdeaBlockType.heading2;
      case 'heading_3':
        return IdeaBlockType.heading3;
      case 'bullet_list':
        return IdeaBlockType.bulletList;
      case 'numbered_list':
        return IdeaBlockType.numberedList;
      case 'checklist':
        return IdeaBlockType.checklist;
      case 'quote':
        return IdeaBlockType.quote;
      case 'code':
        return IdeaBlockType.code;
      case 'callout':
        return IdeaBlockType.callout;
      case 'toggle':
        return IdeaBlockType.toggle;
      case 'divider':
        return IdeaBlockType.divider;
      case 'image':
        return IdeaBlockType.image;
      case 'file':
        return IdeaBlockType.file;
      case 'internal_link':
        return IdeaBlockType.internalLink;
      case 'paragraph':
      default:
        return IdeaBlockType.paragraph;
    }
  }

  String get label {
    switch (this) {
      case IdeaBlockType.paragraph:
        return 'Text / Paragraph';
      case IdeaBlockType.heading1:
        return 'Heading 1';
      case IdeaBlockType.heading2:
        return 'Heading 2';
      case IdeaBlockType.heading3:
        return 'Heading 3';
      case IdeaBlockType.bulletList:
        return 'Bulleted List';
      case IdeaBlockType.numberedList:
        return 'Numbered List';
      case IdeaBlockType.checklist:
        return 'To-do / Checklist';
      case IdeaBlockType.quote:
        return 'Quote';
      case IdeaBlockType.code:
        return 'Code Block';
      case IdeaBlockType.callout:
        return 'Callout';
      case IdeaBlockType.toggle:
        return 'Toggle / Collapsible';
      case IdeaBlockType.divider:
        return 'Divider';
      case IdeaBlockType.image:
        return 'Image';
      case IdeaBlockType.file:
        return 'File Attachment';
      case IdeaBlockType.internalLink:
        return 'Link to Idea';
    }
  }
}

/// A structured block within an Idea document.
class IdeaBlock {
  final String id;
  final IdeaBlockType type;
  final String content;
  final Map<String, dynamic> payload;
  final int sortOrder;

  const IdeaBlock({
    required this.id,
    required this.type,
    this.content = '',
    this.payload = const {},
    this.sortOrder = 0,
  });

  bool get isChecked => payload['checked'] == true;
  bool get isCollapsed => payload['is_collapsed'] == true;
  String? get language => payload['language'] as String?;
  String? get calloutIcon => payload['icon'] as String?;
  String? get targetIdeaId => payload['target_idea_id'] as String?;
  String? get targetIdeaTitle => payload['target_idea_title'] as String?;
  String? get attachmentPath => payload['attachment_path'] as String?;
  String? get fileName => payload['file_name'] as String?;
  int? get fileSize => payload['file_size'] as int?;

  IdeaBlock copyWith({
    String? id,
    IdeaBlockType? type,
    String? content,
    Map<String, dynamic>? payload,
    int? sortOrder,
  }) {
    return IdeaBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      payload: payload ?? this.payload,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.value,
        'content': content,
        'payload': payload,
        'sort_order': sortOrder,
      };

  factory IdeaBlock.fromJson(Map<String, dynamic> json) {
    return IdeaBlock(
      id: json['id'] as String? ?? Id.uuidV7().value,
      type: IdeaBlockTypeExt.fromString(json['type'] as String? ?? 'paragraph'),
      content: json['content'] as String? ?? '',
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : <String, dynamic>{},
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

/// Persistent Idea Space entity.
class IdeaSpace {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? icon;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final String versionHlc;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IdeaSpace({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.icon,
    this.archivedAt,
    this.deletedAt,
    required this.versionHlc,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
}

/// Idea Space card summary with real computed counts.
class IdeaSpaceSummary {
  final IdeaSpace space;
  final int ideaCount;

  const IdeaSpaceSummary({
    required this.space,
    required this.ideaCount,
  });
}

/// Persistent Idea entity.
class Idea {
  final String id;
  final String ownerId;
  final String title;
  final String contentJson;
  final String? excerpt;
  final bool isPinned;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final String versionHlc;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Idea({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.contentJson,
    this.excerpt,
    this.isPinned = false,
    this.archivedAt,
    this.deletedAt,
    required this.versionHlc,
    required this.createdAt,
    required this.updatedAt,
  });

  List<IdeaBlock> get blocks {
    if (contentJson.isEmpty || contentJson == '[]') return [];
    try {
      final list = jsonDecode(contentJson);
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map((m) => IdeaBlock.fromJson(m))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}

/// Detailed Idea read model with spaces, tags, attachments, and links.
class IdeaDetail {
  final Idea idea;
  final List<IdeaSpace> spaces;
  final List<String> tags;
  final int attachmentCount;
  final int linkCount;
  final int backlinkCount;

  const IdeaDetail({
    required this.idea,
    required this.spaces,
    this.tags = const [],
    this.attachmentCount = 0,
    this.linkCount = 0,
    this.backlinkCount = 0,
  });
}

/// Persistent Internal Link between ideas.
class IdeaLink {
  final String id;
  final String ownerId;
  final String sourceIdeaId;
  final String? sourceBlockId;
  final String targetIdeaId;
  final String? targetBlockId;
  final String displayText;
  final String versionHlc;
  final DateTime createdAt;

  const IdeaLink({
    required this.id,
    required this.ownerId,
    required this.sourceIdeaId,
    this.sourceBlockId,
    required this.targetIdeaId,
    this.targetBlockId,
    required this.displayText,
    required this.versionHlc,
    required this.createdAt,
  });
}

/// Backlink item representing an idea that links to the current idea.
class IdeaBacklinkItem {
  final String linkId;
  final String sourceIdeaId;
  final String sourceIdeaTitle;
  final String displayText;
  final DateTime createdAt;

  const IdeaBacklinkItem({
    required this.linkId,
    required this.sourceIdeaId,
    required this.sourceIdeaTitle,
    required this.displayText,
    required this.createdAt,
  });
}

/// Persistent Idea Attachment.
class IdeaAttachment {
  final String id;
  final String ideaId;
  final String? blockId;
  final String ownerId;
  final String storagePath;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final String versionHlc;
  final DateTime createdAt;

  const IdeaAttachment({
    required this.id,
    required this.ideaId,
    this.blockId,
    required this.ownerId,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.versionHlc,
    required this.createdAt,
  });
}
