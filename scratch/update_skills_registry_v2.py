import re
file_path = r'C:\Users\hamza\Documents\antigravity\kratos\app\lib\features\skills\presentation\skills_registry_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

# Add final isDark = Theme.of(context).brightness == Brightness.dark; in build methods if not present
def insert_isDark(class_name, content_str):
    pattern = r'(class ' + class_name + r' .*?Widget build\(BuildContext context\) {)'
    replacement = r'\1\n    final isDark = Theme.of(context).brightness == Brightness.dark;'
    return re.sub(pattern, replacement, content_str, flags=re.DOTALL)

def insert_isDark_arrow(class_name, content_str):
    pattern = r'(class ' + class_name + r' .*?Widget build\(BuildContext context\) =>)'
    replacement = r'Widget build(BuildContext context) {\n    final isDark = Theme.of(context).brightness == Brightness.dark;\n    return'
    # Find the class and replace its build method
    class_match = re.search(r'class ' + class_name + r' .*?Widget build\(BuildContext context\) =>(.*?)(?=\nclass|\Z)', content_str, flags=re.DOTALL)
    if class_match:
        old_build = class_match.group(0)
        new_build = old_build.replace('Widget build(BuildContext context) =>', 'Widget build(BuildContext context) {\n    final isDark = Theme.of(context).brightness == Brightness.dark;\n    return')
        new_build = new_build.rstrip() + ';\n  }'
        content_str = content_str.replace(old_build, new_build)
    return content_str

content = insert_isDark('_GroupManagerDialog', content)
content = insert_isDark('_SkillSheetState', content)
content = insert_isDark_arrow('_Metric', content)
content = insert_isDark_arrow('_EmptyState', content)
content = insert_isDark_arrow('_ErrorState', content)
content = insert_isDark_arrow('_SkillCard', content) # actually SkillCard doesn't use => but we will see

# Simple replacements
replacements = [
    ("Color(0xFF141714)", "(isDark ? const Color(0xFF141714) : KratosTheme.lightSurface)"),
    ("Color(0xFFEEFF08)", "(isDark ? const Color(0xFFEEFF08) : KratosTheme.lightAcidLime)"),
    ("Color(0xFF979C92)", "(isDark ? const Color(0xFF979C92) : KratosTheme.lightTextSecondary)"),
    ("Color(0xFF686D65)", "(isDark ? const Color(0xFF686D65) : KratosTheme.lightTextMuted)"),
    ("Color(0xFFC6F135)", "(isDark ? const Color(0xFFC6F135) : KratosTheme.lightAcidLime)"),
    ("Color(0xFF121412)", "(isDark ? const Color(0xFF121412) : KratosTheme.lightSurface)"),
    ("Color(0xFF0D0F0D)", "(isDark ? const Color(0xFF0D0F0D) : KratosTheme.lightSurfaceGlass)"),
    ("Color(0xFF161816)", "(isDark ? const Color(0xFF161816) : const Color(0xFFF1F3F6))"),
    ("Color(0xFF020302)", "(isDark ? const Color(0xFF020302) : Colors.white)"),
    ("Colors.white12", "(isDark ? Colors.white12 : KratosTheme.lightBorderGlass)"),
    ("Colors.white10", "(isDark ? Colors.white10 : KratosTheme.lightBorderGlass)"),
    ("Colors.white24", "(isDark ? Colors.white24 : Colors.black12)"),
    ("Colors.white38", "(isDark ? Colors.white38 : KratosTheme.lightTextMuted)"),
    ("Colors.white54", "(isDark ? Colors.white54 : KratosTheme.lightTextSecondary)"),
    ("Colors.white70", "(isDark ? Colors.white70 : KratosTheme.lightTextPrimary)"),
    ("Colors.white", "(isDark ? Colors.white : KratosTheme.lightTextPrimary)"),
    ("Colors.black", "(isDark ? Colors.black : Colors.white)"),
]

for old, new in replacements:
    content = content.replace(old, new)

with open(file_path, 'w') as f:
    f.write(content)
print("Done")
