import 'package:flutter/material.dart';

import '../../domain/idea_models.dart';

class ManageIdeaSpacesDialog extends StatefulWidget {
  final List<IdeaSpace> availableSpaces;
  final List<String> currentSpaceIds;
  final Function(List<String> selectedSpaceIds) onSave;

  const ManageIdeaSpacesDialog({
    super.key,
    required this.availableSpaces,
    required this.currentSpaceIds,
    required this.onSave,
  });

  @override
  State<ManageIdeaSpacesDialog> createState() => _ManageIdeaSpacesDialogState();
}

class _ManageIdeaSpacesDialogState extends State<ManageIdeaSpacesDialog> {
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.currentSpaceIds.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141814),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFFC6F135).withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC6F135).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.folder_copy_outlined,
                    color: Color(0xFFC6F135),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Add to Idea Spaces',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'An idea can belong to zero, one, or multiple spaces simultaneously.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (widget.availableSpaces.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No Idea Spaces created yet.\nCreate one from the Dashboard.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.availableSpaces.length,
                  separatorBuilder: (_, _) => const Divider(
                    color: Colors.white12,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final space = widget.availableSpaces[index];
                    final isChecked = _selectedIds.contains(space.id);
                    return CheckboxListTile(
                      value: isChecked,
                      checkColor: Colors.black,
                      activeColor: const Color(0xFFC6F135),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        space.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: space.description != null && space.description!.isNotEmpty
                          ? Text(
                              space.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            )
                          : null,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedIds.add(space.id);
                          } else {
                            _selectedIds.remove(space.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC6F135),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    widget.onSave(_selectedIds.toList());
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
