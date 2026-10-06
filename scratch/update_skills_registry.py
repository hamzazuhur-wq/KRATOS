import re

file_path = r'C:\Users\hamza\Documents\antigravity\kratos\app\lib\features\skills\presentation\skills_registry_screen.dart'

with open(file_path, 'r') as f:
    content = f.read()

# Make isDark available where needed
replacements = [
    (r"color: Color\(0xFF979C92\)", r"color: isDark ? const Color(0xFF979C92) : KratosTheme.lightTextSecondary"),
    (r"color: Color\(0xFF686D65\)", r"color: isDark ? const Color(0xFF686D65) : KratosTheme.lightTextMuted"),
    (r"Color\(0xFF141714\)", r"(isDark ? const Color(0xFF141714) : KratosTheme.lightSurfaceGlass)"),
    (r"Color\(0xFFEEFF08\)", r"(isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime)"),
    (r"Color\(0xFFC6F135\)", r"(isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime)"),
    (r"Color\(0xFF121412\)", r"(isDark ? const Color(0xFF121412) : KratosTheme.lightSurface)"),
    (r"Color\(0xFF0D0F0D\)", r"(isDark ? const Color(0xFF0D0F0D) : KratosTheme.lightSurfaceGlass)"),
    (r"Color\(0xFF161816\)", r"(isDark ? const Color(0xFF161816) : const Color(0xFFF1F3F6))"),
    (r"Color\(0xFF020302\)", r"(isDark ? KratosTheme.deepBlack : Colors.white)"),
    (r"Colors\.white12", r"(isDark ? Colors.white12 : KratosTheme.lightBorderGlass)"),
    (r"Colors\.white10", r"(isDark ? Colors.white10 : KratosTheme.lightBorderGlass)"),
    (r"Colors\.white24", r"(isDark ? Colors.white24 : Colors.black12)"),
    (r"Colors\.white38", r"(isDark ? Colors.white38 : KratosTheme.lightTextMuted)"),
    (r"Colors\.white54", r"(isDark ? Colors.white54 : KratosTheme.lightTextSecondary)"),
    (r"Colors\.white70", r"(isDark ? Colors.white70 : KratosTheme.lightTextPrimary)"),
    (r"Colors\.white", r"(isDark ? Colors.white : KratosTheme.lightTextPrimary)"),
    (r"Colors\.black", r"(isDark ? Colors.black : Colors.white)"),
]

for old, new in replacements:
    content = re.sub(old, new, content)

# ensure isDark is defined in _SkillSheetState
if "final isDark =" not in content.split("class _SkillSheetState")[1].split("Widget build")[1]:
    content = content.replace("Widget build(BuildContext context) {", "Widget build(BuildContext context) {\n    final isDark = Theme.of(context).brightness == Brightness.dark;", 1)

# do the same for _GroupManagerDialog
if "final isDark =" not in content.split("class _GroupManagerDialog")[1].split("Widget build")[1]:
    content = content.replace("Widget build(BuildContext context) =>", "Widget build(BuildContext context) {\n    final isDark = Theme.of(context).brightness == Brightness.dark;\n    return", 1)
    content = content.replace("];\n  );", "];\n  );}", 1)

# same for _Metric
if "final isDark =" not in content.split("class _Metric")[1].split("Widget build")[1]:
    content = content.replace("Widget build(BuildContext context) =>", "Widget build(BuildContext context) {\n    final isDark = Theme.of(context).brightness == Brightness.dark;\n    return", 1)
    content = content.replace("  );\n}", "  );\n  }\n}")

# write back
with open(file_path, 'w') as f:
    f.write(content)
print("Updated skills registry for light mode.")
