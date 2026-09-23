# KRATOS — Store Listing Metadata & Permissions Manifest

## App Title
**KRATOS: Real-Life RPG & Personal OS**

## Short Description (80 characters)
Gamify your real life. Track habits, gain XP, conquer goals, and level up.

## Full Description
Welcome to KRATOS — the futuristic personal operating system that transforms your personal growth, fitness, career, and daily habits into a rewarding life-gamification RPG.

### Features
- ⚡ **Append-Only XP Ledger**: Earn mathematically verified XP for completing focus sessions, workouts, and goals.
- 🛡️ **Life Area Progression**: Level up across Career, Health, Mind, and Craft with tailored 100-level curves and 6 distinct tiers (Bronze to Mythic).
- 🔥 **Streak Society**: Preserve momentum with intelligent freeze tokens and unlock exclusive milestone badges.
- 🧠 **AI Habit Coach & QuickCapture**: Multimodal voice memo transcription, automated plan decomposition, and predictive burnout detection.
- 🌐 **Offline-First Synchronization**: Work completely offline with local Drift database and seamless multi-device cloud convergence.
- 💎 **Liquid Glass Design**: Experience the cutting-edge Dark Volcanic and Acid Lime design language.

## System Permissions Declarations
| Permission | Target | Technical Justification |
|---|---|---|
| `RECORD_AUDIO` | Voice Memos | Required for capturing QuickCapture voice notes for AI Whisper transcription. |
| `POST_NOTIFICATIONS` | Reminders | Delivers focus session completion alerts and streak protection warnings. |
| `FOREGROUND_SERVICE` | Live Activity | Keeps the focus session countdown ticker running smoothly on lock screen widgets. |
