// ignore_for_file: public_member_api_docs
// Wave 23: BackupScreen — Liquid Glass settings-style screen for Export / Import.
//
// Design: Dark Volcanic (#0D0D0D) + Acid Lime (#C6F135) + Liquid Glass panels.

import 'package:flutter/material.dart';
import '../domain/backup_service.dart';
import '../../../data/drift/app_database.dart';

class BackupScreen extends StatefulWidget {
  final String userId;
  final AppDatabase db;

  const BackupScreen({
    super.key,
    required this.userId,
    required this.db,
  });

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final BackupService _service;
  bool _exporting = false;
  bool _importing = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _service = BackupService(db: widget.db);
  }

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _statusMessage = null;
    });

    try {
      final manifest = await _service.exportToJson(widget.userId);
      final json = manifest.toJsonString(pretty: true);

      // In a real app this would use file_picker / share_plus to save the file.
      // For now we display the size as confirmation.
      final sizeKb = (json.length / 1024).toStringAsFixed(1);
      _setStatus('✅ Export complete — $sizeKb KB ready for download.', isError: false);
    } catch (e) {
      _setStatus('❌ Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    // In a real app we'd use file_picker to load a .json file.
    // For demo / test purposes, show a paste dialog.
    final rawJson = await _showImportDialog();
    if (rawJson == null || rawJson.trim().isEmpty) return;

    setState(() {
      _importing = true;
      _statusMessage = null;
    });

    try {
      final result = await _service.importFromJson(rawJson);
      if (result.success) {
        _setStatus(
          '✅ Import complete — ${result.totalImported} entities restored '
          '(${result.lifeAreasImported} areas, ${result.goalsImported} goals, '
          '${result.tasksImported} tasks, ${result.notesImported} notes).',
          isError: false,
        );
      } else {
        _setStatus('❌ Import failed: ${result.errorMessage}', isError: true);
      }
    } catch (e) {
      _setStatus('❌ Import error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _setStatus(String message, {required bool isError}) {
    if (mounted) setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  Future<String?> _showImportDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF131313),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Paste Backup JSON',
                style: TextStyle(
                  color: Color(0xFFC6F135),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                decoration: InputDecoration(
                  hintText: '{ "schema_version": 1, ... }',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withAlpha(8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withAlpha(20)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withAlpha(20)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white38)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC6F135),
                      foregroundColor: const Color(0xFF0D0D0D),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () =>
                        Navigator.of(ctx).pop(controller.text),
                    child: const Text('Import',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Data Backup',
          style: TextStyle(
            color: Color(0xFFC6F135),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFC6F135)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                    icon: Icons.upload_rounded,
                    label: 'Export Data',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Download a complete JSON backup of all your life areas, goals, tasks, notes, skills, and achievements.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  _ActionButton(
                    label: 'Export JSON Backup',
                    icon: Icons.download_rounded,
                    loading: _exporting,
                    onTap: _export,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                    icon: Icons.download_rounded,
                    label: 'Import Data',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Restore from a KRATOS backup file. Existing data is preserved — '
                    'only missing or older entries are updated.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '⚠️ XP ledger entries are not re-imported to preserve the append-only invariant.',
                    style: TextStyle(color: Colors.orange, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  _ActionButton(
                    label: 'Import from JSON',
                    icon: Icons.upload_file_rounded,
                    loading: _importing,
                    onTap: _import,
                    outline: true,
                  ),
                ],
              ),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              _StatusBanner(
                message: _statusMessage!,
                isError: _statusIsError,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFC6F135), size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFC6F135),
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;
  final bool outline;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(
          color: outline
              ? Colors.transparent
              : (loading ? const Color(0xFFC6F135).withAlpha(80) : const Color(0xFFC6F135)),
          borderRadius: BorderRadius.circular(14),
          border: outline
              ? Border.all(color: const Color(0xFFC6F135).withAlpha(120), width: 1.5)
              : null,
          boxShadow: (!outline && !loading)
              ? [
                  BoxShadow(
                    color: const Color(0xFFC6F135).withAlpha(50),
                    blurRadius: 16,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0D0D0D)),
              )
            else
              Icon(icon,
                  size: 18,
                  color: outline ? const Color(0xFFC6F135) : const Color(0xFF0D0D0D)),
            const SizedBox(width: 8),
            Text(
              loading ? 'Working...' : label,
              style: TextStyle(
                color: outline ? const Color(0xFFC6F135) : const Color(0xFF0D0D0D),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const _StatusBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isError ? Colors.red : const Color(0xFFC6F135)).withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isError ? Colors.red : const Color(0xFFC6F135)).withAlpha(60),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? Colors.red[300] : const Color(0xFFC6F135),
          fontSize: 13,
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: child,
    );
  }
}
