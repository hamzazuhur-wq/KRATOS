# KRATOS Insights Analytics — Reference-Exact Rebuild (State & Architecture)

> Master Visual Reference: `media_1791477681870_68cfb93d.jpg`
> Status: **COMPLETE AND VERIFIED**
> Date: 2026-10-08
> Test Suite: 116 / 116 Tests Passing (`test/features/analytics/`)
> Flutter Web Build: SUCCESS (`build/web`)
> Playwright Visual QA: 10 Viewports / Themes Verified

---

## 1. Core Architectural Contract
- **No generic Analytics Insights list**: The Insights experience is NOT a generic list of metric comparison cards ("Total XP increased", etc.).
- **Visual & Structural match to reference**: The Insights page visually and structurally mirrors `media_1791477681870_68cfb93d.jpg`:
  1. Section 1: Focus Time summary (Hero card with total focus time, trend, 3 metric badges, and Goal Progress circular gauge)
  2. Section 2: Activity Pattern (Daily/Weekly/Monthly interactive bar chart with tooltip)
  3. Section 3: Focus by Day (7-day bar chart with duration labels above bars)
  4. Section 4: Focus by Hour (7x24 heatmap with Mon-Sun rows and hour buckets in KRATOS lime)
  5. Section 5: Insights (Derived patterns: Peak Focus Time, Most Focused Day, Focus Trend, Deep Work Share, Focus Concentration, Strongest Routine, Avg Session Length) + View All action that displays all derived patterns in an interactive modal.
- **Truthful Data Only**: All values are calculated strictly from real KRATOS Session & Analytics data. Zero hardcoded illustrative numbers.
- **Single Source of Truth**: Drift `Sessions` table → `FocusTimeAggregator` → `FocusTimeSnapshot` & `DerivedFocusInsight`s → UI.

---

## 2. Reference-to-Implementation Coverage Table

| Section / Component | Reference Visual | Data Source | Implementation | Status |
|---|---|---|---|---|
| **Header Bar** | KRATOS logo, Lv 12 XP progress bar, Bell, Avatar | KratosApp / AppShell | `AppShell` & `InsightsScreen` | VERIFIED |
| **Section 1: Focus Time Hero** | "Focus Time", subtitle, "This Week" pill, big duration, trend badge, 3 metric badges (Sessions, Avg. Session, Longest), Goal Progress gauge | Drift `Sessions` / `Goals` | `FocusTimeHeroCard` | VERIFIED |
| **Section 2: Activity Pattern** | "Activity Pattern", Daily/Weekly/Monthly toggle, bar chart with gradient fill, grid lines, tooltip popover | Drift `Sessions` | `FocusTimeActivityPatternCard` | VERIFIED |
| **Section 3: Focus by Day** | "Focus by Day", subtitle, 7 bars for Mon..Sun with duration label above each bar | `FocusTimeSnapshot.weekdayTotals` | `FocusTimeByDayCard` | VERIFIED |
| **Section 4: Focus by Hour** | "Focus by Hour", 7x24 heatmap with Mon..Sun rows, 6am/12pm/6pm/12am axis | `FocusTimeSnapshot.weekdayHour` | `FocusTimeByHourCard` | VERIFIED |
| **Section 5: Derived Insights** | "Insights", subtitle, 3 derived cards with icon box, title, value/window, explanation, and "View All →" button | Derived Focus Insights Engine | `FocusTimeInsightsCard` with `snapshot.previewInsights` | VERIFIED |
| **Section 5: View All** | "View All →" action | Derived Focus Insights Engine | Modal sheet/dialog listing all `snapshot.derivedInsights` with icons, titles, and metrics | VERIFIED |

---

## 3. Implementation Phases Checklist

| Phase | Description | Status |
|---|---|---|
| **Phase 1** | Audit current implementation and existing data | DONE |
| **Phase 2** | Map reference components to KRATOS data sources & coverage table | DONE |
| **Phase 3** | Implement missing domain calculations (DerivedFocusInsights in `focus_time_models.dart`) | DONE |
| **Phase 4** | Build/rebuild the complete Insights page structure in `InsightsScreen` & `AnalyticsFocusTimeSection` | DONE |
| **Phase 5** | Verify & refine Activity Pattern card | DONE |
| **Phase 6** | Verify & refine Focus by Day card | DONE |
| **Phase 7** | Verify & refine Focus by Hour heatmap card | DONE |
| **Phase 8** | Implement derived Insights card matching reference visual | DONE |
| **Phase 9** | Implement View All behavior (shows all derived insights in interactive bottom sheet / modal) | DONE |
| **Phase 10** | Light/Dark theme refinement matching reference dual-mode design | DONE |
| **Phase 11** | Responsive refinement (Desktop side-by-side, Tablet wrap, Mobile stacked) | DONE |
| **Phase 12** | Automated unit & widget tests (116 tests passing) | DONE |
| **Phase 13** | Flutter Web visual QA with Playwright screenshots comparison (10 screenshots captured & inspected) | DONE |
| **Phase 14** | Final regression & sign-off | DONE |

---

## 4. Visual QA Screenshots

Captured via `tools/capture_insights_qa.js`:
- `screenshots/insights_desktop_1440x900_dark.png`
- `screenshots/insights_desktop_1440x900_light.png`
- `screenshots/insights_tablet_820x1180_dark.png`
- `screenshots/insights_tablet_820x1180_light.png`
- `screenshots/insights_mobile_390x844_dark.png`
- `screenshots/insights_mobile_390x844_light.png`
- `screenshots/insights_dashboard_context_dark.png`
- `screenshots/insights_dashboard_context_light.png`
- `screenshots/insights_empty_state_dark.png`
- `screenshots/insights_empty_state_light.png`
