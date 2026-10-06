import re

file_path = r'C:\Users\hamza\Documents\antigravity\kratos\app\lib\app\app_shell.dart'
with open(file_path, 'r') as f:
    content = f.read()

# For KratosPageRoute
replacements = [
    (r'(KratosPageRoute\(\s*page: ProfileScreen\([\s\S]*?\),)(\s*\))', r"\1 settings: const RouteSettings(name: '/profile'),\2"),
    (r'(KratosPageRoute\(\s*page: NotificationsScreen\([\s\S]*?\),)(\s*\))', r"\1 settings: const RouteSettings(name: '/notifications'),\2"),
    (r'(KratosPageRoute\(\s*page: DueTodayScreen\([\s\S]*?\),)(\s*\))', r"\1 settings: const RouteSettings(name: '/due_today'),\2"),
    (r'(KratosPageRoute\(\s*page: LevelsDashboardScreen\([\s\S]*?\),)(\s*\))', r"\1 settings: const RouteSettings(name: '/levels'),\2"),
    (r'(KratosPageRoute\(\s*page: LifeAreasScreen\([\s\S]*?\),)(\s*\))', r"\1 settings: const RouteSettings(name: '/life_areas'),\2"),
    (r'(KratosPageRoute\(\s*page: SkillsRegistryScreen\([\s\S]*?\),)(\s*\))', r"\1 settings: const RouteSettings(name: '/skills'),\2"),
    (r'(KratosPageRoute\(\s*page: ProjectsScreen\([\s\S]*?\),)(\s*\))', r"\1 settings: const RouteSettings(name: '/projects'),\2"),
    (r'(KratosPageRoute\(\s*page: SettingsScreen\([\s\S]*?\),)(\s*\))', r"\1 settings: const RouteSettings(name: '/settings'),\2"),
    (r'(KratosPageRoute\(\s*page: StreakScreen\([\s\S]*?\),)(\s*\))', r"\1 settings: const RouteSettings(name: '/streaks'),\2"),
]

for pat, repl in replacements:
    content = re.sub(pat, repl, content)

# For KratosMaterialPageRoute ActivityDetailScreen
pat = r'(KratosMaterialPageRoute\(\s*builder: \(_\) => ActivityDetailScreen\([\s\S]*?\),)(\s*\))'
repl = r"\1 settings: RouteSettings(name: '/activity/$id'),\2"
content = re.sub(pat, repl, content)

# There is also a KratosPageRoute for ActivityDetailScreen in the same file!
pat2 = r'(KratosPageRoute\(\s*page: ActivityDetailScreen\([\s\S]*?\),)(\s*\))'
repl2 = r"\1 settings: RouteSettings(name: '/activity/$id'),\2"
content = re.sub(pat2, repl2, content)

with open(file_path, 'w') as f:
    f.write(content)
print("Updated app_shell.dart")
