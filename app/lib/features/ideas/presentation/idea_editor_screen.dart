import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/kratos_motion.dart';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/kratos_dropdown.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/ids.dart';
import '../data/ideas_repository.dart';
import '../domain/idea_models.dart';
import 'dialogs/manage_idea_spaces_dialog.dart';
import 'widgets/backlinks_section.dart';
import 'widgets/block_item_widget.dart';
import 'widgets/internal_link_autocomplete.dart';
import 'widgets/slash_command_menu.dart';

class IdeaEditorScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final String ideaId;

  const IdeaEditorScreen({
    super.key,
    required this.database,
    required this.ownerId,
    required this.ideaId,
  });

  @override
  State<IdeaEditorScreen> createState() => _IdeaEditorScreenState();
}

class _IdeaEditorScreenState extends State<IdeaEditorScreen> {
  late final IdeasRepository _repository;
  late final TextEditingController _titleController;

  final List<IdeaBlock> _blocks = [];
  final List<TextEditingController> _blockControllers = [];
  final List<FocusNode> _blockFocusNodes = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPinned = false;
  List<IdeaSpace> _currentSpaces = [];
  Timer? _debounceTimer;

  // Slash command state
  int? _activeSlashIndex;
  String _slashFilter = '';

  // Autocomplete link state
  int? _activeLinkIndex;
  String _linkQuery = '';

  @override
  void initState() {
    super.initState();
    _repository = IdeasRepository(widget.database);
    _titleController = TextEditingController();
    _loadIdea();
  }

  Future<void> _loadIdea() async {
    final detail = await _repository.getIdeaDetail(widget.ideaId);
    if (detail != null) {
      _titleController.text = detail.idea.title;
      _isPinned = detail.idea.isPinned;
      _currentSpaces = detail.spaces;

      final loadedBlocks = detail.idea.blocks;
      if (loadedBlocks.isNotEmpty) {
        _blocks.addAll(loadedBlocks);
      } else {
        _blocks.add(
          IdeaBlock(
            id: Id.uuidV7().value,
            type: IdeaBlockType.paragraph,
            content: '',
          ),
        );
      }
    } else {
      _titleController.text = 'Untitled';
      _blocks.add(
        IdeaBlock(
          id: Id.uuidV7().value,
          type: IdeaBlockType.paragraph,
          content: '',
        ),
      );
    }

    _syncControllers();
    if (mounted) setState(() => _isLoading = false);
  }

  void _syncControllers() {
    for (final c in _blockControllers) {
      c.dispose();
    }
    for (final f in _blockFocusNodes) {
      f.dispose();
    }
    _blockControllers.clear();
    _blockFocusNodes.clear();

    for (var i = 0; i < _blocks.length; i++) {
      final ctrl = TextEditingController(text: _blocks[i].content);
      final focus = FocusNode();
      _blockControllers.add(ctrl);
      _blockFocusNodes.add(focus);
    }
  }

  void _onBlockChanged(int index, String value) {
    _blocks[index] = _blocks[index].copyWith(content: value);

    // Check for slash menu trigger '/'
    if (value.startsWith('/')) {
      setState(() {
        _activeSlashIndex = index;
        _slashFilter = value;
        _activeLinkIndex = null;
      });
    } else if (_activeSlashIndex == index) {
      setState(() {
        _activeSlashIndex = null;
      });
    }

    // Check for internal link trigger '[['
    if (value.contains('[[')) {
      final start = value.indexOf('[[');
      final sub = value.substring(start);
      setState(() {
        _activeLinkIndex = index;
        _linkQuery = sub;
        _activeSlashIndex = null;
      });
    } else if (_activeLinkIndex == index) {
      setState(() {
        _activeLinkIndex = null;
      });
    }

    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    _debounceTimer?.cancel();
    if (mounted) setState(() => _isSaving = true);

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      await _save();
      if (mounted) setState(() => _isSaving = false);
    });
  }

  Future<void> _save() async {
    await _repository.updateIdeaContent(
      ideaId: widget.ideaId,
      title: _titleController.text.trim().isEmpty
          ? 'Untitled'
          : _titleController.text.trim(),
      blocks: _blocks,
      isPinned: _isPinned,
    );
  }

  void _insertBlockBelow(int index, IdeaBlockType type) {
    final newBlock = IdeaBlock(
      id: Id.uuidV7().value,
      type: type,
      content: '',
      sortOrder: index + 1,
    );
    setState(() {
      _blocks.insert(index + 1, newBlock);
      _activeSlashIndex = null;
      _activeLinkIndex = null;
      _syncControllers();
    });
    _scheduleAutosave();

    // Focus the new block
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index + 1 < _blockFocusNodes.length) {
        _blockFocusNodes[index + 1].requestFocus();
      }
    });
  }

  void _deleteBlock(int index) {
    if (_blocks.length <= 1) {
      // Keep at least one empty block
      _blocks[0] = IdeaBlock(
        id: Id.uuidV7().value,
        type: IdeaBlockType.paragraph,
        content: '',
      );
      _blockControllers[0].text = '';
      setState(() {});
      _scheduleAutosave();
      return;
    }

    setState(() {
      _blocks.removeAt(index);
      _syncControllers();
    });
    _scheduleAutosave();
  }

  Future<void> _pickImageForBlock(int index) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final payload = {
          'attachment_path': picked.path,
          'file_name': picked.name,
          'file_size': bytes.length,
        };
        setState(() {
          _blocks[index] = _blocks[index].copyWith(
            type: IdeaBlockType.image,
            content: picked.path,
            payload: payload,
          );
          _blockControllers[index].text = picked.name;
        });
        _scheduleAutosave();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickFileForBlock(int index) async {
    try {
      final file = await FilePicker.pickFile();
      if (file != null) {
        final size = file.lengthSync() ?? (await file.length()) ?? 0;
        final payload = {
          'attachment_path': file.path ?? '',
          'file_name': file.name,
          'file_size': size,
        };
        setState(() {
          _blocks[index] = _blocks[index].copyWith(
            type: IdeaBlockType.file,
            content: file.name,
            payload: payload,
          );
          _blockControllers[index].text = file.name;
        });
        _scheduleAutosave();
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  void _onEnterPressed(int index) {
    if (index >= _blocks.length) return;
    final current = _blocks[index];
    final isListType =
        current.type == IdeaBlockType.bulletList ||
        current.type == IdeaBlockType.numberedList ||
        current.type == IdeaBlockType.checklist;

    // If current block is empty list item, convert to paragraph on Enter
    if (isListType && current.content.trim().isEmpty) {
      setState(() {
        _blocks[index] = current.copyWith(type: IdeaBlockType.paragraph);
      });
      _scheduleAutosave();
      return;
    }

    // Otherwise insert new block below: maintain list type if inside list, otherwise paragraph
    final nextType = isListType ? current.type : IdeaBlockType.paragraph;
    _insertBlockBelow(index, nextType);
  }

  Future<void> _applySlashSelection(IdeaBlockType selectedType) async {
    if (_activeSlashIndex == null || _activeSlashIndex! >= _blocks.length) {
      return;
    }
    final idx = _activeSlashIndex!;

    if (selectedType == IdeaBlockType.image) {
      _activeSlashIndex = null;
      setState(() {});
      await _pickImageForBlock(idx);
      return;
    }

    if (selectedType == IdeaBlockType.file) {
      _activeSlashIndex = null;
      setState(() {});
      await _pickFileForBlock(idx);
      return;
    }

    setState(() {
      _blocks[idx] = _blocks[idx].copyWith(type: selectedType, content: '');
      _blockControllers[idx].text = '';
      _activeSlashIndex = null;
    });
    _scheduleAutosave();
  }

  void _applyLinkSelection(IdeaDetail targetIdea) {
    if (_activeLinkIndex == null || _activeLinkIndex! >= _blocks.length) return;
    final idx = _activeLinkIndex!;

    final payload = {
      'target_idea_id': targetIdea.idea.id,
      'target_idea_title': targetIdea.idea.title,
    };

    setState(() {
      _blocks[idx] = _blocks[idx].copyWith(
        type: IdeaBlockType.internalLink,
        content: targetIdea.idea.title,
        payload: payload,
      );
      _blockControllers[idx].text = targetIdea.idea.title;
      _activeLinkIndex = null;
    });
    _scheduleAutosave();
  }

  Future<void> _openManageSpaces() async {
    final allSpaces = await _repository
        .watchIdeaSpacesWithCounts(widget.ownerId)
        .first;
    if (!mounted) return;

    final availableSpaces = allSpaces.map((s) => s.space).toList();
    final currentIds = _currentSpaces.map((s) => s.id).toList();

    showDialog(
      context: context,
      builder: (_) => ManageIdeaSpacesDialog(
        availableSpaces: availableSpaces,
        currentSpaceIds: currentIds,
        onSave: (selectedIds) async {
          await _repository.assignIdeaToSpaces(
            ideaId: widget.ideaId,
            ownerId: widget.ownerId,
            spaceIds: selectedIds,
          );
          final updated = await _repository.getIdeaDetail(widget.ideaId);
          if (mounted && updated != null) {
            setState(() => _currentSpaces = updated.spaces);
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.dispose();
    for (final c in _blockControllers) {
      c.dispose();
    }
    for (final f in _blockFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFC6F135)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () async {
            await _save();
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isSaving
                    ? const Color(0xFFFFB300).withValues(alpha: 0.15)
                    : const Color(0xFFC6F135).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSaving ? Icons.sync : Icons.cloud_done_outlined,
                    color: _isSaving
                        ? const Color(0xFFFFB300)
                        : const Color(0xFFC6F135),
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isSaving ? 'Saving...' : 'Saved',
                    style: TextStyle(
                      color: _isSaving
                          ? const Color(0xFFFFB300)
                          : const Color(0xFFC6F135),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: _isPinned ? const Color(0xFFC6F135) : Colors.white38,
            ),
            onPressed: () {
              setState(() => _isPinned = !_isPinned);
              _scheduleAutosave();
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder_outlined, color: Colors.white70),
            onPressed: _openManageSpaces,
            tooltip: 'Assign to Spaces',
          ),
          KratosPopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            onSelected: (val) async {
              if (val == 'delete') {
                await _repository.deleteIdea(widget.ideaId, widget.ownerId);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            itemBuilder: (context) => [
              const KratosPopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Delete Idea',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Spaces Chip Bar
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ..._currentSpaces.map(
                      (s) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC6F135)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFC6F135)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.folder_outlined,
                              color: Color(0xFFC6F135),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              s.name,
                              style: const TextStyle(
                                color: Color(0xFFC6F135),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _openManageSpaces,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: Colors.white54, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Add Space',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Main Title Field
                TextField(
                  controller: _titleController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Untitled Idea',
                    hintStyle: TextStyle(
                      color: Colors.white24,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (_) => _scheduleAutosave(),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),

                // Blocks Canvas
                ...List.generate(_blocks.length, (index) {
                  return BlockItemWidget(
                    block: _blocks[index],
                    index: index,
                    controller: _blockControllers[index],
                    focusNode: _blockFocusNodes[index],
                    onChanged: (val) => _onBlockChanged(index, val),
                    onEnter: () => _onEnterPressed(index),
                    onPickImage: () => _pickImageForBlock(index),
                    onPickFile: () => _pickFileForBlock(index),
                    onUpdateBlock: (updated) {
                      setState(() => _blocks[index] = updated);
                      _scheduleAutosave();
                    },
                    onDelete: () => _deleteBlock(index),
                    onOpenSlashMenu: () {
                      setState(() {
                        _activeSlashIndex = index;
                        _slashFilter = '';
                      });
                    },
                    onOpenLinkedIdea: (targetId) {
                      Navigator.of(context).push(
                        KratosMaterialPageRoute(
                          builder: (_) => IdeaEditorScreen(
                            database: widget.database,
                            ownerId: widget.ownerId,
                            ideaId: targetId,
                          ),
                        ),
                      );
                    },
                  );
                }),

                // Fluid bottom canvas area: tap anywhere below to keep typing
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (_blocks.isEmpty ||
                        _blocks.last.content.trim().isNotEmpty) {
                      _insertBlockBelow(
                        _blocks.length - 1,
                        IdeaBlockType.paragraph,
                      );
                    } else {
                      _blockFocusNodes.last.requestFocus();
                    }
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    color: Colors.transparent,
                  ),
                ),

                // Backlinks Section
                BacklinksSection(
                  repository: _repository,
                  ideaId: widget.ideaId,
                  onOpenIdea: (sourceId) {
                    Navigator.of(context).push(
                      KratosMaterialPageRoute(
                        builder: (_) => IdeaEditorScreen(
                          database: widget.database,
                          ownerId: widget.ownerId,
                          ideaId: sourceId,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),

          // Floating Slash Menu Overlay
          if (_activeSlashIndex != null)
            Positioned(
              left: 24,
              bottom: 40,
              child: SlashCommandMenu(
                filter: _slashFilter,
                onSelect: _applySlashSelection,
                onDismiss: () => setState(() => _activeSlashIndex = null),
              ),
            ),

          // Floating Internal Link Autocomplete Overlay
          if (_activeLinkIndex != null)
            Positioned(
              left: 24,
              bottom: 40,
              child: InternalLinkAutocomplete(
                repository: _repository,
                ownerId: widget.ownerId,
                query: _linkQuery,
                onSelect: _applyLinkSelection,
                onDismiss: () => setState(() => _activeLinkIndex = null),
              ),
            ),
        ],
      ),
    );
  }
}
