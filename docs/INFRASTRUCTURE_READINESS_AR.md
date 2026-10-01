# تقرير جاهزية البنية التحتية المشتركة — KRATOS

**التاريخ:** 2026-09-27  
**النطاق:** Flutter Mobile + Flutter Web + Drift + Supabase/PostgreSQL + Auth + Sync  
**القرار:** **NOT READY — BLOCKED**

> هذا التقرير مبني على فحص المستودع الفعلي الحالي، وليس على تقرير تاريخي. لم تُجرَ أي تغييرات على مخطط الإنتاج أو قاعدة بيانات بعيدة.

## ملخص تنفيذي

الأساس المحلي موجود إلى حد جيد: تطبيق Flutter، قاعدة Drift محلية، مهاجرات PostgreSQL متسلسلة، طبقة Supabase Auth، وOutbox/Sync Engine. لكن لا يمكن اعتماد الربط الإنتاجي حاليًا للأسباب التالية:

1. لا تتوفر بيئة Flutter في جلسة التدقيق، لذلك لم يمكن تشغيل `flutter analyze` أو `flutter test` أو اختبار Web WASM فعليًا.
2. لا توجد بيانات اعتماد/مرجع مشروع Supabase متاحان في هذه الجلسة، لذلك حالة الهجرات البعيدة، RLS الفعلي، Storage، النسخ الاحتياطي، وSecurity Advisor غير متحققة.
3. يوجد تعارض مؤكد بين عقد المزامنة: `SupabaseSyncTransport` ينتظر `response.results` لكل عملية، بينما migration `0010_sync_rpc.sql` يعيد `status/applied/skipped` فقط.
4. `SupabaseAuthService.isDevBypassEnabled` يعيد `true` دائمًا، بما في ذلك عند استخدام خدمة Supabase، وهذا غير آمن للإنتاج.
5. تغطية سياسات RLS في migration `0009` جزئية؛ جداول كثيرة مفعّل عليها RLS في `0005` لكنها لا تحصل على سياسات CRUD/قراءة ظاهرة في `0009`.
6. يوجد اختبار إنتاجي قديم غير متوافق مع الحالة الحالية: يتوقع schema version = 12 وخصائص غير موجودة في `AppConfig`، بينما الكود الحالي يعرّف Drift schema version = 13 ويستخدم `supabaseAnonKey`.

---

## 1. البنية الحالية — PARTIAL

المسار المقصود والموجود في المستودع:

```text
Flutter Mobile/Web
        ↕
Drift local database
        ↕
SyncOutbox + SyncEngine
        ↕
Supabase Auth / RPC / tables
        ↕
PostgreSQL
```

الأدلة:

- `README.md` يصف Local-first مع Drift/SQLite وSupabase/PostgreSQL.
- `app/lib/data/drift/app_database.dart` يسجل جداول المجال وOutbox وTombstones.
- `app/lib/main.dart` يهيئ Supabase عند توفر `SUPABASE_URL` و`SUPABASE_PUBLISHABLE_KEY`.
- `app/lib/features/sync/domain/sync_engine.dart` يطبق push ثم pull عند عدم وجود عمليات معلقة.

لا يوجد Backend ثانٍ أو قاعدة ثانية ظاهرة في المستودع.

## 2. إعداد مشروع Supabase الحالي — UNVERIFIED

المستودع يعتمد على متغيرات build-time:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- fallback legacy: `SUPABASE_ANON_KEY`
- `APP_ENV`
- `ENABLE_DEBUG_AUTH_BYPASS`

المصدر: `app/lib/core/config/app_config.dart`.

لا توجد في جلسة التدقيق بيانات مشروع/بيئة Supabase يمكن استخدامها للتحقق من URL الحقيقي، project ref، أو الاتصال الفعلي. لا يمكن اعتبار وجود قيم افتراضية في الكود إعداد إنتاج.

## 3. حالة الهجرات — PARTIAL / UNVERIFIED REMOTE

الهجرات المحلية موجودة بالتسلسل `0001` حتى `0026`، وتشمل core، XP، sync، auth/RLS، RPCs، progression، Storage/analytics وغيرها.

المؤكد محليًا:

- النظام migration-driven.
- توجد إصلاحات لاحقة للقيود في `0024_xp_constraint_fixes.sql`.
- لا يجوز تنفيذ reset أو تعديل schema عن بعد خارج migration.

غير المتحقق:

- تاريخ الهجرات المطبق على قاعدة الإنتاج.
- divergence بين local وremote.
- project ref المستهدف.
- وجود migrations pending.

## 4. حالة المخطط البعيد — UNVERIFIED

لا يوجد اتصال فعلي بقاعدة PostgreSQL/Supabase في جلسة التدقيق. لذلك لا يمكن تأكيد:

- الجداول والأعمدة والأنواع والنماذج nullability.
- المفاتيح الأجنبية والفهارس.
- وجود migrations الأخيرة عن بعد.
- row counts أو سلامة البيانات.

وثيقة `docs/SCHEMA.md` تصف 30 جدولًا تاريخيًا، بينما `AppDatabase` الحالي يسجل جداول إضافية من موجات لاحقة؛ لذلك لا ينبغي اعتبار الوثيقة وحدها مرآة كاملة للحالة الحالية.

## 5. RLS — PARTIAL / BLOCKED

المؤكد:

- `0005_enable_rls.sql` يفعّل ويفرض RLS على مجموعة الجداول الأساسية.
- `0009_auth_and_rls_hardening.sql` يضيف سياسات مالك تفصيلية لبعض الجداول مثل `life_areas`, `categories`, `goals`, `tasks`, `projects`, `activities`, `sessions`, `notes`, `audios`, `skills`, `tools`.
- XP ledger لا يسمح بإدراج مباشر للمستخدم authenticated وفق الحارس الموجود في `0005`، والمسار المقصود هو RPC.

المخاطر/النواقص المؤكدة من قراءة النص:

- جداول مفعّل عليها RLS في `0005` لا تظهر لها في `0009` سياسات CRUD/SELECT مقابلة، ومنها على الأقل: `users`, `category_actions`, `category_xp_rule_versions`, `task_goal_links`, `xp_allocation_lines`, `user_streaks`, `streak_pauses`, `sync_cursors`, `achievements`, `evidence`, `ai_artifacts`, `files`, `links`, `attachment_links`, `skill_tools`, `task_tool_links`.
- قد يكون بعضها مقصودًا أن يكون deny-by-default أو محميًا عبر RPC، لكن ذلك غير موثق ومحتاج تحققًا مباشرًا من PostgreSQL.
- لا يمكن اعتماد cross-user isolation دون جلسات مستخدمين منفصلة واختبار RLS فعلي.

## 6. Auth — PARTIAL

الإيجابيات:

- `Supabase.initialize` يستخدم URL وpublishable key من البيئة.
- `SupabaseAuthService` يعتمد `currentUser` و`onAuthStateChange`.
- Supabase Flutter هو مسار persistence الأساسي المتوقع.
- توجد redirect مختلفة للويب والموبايل.

مانع إنتاجي:

- `SupabaseAuthService.isDevBypassEnabled` يعيد `true` دون ربطه بـ `AppConfig` أو البيئة.
- `signInWithDevBypass` موجود داخل الخدمة الحقيقية، وليس محصورًا إنشائيًا بخدمة Mock/Dev.
- يلزم منع bypass في production قبل الربط العام.

## 7. قاعدة Drift المحلية — PASS (ساكنًا) / UNVERIFIED runtime

المؤكد من الكود:

- Native SQLite للموبايل/سطح المكتب عبر `driftDatabase`.
- schema version الحالية: **13**.
- توجد MigrationStrategy تضيف أعمدة وجداول تدريجيًا، ولا توجد إعادة إنشاء مدمرة في `onUpgrade` الظاهر.
- جداول Outbox وCursors وTombstones مسجلة.

غير المتحقق:

- restart/update/migration على جهاز فعلي.
- بقاء بيانات المستخدم بعد تحديث التطبيق.
- عدم وجود مشاكل تشغيلية في codegen أو SQLite native.

## 8. Web Drift persistence — PARTIAL / UNVERIFIED

الكود يحدد:

- `sqlite3.wasm`
- `drift_worker.js`
- `DriftWebOptions`
- اسم قاعدة ثابت `kratos_db`

لكن لم يمكن تشغيل Web build أو browser runtime في جلسة التدقيق، ولم يُتحقق من:

- chosen implementation الفعلي.
- OPFS/IndexedDB persistence.
- fallback إلى ذاكرة مؤقتة.
- بقاء البيانات بعد reload.
- عدم حذف قاعدة المتصفح عند تحديث الأصول.

## 9. Sync — BLOCKED

المسار المحلي في `SyncEngine` يحافظ على:

- pending outbox.
- retry وexponential backoff.
- عدم مسح البيانات عند فشل الشبكة.
- tombstone/pending protection في pull transport.

لكن يوجد تعارض عقدي مباشر:

- `app/lib/features/sync/data/supabase_sync_transport.dart` يرفض الاستجابة ما لم تكن `response['results']` قائمة acknowledgements تحتوي `seq` و`status` لكل عنصر.
- `server/migrations/0010_sync_rpc.sql` يعيد في نهايته JSON يحوي `status`, `applied`, `skipped` فقط ولا ينشئ `results`.

النتيجة: حتى لو نجح استدعاء RPC، سيصنف النقل الاستجابة كـ `missing_acknowledgements` ولن يؤكد عمليات Outbox.

## 10. Outbox — PARTIAL

المسار المحلي موجود، و`record_xp_event` يضيف event إلى `sync_outbox` في نفس المعاملة وفق migration `0006`.

لكن اعتماد Outbox الإنتاجي غير مكتمل حتى إصلاح عقد acknowledgement والتحقق من:

- كل أنواع entities الحديثة.
- push/pull فعليًا.
- deduplication باستخدام idempotency keys.
- ack ثم read-back من الخادم.

## 11. Storage — UNVERIFIED

لا يمكن من المستودع وحده اعتماد bucket names، private/public، limits، MIME types، أو سياسات `storage.objects`. يلزم فحص مشروع Supabase الفعلي وSecurity Advisor.

## 12. Backups — UNVERIFIED

لا يوجد تحقق فعلي من خطة النسخ الاحتياطي أو retention أو PITR. لا ينبغي إعلان backup readiness بناءً على وجود `BackupService` محلي فقط.

## 13. Environment — PARTIAL

الإيجابيات:

- لا يظهر service-role key أو database password في `AppConfig`.
- الإعداد build-time وليس hardcoded production credentials.

النواقص:

- القيم الفعلية غير متاحة للتحقق.
- يجب التأكد أن release pipeline يحقن publishable key الصحيح، ولا يحقن أي secret/server key.
- يجب تعطيل debug bypass في release وفي بيئة production.

## 14. Runtime verification — BLOCKED

لم تُنفذ الاختبارات المطلوبة لأن Flutter CLI غير متاح في بيئة التدقيق الحالية، ولا يوجد اتصال Supabase فعلي.

لم يتم إثبات:

- sign-in → close → reopen → session restore.
- cloud read/create/update/delete.
- cross-user RLS denial.
- offline write → Outbox → reconnect → server read-back.
- no duplicate mutation.
- local migration preservation.
- Web WASM persistence.
- XP idempotency وعدم التكرار.

## 15. BLOCKERS

| الأولوية | المانع | الدليل | الإجراء المطلوب |
|---|---|---|---|
| P0 | Sync acknowledgement contract mismatch | `supabase_sync_transport.dart` مقابل migration `0010` | توحيد العقد: إما أن يعيد RPC `results` لكل seq أو يغير transport بعقد موثق وقابل للتأكد، ثم إضافة migration واختبار فعلي |
| P0 | Dev bypass مفعّل دائمًا في SupabaseAuthService | getter في `supabase_auth_service.dart` | ربطه بتهيئة البيئة ومنعه في production، ثم اختبار release |
| P0 | RLS/remote schema غير متحققين | لا يوجد اتصال بمشروع Supabase | فحص migration history و`pg_policies` و`pg_class` وSecurity Advisor بحساب/مشروع صحيح |
| P1 | Flutter runtime غير متاح | `flutter: command not found` | تشغيل التدقيق في بيئة تحتوي Flutter SDK ثم analyze/test/build web |
| P1 | اختبار إنتاجي قديم غير متطابق | test يتوقع schema 12 وخصائص غير موجودة | تحديث الاختبار أو توثيق سبب التوقع، ثم تشغيله بدل اعتباره دليلًا |
| P1 | Web persistence غير متحقق | لا browser runtime | تشغيل build/preview/reload واختبار chosen implementation وبيانات OPFS/IndexedDB |
| P1 | Storage/backups غير متحققين | لا اتصال Supabase | فحص الإعداد الفعلي وتوثيق النتائج والتحذيرات |

## 16. قرار READY / NOT READY

**NOT READY — BLOCKED**

لا يُنصح بربط مستخدمين حقيقيين أو اعتماد الإنتاج قبل:

1. توفير بيئة Flutter للاختبارات.
2. توفير اتصال آمن إلى مشروع Supabase الصحيح.
3. إصلاح عقد `apply_sync_batch`/acknowledgements.
4. تعطيل dev bypass في production.
5. إكمال/توثيق سياسات RLS لكل جدول مكشوف أو RPC محمي.
6. تنفيذ runtime verification للموبايل والويب وRLS وoffline sync وXP idempotency.
7. توثيق migration history وStorage وbackup وSite URL/redirect URLs.

## الملفات التي تم فحصها

- `app/lib/main.dart`
- `app/lib/core/config/app_config.dart`
- `app/lib/data/drift/app_database.dart`
- `app/lib/features/auth/data/supabase_auth_service.dart`
- `app/lib/features/sync/data/supabase_sync_transport.dart`
- `app/lib/features/sync/domain/sync_engine.dart`
- `server/migrations/0002_init_xp_ledger.sql`
- `server/migrations/0005_enable_rls.sql`
- `server/migrations/0006_init_xp_ledger_rpc.sql`
- `server/migrations/0009_auth_and_rls_hardening.sql`
- `server/migrations/0010_sync_rpc.sql`
- `server/migrations/0024_xp_constraint_fixes.sql`
- `docs/SCHEMA.md`
- `docs/IMPLEMENTATION_STATUS.md`
- `app/test/features/production_database_sync_integration_test.dart`

## ملاحظة تغيير التحكم

لم تُجرَ أي تغييرات على كود التطبيق أو migrations أو قاعدة بيانات بعيدة خلال هذا التدقيق. هذا مقصود لأن إصلاح Sync/RLS/Auth دون بيئة تنفيذ واختبار Supabase الفعلية قد يؤدي إلى تأكيدات خاطئة أو فقدان عمليات Outbox.
