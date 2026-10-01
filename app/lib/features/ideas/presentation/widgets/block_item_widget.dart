import 'package:flutter/material.dart';

import '../../domain/idea_models.dart';

class BlockItemWidget extends StatelessWidget {
  final IdeaBlock block;
  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<IdeaBlock> onUpdateBlock;
  final VoidCallback onDelete;
  final VoidCallback onOpenSlashMenu;
  final Function(String targetIdeaId) onOpenLinkedIdea;

  final VoidCallback? onEnter;
  final VoidCallback? onPickImage;
  final VoidCallback? onPickFile;

  const BlockItemWidget({
    super.key,
    required this.block,
    required this.index,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onUpdateBlock,
    required this.onDelete,
    required this.onOpenSlashMenu,
    required this.onOpenLinkedIdea,
    this.onEnter,
    this.onPickImage,
    this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case IdeaBlockType.heading1:
        return _buildHeading(24, FontWeight.w900);
      case IdeaBlockType.heading2:
        return _buildHeading(20, FontWeight.w800);
      case IdeaBlockType.heading3:
        return _buildHeading(16, FontWeight.w700);
      case IdeaBlockType.bulletList:
        return _buildBullet();
      case IdeaBlockType.numberedList:
        return _buildNumbered();
      case IdeaBlockType.checklist:
        return _buildChecklist();
      case IdeaBlockType.quote:
        return _buildQuote();
      case IdeaBlockType.code:
        return _buildCode();
      case IdeaBlockType.callout:
        return _buildCallout();
      case IdeaBlockType.toggle:
        return _buildToggle();
      case IdeaBlockType.divider:
        return _buildDivider();
      case IdeaBlockType.image:
        return _buildImage();
      case IdeaBlockType.file:
        return _buildFile();
      case IdeaBlockType.internalLink:
        return _buildInternalLink();
      case IdeaBlockType.paragraph:
        return _buildParagraph();
    }
  }

  Widget _buildParagraph() {
    return _buildEditorRow(
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: null,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => onEnter?.call(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.5,
        ),
        decoration: _inputDecoration(index == 0 && controller.text.isEmpty ? 'Start typing your thoughts...' : ''),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildHeading(double fontSize, FontWeight fontWeight) {
    return _buildEditorRow(
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: null,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => onEnter?.call(),
        style: TextStyle(
          color: const Color(0xFFC6F135),
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: -0.5,
        ),
        decoration: _inputDecoration('Heading'),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildBullet() {
    return _buildEditorRow(
      prefix: const Padding(
        padding: EdgeInsets.only(top: 8, right: 8),
        child: Icon(Icons.circle, size: 6, color: Color(0xFFC6F135)),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: null,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => onEnter?.call(),
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
        decoration: _inputDecoration(''),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNumbered() {
    return _buildEditorRow(
      prefix: Padding(
        padding: const EdgeInsets.only(top: 4, right: 8),
        child: Text(
          '${index + 1}.',
          style: const TextStyle(
            color: Color(0xFFC6F135),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: null,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => onEnter?.call(),
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
        decoration: _inputDecoration(''),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildChecklist() {
    final isChecked = block.isChecked;
    return _buildEditorRow(
      prefix: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Checkbox(
          value: isChecked,
          checkColor: Colors.black,
          activeColor: const Color(0xFFC6F135),
          side: const BorderSide(color: Colors.white38),
          onChanged: (val) {
            final newPayload = Map<String, dynamic>.from(block.payload);
            newPayload['checked'] = val == true;
            onUpdateBlock(block.copyWith(payload: newPayload));
          },
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: null,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => onEnter?.call(),
        style: TextStyle(
          color: isChecked ? Colors.white38 : Colors.white,
          fontSize: 14,
          decoration:
              isChecked ? TextDecoration.lineThrough : TextDecoration.none,
          decorationColor: Colors.white38,
          height: 1.5,
        ),
        decoration: _inputDecoration('To-do...'),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildQuote() {
    return _buildEditorRow(
      child: Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: Color(0xFFC6F135), width: 3),
          ),
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: null,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
          decoration: _inputDecoration('Quote...'),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCode() {
    return _buildEditorRow(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F130F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: null,
          style: const TextStyle(
            color: Color(0xFFC6F135),
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.4,
          ),
          decoration: _inputDecoration('// Write or paste code snippet...'),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCallout() {
    return _buildEditorRow(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF182018),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFC6F135).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline,
              color: Color(0xFFC6F135),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: null,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.4,
                ),
                decoration: _inputDecoration('Callout message...'),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle() {
    final isCollapsed = block.isCollapsed;
    return _buildEditorRow(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF141814),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () {
                    final newPayload =
                        Map<String, dynamic>.from(block.payload);
                    newPayload['is_collapsed'] = !isCollapsed;
                    onUpdateBlock(block.copyWith(payload: newPayload));
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isCollapsed
                          ? Icons.arrow_right
                          : Icons.arrow_drop_down,
                      color: const Color(0xFFC6F135),
                      size: 20,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    maxLines: null,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    decoration: _inputDecoration('Toggle title...'),
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
            if (!isCollapsed)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 4, bottom: 8),
                child: Text(
                  block.payload['details'] as String? ??
                      'Enter nested details in toggle block...',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Colors.white24, height: 1)),
          IconButton(
            icon: const Icon(Icons.close, size: 14, color: Colors.white38),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final imagePath = block.attachmentPath ?? block.content;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141814),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imagePath.isNotEmpty && imagePath.startsWith('http'))
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white38,
                      size: 32,
                    ),
                  ),
                ),
              ),
            )
          else if (imagePath.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC6F135).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.image,
                      color: Color(0xFFC6F135),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          block.fileName ?? 'Image Selected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          imagePath,
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onPickImage,
                    icon: const Icon(Icons.sync, size: 14, color: Color(0xFFC6F135)),
                    label: const Text('Change', style: TextStyle(color: Color(0xFFC6F135), fontSize: 11)),
                  ),
                ],
              ),
            )
          else
            InkWell(
              onTap: onPickImage,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC6F135).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Color(0xFFC6F135),
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Upload Image / Pick from Device',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tap here to browse photos on your device',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    decoration:
                        _inputDecoration('Image URL or caption...'),
                    onChanged: onChanged,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 18),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFile() {
    final fileName = block.fileName ?? block.content;
    final fileSize = block.fileSize;
    final formattedSize = fileSize != null
        ? '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '';

    if (fileName.isEmpty && block.attachmentPath == null) {
      return InkWell(
        onTap: onPickFile,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141814),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFC6F135).withValues(alpha: 0.3),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file, color: Color(0xFFC6F135), size: 20),
              SizedBox(width: 8),
              Text(
                'Select File / Attachment from Device',
                style: TextStyle(
                  color: Color(0xFFC6F135),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141814),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFC6F135).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFC6F135).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Color(0xFFC6F135),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName.isEmpty ? 'Attached Document' : fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (formattedSize.isNotEmpty)
                  Text(
                    formattedSize,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync, color: Color(0xFFC6F135), size: 16),
            tooltip: 'Change file',
            onPressed: onPickFile,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.white38, size: 18),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildInternalLink() {
    final title = block.targetIdeaTitle ??
        (block.content.isNotEmpty ? block.content : 'Untitled Idea');
    final targetId = block.targetIdeaId;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              if (targetId != null && targetId.isNotEmpty) {
                onOpenLinkedIdea(targetId);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFC6F135).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFC6F135).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.link,
                    color: Color(0xFFC6F135),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFC6F135),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward,
                    color: Color(0xFFC6F135),
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white24, size: 16),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildEditorRow({Widget? prefix, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ?prefix,
          Expanded(child: child),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      border: InputBorder.none,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}
