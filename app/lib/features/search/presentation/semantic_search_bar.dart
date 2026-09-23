// Wave 19: Semantic Search Bar Widget — Liquid Glass aesthetic.
// Displays AI-ranked results with similarity percentage badges.

import 'package:flutter/material.dart';
import '../domain/semantic_search_models.dart';

class SemanticSearchBar extends StatefulWidget {
  final ValueChanged<String>? onQueryChanged;
  final List<SearchResultItem> results;
  final ValueChanged<SearchResultItem>? onItemSelected;

  const SemanticSearchBar({
    super.key,
    this.onQueryChanged,
    this.results = const [],
    this.onItemSelected,
  });

  @override
  State<SemanticSearchBar> createState() => _SemanticSearchBarState();
}

class _SemanticSearchBarState extends State<SemanticSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: _controller,
            onChanged: widget.onQueryChanged,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Semantic AI Search (e.g. "fitness habits", "deep work")...',
              hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: Icon(Icons.search, color: Color(0xFFC6F135), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        if (widget.results.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.results.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, index) {
                final item = widget.results[index];
                final matchPct = (item.similarityScore * 100).toInt();

                return ListTile(
                  dense: true,
                  leading: Icon(
                    switch (item.entityKind) {
                      'goals' => Icons.flag,
                      'tasks' => Icons.task_alt,
                      'notes' => Icons.note,
                      _ => Icons.verified,
                    },
                    color: const Color(0xFFC6F135),
                    size: 18,
                  ),
                  title: Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC6F135).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFC6F135).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '$matchPct% MATCH',
                      style: const TextStyle(
                        color: Color(0xFFC6F135),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () => widget.onItemSelected?.call(item),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
