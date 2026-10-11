import 'dart:io';

void main() {
  final file = File('app/lib/features/settings/presentation/settings_kit.dart');
  var content = file.readAsStringSync();
  
  if (!content.contains("import '../../../app/kratos_visuals.dart';")) {
    content = content.replaceFirst("import '../../../app/kratos_theme.dart';", "import '../../../app/kratos_theme.dart';\nimport '../../../app/kratos_visuals.dart';");
  }

  final buildStart = content.indexOf('  @override\n  Widget build(BuildContext context) {', content.indexOf('class SettingsGroup extends StatelessWidget {'));
  if (buildStart == -1) {
    print('Could not find build method for SettingsGroup');
    // Try with \r\n
    final buildStart2 = content.indexOf('  @override\r\n  Widget build(BuildContext context) {', content.indexOf('class SettingsGroup extends StatelessWidget {'));
    if (buildStart2 == -1) return;
  }
  
  final buildStartIdx = content.indexOf('  @override', content.indexOf('class SettingsGroup extends StatelessWidget {'));
  final nextClass = content.indexOf('class SettingsSection extends StatelessWidget {');
  
  final newBuild = '''  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    final toneColor = tone == SettingsTone.normal ? t.accent : _toneColor(t, tone);
    final highlighted = active || tone != SettingsTone.normal;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(
          height: 1,
          thickness: 1,
          indent: dividerIndent,
          endIndent: 0,
          color: t.hairline,
        ));
      }
      rows.add(children[i]);
    }

    return KratosGlassCard(
      variant: highlighted ? KratosSurfaceVariant.active : KratosSurfaceVariant.normal,
      padding: padding ?? EdgeInsets.zero,
      accentColor: toneColor,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }
}

/// Header + group convenience wrapper.
''';

  content = content.substring(0, buildStartIdx) + newBuild + content.substring(content.indexOf('class SettingsSection extends StatelessWidget {') + 45);
  
  file.writeAsStringSync(content);
}
