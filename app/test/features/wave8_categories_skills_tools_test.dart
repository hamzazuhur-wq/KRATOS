// Wave 8: Unit tests for Category, Skill, and Tool domain entities.
// Validates: ADR-003 SCD Type 2 rules, ADR-004 separation, Invariant #4, #9, #10.

import 'package:test/test.dart';

import '../../lib/domain/errors.dart';
import '../../lib/domain/hlc.dart';
import '../../lib/domain/ids.dart';
import '../../lib/domain/timestamps.dart';
import '../../lib/features/categories/domain/category_models.dart';
import '../../lib/features/skills/domain/skill_models.dart';

void main() {
  // ─── Helpers ─────────────────────────────────────────────────────────────

  Hlc _hlc([int counter = 1]) => Hlc(
        wallMs: DateTime.now().millisecondsSinceEpoch,
        counter: counter,
        node: 'test',
      );

  Category _makeCategory({bool isImmutable = false, int baseXp = 100}) {
    final now = Iso8601Timestamp.now();
    return Category(
      id: Id.uuidV7(),
      ownerId: Id.uuidV7(),
      name: 'Health',
      baseXp: baseXp,
      isImmutable: isImmutable,
      versionHlc: _hlc(),
      createdAt: now,
      updatedAt: now,
    );
  }

  SkillEntity _makeSkill({int xpTotal = 500, int level = 3}) {
    final now = Iso8601Timestamp.now();
    return SkillEntity(
      id: Id.uuidV7(),
      ownerId: Id.uuidV7(),
      name: 'Flutter Dev',
      xpTotal: xpTotal,
      level: level,
      versionHlc: _hlc(),
      createdAt: now,
      updatedAt: now,
    );
  }

  ToolEntity _makeTool() {
    final now = Iso8601Timestamp.now();
    return ToolEntity(
      id: Id.uuidV7(),
      ownerId: Id.uuidV7(),
      name: 'VS Code',
      toolType: 'software',
      versionHlc: _hlc(),
      createdAt: now,
      updatedAt: now,
    );
  }

  // ─── Category Tests ────────────────────────────────────────────────────

  group('Category domain entity', () {
    test('creates with valid baseXp', () {
      final cat = _makeCategory(baseXp: 100);
      expect(cat.baseXp, equals(100));
      expect(cat.isActive, isTrue);
    });

    test('rejects negative baseXp', () {
      expect(
        () => _makeCategory(baseXp: -1),
        throwsA(isA<ValidationError>()),
      );
    });

    test('rename returns new instance with updated name', () {
      final cat = _makeCategory();
      final renamed = cat.rename('Wellness', _hlc(2));
      expect(renamed.name, equals('Wellness'));
      expect(renamed.id, equals(cat.id));
    });

    test('archive produces archived Category', () {
      final cat = _makeCategory();
      final archived = cat.archive(_hlc(2));
      expect(archived.isArchived, isTrue);
      expect(archived.isActive, isFalse);
    });

    test('cannot archive an already-archived Category', () {
      final cat = _makeCategory().archive(_hlc(2));
      expect(() => cat.archive(_hlc(3)), throwsA(isA<ConflictError>()));
    });

    test('cannot archive an immutable Category (ADR-003)', () {
      final cat = _makeCategory(isImmutable: true);
      expect(() => cat.archive(_hlc(2)), throwsA(isA<ConflictError>()));
    });

    test('updateBaseXp returns new Category with new baseXp', () {
      final cat = _makeCategory(baseXp: 100);
      final updated = cat.updateBaseXp(150, _hlc(2));
      expect(updated.baseXp, equals(150));
      expect(updated.id, equals(cat.id));
    });

    test('updateBaseXp rejects negative value', () {
      final cat = _makeCategory();
      expect(
        () => cat.updateBaseXp(-10, _hlc(2)),
        throwsA(isA<ValidationError>()),
      );
    });
  });

  // ─── CategoryXpRuleSnapshot Tests ──────────────────────────────────────

  group('CategoryXpRuleSnapshot serialization (ADR-003)', () {
    test('roundtrips through JSON correctly', () {
      const snapshot = CategoryXpRuleSnapshot(
        baseXp: 100,
        actions: [
          (actionName: 'Morning workout', modifierPercent: 0.20),
          (actionName: 'Evening stretch', modifierPercent: 0.10),
        ],
      );
      final json = snapshot.toJson();
      final restored = CategoryXpRuleSnapshot.fromJson(json);
      expect(restored.baseXp, equals(100));
      expect(restored.actions.length, equals(2));
      expect(restored.actions.first.actionName, equals('Morning workout'));
      expect(restored.actions.first.modifierPercent, closeTo(0.20, 0.001));
    });

    test('effectiveXpDelta computes correctly for CategoryActionEntity', () {
      final now = Iso8601Timestamp.now();
      final action = CategoryActionEntity(
        id: Id.uuidV7(),
        categoryId: Id.uuidV7(),
        actionName: 'Quick workout',
        modifierPercent: 0.20,
        effectiveFrom: now,
      );
      // base_xp = 100, +20% → delta = 20
      expect(action.effectiveXpDelta(100), equals(20));
      // base_xp = 200, +20% → delta = 40
      expect(action.effectiveXpDelta(200), equals(40));
    });
  });

  // ─── SkillEntity Tests ─────────────────────────────────────────────────

  group('SkillEntity domain entity (ADR-004 + Invariant #4)', () {
    test('creates with valid xpTotal and level', () {
      final skill = _makeSkill(xpTotal: 500, level: 3);
      expect(skill.xpTotal, equals(500));
      expect(skill.level, equals(3));
      expect(skill.isActive, isTrue);
    });

    test('rejects negative xpTotal', () {
      expect(() => _makeSkill(xpTotal: -1), throwsA(isA<ValidationError>()));
    });

    test('rejects negative level', () {
      expect(() => _makeSkill(level: -1), throwsA(isA<ValidationError>()));
    });

    test('rejects blank name', () {
      final now = Iso8601Timestamp.now();
      expect(
        () => SkillEntity(
          id: Id.uuidV7(),
          ownerId: Id.uuidV7(),
          name: '   ',
          xpTotal: 100,
          level: 1,
          versionHlc: _hlc(),
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<ValidationError>()),
      );
    });

    test('rename returns new Skill with updated name', () {
      final skill = _makeSkill();
      final renamed = skill.rename('Dart Programming', _hlc(2));
      expect(renamed.name, equals('Dart Programming'));
      expect(renamed.id, equals(skill.id));
    });

    test('softDelete marks skill as deleted (Invariant #10)', () {
      final skill = _makeSkill();
      final deleted = skill.softDelete(Id.uuidV7(), _hlc(2));
      expect(deleted.isDeleted, isTrue);
      // xpTotal is preserved — historical audit chain intact
      expect(deleted.xpTotal, equals(skill.xpTotal));
    });

    test('double softDelete throws ConflictError', () {
      final skill = _makeSkill().softDelete(Id.uuidV7(), _hlc(2));
      expect(
        () => skill.softDelete(Id.uuidV7(), _hlc(3)),
        throwsA(isA<ConflictError>()),
      );
    });
  });

  // ─── ToolEntity Tests ─────────────────────────────────────────────────

  group('ToolEntity domain entity (ADR-004)', () {
    test('creates valid tool', () {
      final tool = _makeTool();
      expect(tool.name, equals('VS Code'));
      expect(tool.isActive, isTrue);
    });

    test('rejects blank name', () {
      final now = Iso8601Timestamp.now();
      expect(
        () => ToolEntity(
          id: Id.uuidV7(),
          ownerId: Id.uuidV7(),
          name: '  ',
          toolType: 'software',
          versionHlc: _hlc(),
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<ValidationError>()),
      );
    });

    test('rename returns new Tool with updated name', () {
      final tool = _makeTool();
      final renamed = tool.rename('Neovim', _hlc(2));
      expect(renamed.name, equals('Neovim'));
      expect(renamed.id, equals(tool.id));
    });

    test('softDelete marks tool as deleted', () {
      final tool = _makeTool();
      final deleted = tool.softDelete(Id.uuidV7(), _hlc(2));
      expect(deleted.isDeleted, isTrue);
    });

    test('double softDelete throws ConflictError', () {
      final tool = _makeTool().softDelete(Id.uuidV7(), _hlc(2));
      expect(
        () => tool.softDelete(Id.uuidV7(), _hlc(3)),
        throwsA(isA<ConflictError>()),
      );
    });
  });
}
