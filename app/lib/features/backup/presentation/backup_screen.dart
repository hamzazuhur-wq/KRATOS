// ignore_for_file: public_member_api_docs
// Wave 23: BackupScreen — settings-style screen for Export / Import.
// Wave 12: presentation restyled with the Settings kit (Dark master + Light).

import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/backup_service.dart';
import '../../../data/drift/app_database.dart';
import '../../settings/presentation/settings_kit.dart';

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
      final bytes = Uint8List.fromList(utf8.encode(json));
      final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = 'kratos_backup_$dateStr.json';

      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Save KRATOS Backup File',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      final sizeKb = (json.length / 1024).toStringAsFixed(1);
      if (savedUri != null) {
        _setStatus('✅ Export saved successfully ($sizeKb KB) -> $savedUri', isError: false);
      } else {
        _setStatus('✅ Export file generated ($sizeKb KB).', isError: false);
      }
    } catch (e) {
      _setStatus('❌ Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _copyExportJson() async {
    setState(() {
      _exporting = true;
      _statusMessage = null;
    });

    try {
      final manifest = await _service.exportToJson(widget.userId);
      final json = manifest.toJsonString(pretty: true);
      await Clipboard.setData(ClipboardData(text: json));
      final sizeKb = (json.length / 1024).toStringAsFixed(1);
      _setStatus('✅ Backup JSON copied to clipboard ($sizeKb KB).', isError: false);
    } catch (e) {
      _setStatus('❌ Failed to copy export: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importFromFile() async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Select KRATOS Backup File (.json)',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (file == null) return;
      final bytes = await file.readAsBytes();
      final rawJson = utf8.decode(bytes);

      if (rawJson.trim().isEmpty) {
        _setStatus('❌ Could not read the selected backup file.', isError: true);
        return;
      }

      setState(() {
        _importing = true;
        _statusMessage = null;
      });

      final importResult = await _service.importFromJson(rawJson);
      if (importResult.success) {
        _setStatus(
          '✅ Import successful! Restored ${importResult.totalImported} entities '
          '(${importResult.lifeAreasImported} life areas, ${importResult.goalsImported} goals, '
          '${importResult.tasksImported} tasks, ${importResult.notesImported} notes, '
          '${importResult.skillsImported} skills, ${importResult.projectsImported} projects).',
          isError: false,
        );
      } else {
        _setStatus('❌ Import failed: ${importResult.errorMessage}', isError: true);
      }
    } catch (e) {
      _setStatus('❌ Import error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importFromText() async {
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
    if (mounted) {
      setState(() {
        _statusMessage = message;
        _statusIsError = isError;
      });
    }
  }

  Future<String?> _showImportDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => SettingsDialog(
        eyebrow: 'Import',
        title: 'Paste backup JSON',
        actions: [
          SettingsButton(
            label: 'Cancel',
            expand: false,
            compact: true,
            variant: SettingsButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(null),
          ),
          SettingsButton(
            label: 'Import',
            expand: false,
            compact: true,
            onPressed: () => Navigator.of(ctx).pop(controller.text),
          ),
        ],
        child: TextField(
          controller: controller,
          maxLines: 8,
          style: TextStyle(
            fontFamily: 'IBM Plex Mono',
            color: SettingsTokens.of(ctx).text,
            fontSize: 12,
          ),
          decoration: const InputDecoration(
            hintText: '{ "schema_version": 1, ... }',
          ),
        ),
      ),
    );
  }

  /// Status copy arrives prefixed with a status emoji; the banner renders a
  /// proper icon instead, so strip the glyph for display only.
  String _displayMessage(String raw) =>
      raw.replaceFirst(RegExp(r'^[\u2705\u274C\u26A0\uFE0F\s]+'), '');

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: 'Data Backup',
      children: [
        SettingsSection(
          title: 'Export Data',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CopyBlock(
                    icon: Icons.upload_rounded,
                    title: 'Export Data',
                    body:
                        'Download a complete JSON backup of all your life areas, goals, tasks, notes, skills, and achievements.',
                  ),
                  const SizedBox(height: 16),
                  SettingsButtonRow(
                    children: [
                      SettingsButton(
                        label: 'Save File (.json)',
                        icon: Icons.download_rounded,
                        loading: _exporting,
                        onPressed: _export,
                      ),
                      SettingsButton(
                        label: 'Copy JSON',
                        icon: Icons.copy_rounded,
                        loading: _exporting,
                        variant: SettingsButtonVariant.secondary,
                        onPressed: _copyExportJson,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        SettingsSection(
          title: 'Import Data',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CopyBlock(
                    icon: Icons.download_rounded,
                    title: 'Import Data',
                    body:
                        'Restore from a KRATOS backup file. Existing data is preserved — '
                        'only missing or older entries are updated.',
                  ),
                  const SizedBox(height: 12),
                  const SettingsBanner(
                    tone: SettingsTone.warning,
                    message:
                        'XP ledger entries are not re-imported to preserve the append-only invariant.',
                  ),
                  const SizedBox(height: 16),
                  SettingsButtonRow(
                    children: [
                      SettingsButton(
                        label: 'Select File (.json)',
                        icon: Icons.file_open_rounded,
                        loading: _importing,
                        onPressed: _importFromFile,
                      ),
                      SettingsButton(
                        label: 'Paste JSON',
                        icon: Icons.paste_rounded,
                        loading: _importing,
                        variant: SettingsButtonVariant.secondary,
                        onPressed: _importFromText,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 20),
          SettingsBanner(
            message: _displayMessage(_statusMessage!),
            tone: _statusIsError ? SettingsTone.danger : SettingsTone.success,
          ),
        ],
      ],
    );
  }
}

class _CopyBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _CopyBlock({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsIconTile(icon: icon),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: t.text,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: t.secondary,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
