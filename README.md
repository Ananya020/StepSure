
<div align="center">

<br/>

# StepSure

**AI-Powered Smartphone Gait Analysis for Stroke Rehabilitation**

*Walk with confidence. Recover with intelligence.*

<br/>

[![Flutter](https://img.shields.io/badge/Flutter-3.19+-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.3+-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=flat-square&logo=supabase&logoColor=white)](https://supabase.com)
[![Google ML Kit](https://img.shields.io/badge/ML_Kit-Pose_Detection-4285F4?style=flat-square&logo=google&logoColor=white)](https://developers.google.com/ml-kit)
[![Gemini AI](https://img.shields.io/badge/Gemini-AI_Reports-8E75B2?style=flat-square&logo=google&logoColor=white)](https://deepmind.google/technologies/gemini)
[![License](https://img.shields.io/badge/License-MIT-1F7A7A?style=flat-square)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-Welcome-3AABAB?style=flat-square)](CONTRIBUTING.md)

<br/>

<img src="https://raw.githubusercontent.com/your-username/stepsure/main/assets/screenshots/hero.png" alt="StepSure App" width="800"/>

<br/>

> *"The greatest wealth is health." — Virgil*
>
> 80 million stroke survivors worldwide need rehabilitation. Most can't access it.
> StepSure brings a clinical-grade physiotherapist into every pocket, available 24/7, for ₹199/month.

<br/>

</div>

---

## What is StepSure?

StepSure is a cross-platform Flutter application that uses AI to analyse a patient's walking pattern through their smartphone camera, then generates a personalised rehabilitation programme. No wearables. No clinic visits required. No internet connection needed during analysis.

The app is designed specifically for **post-stroke gait rehabilitation** — a field where 95% of rural patients currently receive zero professional support between the rare clinic visits they can access.

---

## The Problem We're Solving

| Reality | Numbers |
|---|---|
| Stroke survivors who need rehabilitation | **80 million** worldwide |
| Average wait for physiotherapy appointment | **6 weeks** |
| Rural patients who never see a physiotherapist | **95%** |
| Cost per physio session (India) | **₹1,500 – 3,000** |
| Cost of StepSure per month | **₹199** |

Between clinic appointments, patients walk incorrectly for weeks — reinforcing bad movement patterns and causing long-term damage. Clinicians have zero visibility into what's happening at home. StepSure closes that gap.

---

## Core Features

### 🦿 Gait Analysis Engine
- **33-landmark skeletal mapping** — Google ML Kit Pose Detection processes every frame of a 30-second walk
- **7 deficit classifications** — symmetry, cadence, stride length, knee deviation, trunk lean, balance instability, hip flexion
- **Fall risk scoring** — Low / Moderate / High, calculated from stride variability coefficient of variation
- **Recovery score** — composite metric tracked session-to-session: `(Symmetry×0.40) + (Cadence×0.20) + (Consistency×0.20) + (100−JointDev)×0.20`
- **100% on-device** — analysis runs locally via the device NPU; no data leaves the phone during recording

### 🎯 AI Exercise Prescription
- **Rule-based deficit matching** — each gait deficit triggers a specific set of targeted exercises
- **18-exercise library** — from single-leg balance to metronome walking, all medically validated
- **3D Mixamo-rendered animations** — professional skeletal character animations, rendered via Blender and played as looping videos in Flutter
- **Voice guidance** — real-time audio cues using `flutter_tts` with 6-second cooldown per cue

### 📊 Progress Tracking
- **Session-over-session recovery curves** — visualised with `fl_chart`
- **Gemini-powered rehab reports** — AI-generated clinical PDF summaries shareable with physiotherapists
- **Clinician dashboard** — real-time gait metrics for enrolled patients (B2B feature)

### 🔒 Clinical Safety
- Conservative exercise defaults — system never prescribes at the edge of capability
- High fall risk → consultation alert (not more exercises)
- Camera confidence scoring — low-quality recordings prompt re-record rather than generating unreliable results

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        StepSure App                             │
│                                                                 │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────┐    │
│  │  Presentation│    │    Domain    │    │      Data       │    │
│  │   Screens   │───▶│   Services   │───▶│    Services     │    │
│  │  & Widgets  │    │  & Models    │    │  & Repositories │    │
│  └─────────────┘    └──────────────┘    └─────────────────┘    │
│         │                  │                      │             │
│         ▼                  ▼                      ▼             │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────┐    │
│  │   Flutter   │    │  ML Kit Pose │    │   Supabase      │    │
│  │   Provider  │    │  Detection   │    │  Auth + DB +    │    │
│  │    State    │    │  (on-device) │    │  Storage + Edge │    │
│  └─────────────┘    └──────────────┘    └─────────────────┘    │
│                                                    │             │
│                                         ┌──────────▼──────────┐ │
│                                         │    Gemini AI Edge   │ │
│                                         │  Function (reports) │ │
│                                         └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Framework** | Flutter 3.19+ (Dart) | Cross-platform iOS + Android |
| **State Management** | Provider | App-wide state |
| **Pose Estimation** | Google ML Kit | 33-landmark detection at 30fps |
| **AI Reports** | Gemini AI (Supabase Edge Function) | Clinical PDF generation |
| **Backend** | Supabase | Auth, PostgreSQL, Storage, RLS |
| **3D Animations** | Mixamo → Blender → Flutter `video_player` | Exercise character animations |
| **Charts** | fl_chart | Recovery score visualisation |
| **Voice Guidance** | flutter_tts | Real-time audio cues |
| **PDF Export** | pdf + printing | Downloadable reports |
| **Notifications** | flutter_local_notifications | Exercise reminders |

---

## Project Structure

```
lib/
├── main.dart                          # App entry + Supabase init
├── core/
│   ├── constants/
│   │   └── design_system.dart         # Teal medical colour palette + typography
│   └── widgets/
│       └── widgets.dart               # Shared component library (20+ components)
├── data/
│   ├── supabase_service.dart          # All DB operations + auth
│   ├── pose_service.dart              # ML Kit pose detection pipeline
│   └── local_storage.dart            # Offline caching
├── domain/
│   ├── models/
│   │   ├── session_model.dart         # Gait session data structure
│   │   └── exercise_model.dart        # Exercise + AI prescription engine
│   ├── services/
│   │   ├── exercise_session_controller.dart  # Exercise state machine
│   │   └── voice_guidance_service.dart       # TTS with cooldown logic
│   ├── gait_analysis_service.dart     # Core gait metric calculations
│   ├── score_calculator.dart          # Recovery score + fall risk
│   ├── feedback_engine.dart           # Rule-based real-time cues
│   └── report_generator.dart          # PDF report builder
└── presentation/
    └── screens/
        ├── auth/                      # Login, Register, Onboarding
        ├── home/                      # Dashboard + exercise banner
        ├── instructions/              # Pre-recording setup guide
        ├── recording/                 # Live camera + ML Kit
        ├── results/                   # Gait analysis results
        ├── progress/                  # Recovery charts
        ├── report/                    # Report list + detail
        ├── profile/                   # Patient profile + settings
        ├── upload/                    # Video upload pipeline
        ├── exercise_recommendation/   # AI exercise prescription UI
        └── exercise_mode/             # 3D animated exercise sessions
            ├── exercise_video_player.dart     # Mixamo video widget
            ├── exercise_video_card.dart       # Exercise mode card
            └── exercise_thumb_card.dart       # Recommendation thumbnails
```

---

## Gait Analysis — How It Works

```
Patient walks 30 seconds
        │
        ▼
Camera captures video frames
        │
        ▼
ML Kit extracts 33 landmarks per frame (x, y, z + confidence)
        │
        ▼
Temporal signal processing
  ├── Heel strike detection (ankle vertical minima)
  ├── Stride time extraction
  ├── Cadence calculation (steps/minute)
  ├── Stride length estimation (hip-ankle geometry)
  └── Joint angle computation (knee, trunk, hip)
        │
        ▼
Deficit classification (7 checks)
  ├── Symmetry Index < 60%    → Poor symmetry flag
  ├── Cadence < 70 spm        → Low cadence flag
  ├── Stride length < 0.9m   → Short stride flag
  ├── Knee deviation > 30°    → Knee instability flag
  ├── Trunk lean > 8°         → Forward lean flag
  ├── Stride variability CV   → Fall risk (Low/Med/High)
  └── Consistency < 50%       → Hip flexion flag
        │
        ▼
Recovery Score calculation
  (Symmetry×0.40) + (Cadence×0.20) + (Consistency×0.20) + (100−JointDev)×0.20
        │
        ▼
Gemini AI generates personalised exercise prescription + PDF report
```

---

## Exercise Prescription Engine

Each gait deficit maps to targeted exercises:

| Deficit | Exercises Prescribed |
|---|---|
| Poor symmetry (< 60%) | Alternating Step Drill, Lateral Weight Shift |
| Low cadence (< 70 spm) | Metronome Walking, Fast Feet Drill |
| Short stride (< 0.9m) | Step-Length Training, Exaggerated Marching |
| Knee deviation (> 30°) | Knee Stability Squat, Terminal Knee Extension |
| Forward trunk lean (> 8°) | Posture Correction, Chest Opener |
| High fall risk | Single-Leg Balance, Tandem Tightrope Walk |
| Hip flexion deficit | Hip Flexor Lunge, Calf Raises |

---

## 3D Animation Pipeline

StepSure uses professional Mixamo character animations — not hand-coded skeletons. The pipeline:

```
Mixamo.com → Download FBX (With Skin, In Place, 30fps)
     │
     ▼
Blender (render_pipeline.py)
  ├── 4-point medical studio lighting
  ├── Teal material palette applied
  ├── 30° three-quarter camera view
  └── Renders looping MP4 per exercise
     │
     ▼
post_process.py (FFmpeg)
  ├── Re-encode: H.264 baseline, +faststart, yuv420p (iOS compatible)
  ├── Resize to 512×512
  └── Extract thumbnail PNGs
     │
     ▼
Flutter video_player widget
  ├── ExerciseVideoCache — preloads all 12 videos on HomeScreen
  ├── ExerciseVideoCard — full exercise mode card
  └── ExerciseThumbCard — recommendation list preview
```

**12 rendered exercises:** walk · march · squat · balance · tandem · calf · lunge · posture · shift · metro · fast · chest

---

## Database Schema

```sql
-- User profiles
profiles (id, full_name, age, stroke_date, affected_side, walking_aid, reminder_time)

-- Gait recording sessions
sessions (id, user_id, recorded_at, duration_seconds, video_url, status)

-- Computed gait metrics per session
gait_metrics (
  id, session_id, symmetry_index, cadence_spm, stride_length_m,
  joint_deviation_deg, trunk_lean_deg, stride_consistency,
  fall_risk_level, recovery_score, deficit_flags[]
)

-- AI-generated clinical reports
reports (id, user_id, session_id, generated_at, content_json, pdf_url)
```

Row-Level Security (RLS) enforces `auth.uid() = user_id` on all tables. No cross-patient data access is possible.

---

## Getting Started

### Prerequisites

```bash
Flutter SDK 3.19+
Dart 3.3+
Android Studio / Xcode
Supabase account (free tier works)
```

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/your-username/stepsure.git
cd stepsure

# 2. Install dependencies
flutter pub get

# 3. Configure Supabase
# Copy the example config
cp lib/core/constants/supabase_config.example.dart \
   lib/core/constants/supabase_config.dart

# Edit with your Supabase project credentials
# SUPABASE_URL=https://your-project.supabase.co
# SUPABASE_ANON_KEY=your-anon-key

# 4. Run the database migrations
# Paste the contents of supabase/migrations/ into your
# Supabase SQL editor and execute

# 5. Run the app
flutter run
```

### Environment Configuration

```dart
// lib/core/constants/supabase_config.dart
const String supabaseUrl = 'YOUR_SUPABASE_URL';
const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### Running Tests

```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# Analyse code
flutter analyze
```

---

## pubspec.yaml — Key Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Backend
  supabase_flutter: ^2.3.0

  # AI / ML
  google_mlkit_pose_detection: ^0.10.0

  # UI / Charts
  fl_chart: ^0.66.0
  video_player: ^2.8.3

  # Audio
  flutter_tts: ^4.0.2

  # PDF
  pdf: ^3.10.8
  printing: ^5.12.0

  # Notifications
  flutter_local_notifications: ^17.0.0

  # Camera / Video
  camera: ^0.10.5+9
  image_picker: ^1.0.7

  # State
  provider: ^6.1.2
```

---

## Design System

StepSure uses a **medical teal** palette designed for clinical clarity and accessibility.

```dart
// Primary palette
static const Color teal       = Color(0xFF3AABAB);  // Primary actions
static const Color tealDark   = Color(0xFF1F7A7A);  // Headers, emphasis
static const Color tealLight  = Color(0xFF7DD4D4);  // Secondary text
static const Color tealPale   = Color(0xFFE0F5F5);  // Backgrounds, cards

// Backgrounds
static const Color bgGradientStart = Color(0xFFDFF2F7);
static const Color bgGradientEnd   = Color(0xFFC2E5EF);

// Semantic
static const Color warning    = Color(0xFFF5A623);  // Fall risk moderate
static const Color danger     = Color(0xFFE05454);  // Fall risk high
static const Color success    = Color(0xFF4AE08A);  // Recovery milestones

// Typography: Nunito (rounded, approachable, clinical-friendly)
```

---

## Screens

| Screen | Description |
|---|---|
| `LoginScreen` | Email/password auth with Supabase |
| `RegisterScreen` | New account creation |
| `OnboardingScreen` | Patient profile setup (stroke date, affected side, walking aid) |
| `HomeScreen` | Recovery score dashboard, session history, exercise banner |
| `InstructionsScreen` | Pre-recording camera setup guide |
| `RecordingScreen` | Live camera + real-time ML Kit pose overlay |
| `ResultsScreen` | Full gait analysis results with deficit breakdown |
| `ProgressScreen` | Recovery score chart over time |
| `ExerciseRecommendationScreen` | AI-prescribed exercise library |
| `ExerciseModeScreen` | 3D animated guided exercise session with voice |
| `ExerciseCompleteScreen` | Session summary + rep count |
| `ReportsListScreen` | All Gemini-generated reports |
| `ReportDetailScreen` | Full AI report with PDF export |
| `ProfileScreen` | Patient settings, reminders, account |
| `UploadScreen` | Upload existing video for analysis |

---

## Contributing

Contributions are welcome. StepSure is an open project and clinical impact scales with the quality of the codebase.

```bash
# Fork the repo
# Create a feature branch
git checkout -b feature/your-feature-name

# Make your changes
# Run tests
flutter test

# Commit with a clear message
git commit -m "feat: add real-time knee angle overlay during recording"

# Push and open a PR
git push origin feature/your-feature-name
```

**Areas we'd particularly value contributions in:**
- Real-time exercise form correction (Phase 2 feature)
- Additional language support for voice guidance
- Clinical validation tooling
- Accessibility improvements
- Performance optimisation on low-end Android devices

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a PR.

---

## Roadmap

- [x] Core gait analysis engine (ML Kit + 7 deficit classifiers)
- [x] AI exercise prescription engine (18-exercise library)
- [x] 3D Mixamo-rendered exercise animations
- [x] Gemini AI clinical report generation
- [x] Supabase backend with RLS
- [x] Voice guidance system
- [x] Fall risk detection
- [x] Recovery score tracking
- [ ] Real-time exercise form correction (v2)
- [ ] Clinician monitoring dashboard (v2)
- [ ] CDSCO medical device registration
- [ ] International language support (Hindi, Tamil, Telugu)
- [ ] Apple Watch / WearOS integration
- [ ] Wearable fall detection alerts
- [ ] Predictive gait deterioration alerts

---

## Clinical Disclaimer

StepSure is a **wellness and monitoring tool**, not a medical device making clinical diagnoses. The app is designed to support, not replace, professional physiotherapy care.

- All exercise prescriptions are conservative by default
- High fall risk triggers a consultation recommendation, not more exercises
- Analysis results should be shared with and interpreted by a qualified physiotherapist
- Clinical validation (Phase 1 concurrent validity study) is in progress

---

## License

```
MIT License

Copyright (c) 2026 StepSure

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

---

## Acknowledgements

- [Google ML Kit](https://developers.google.com/ml-kit) — Pose detection backbone
- [Mixamo](https://www.mixamo.com) — Character animation library
- [Supabase](https://supabase.com) — Open-source Firebase alternative
- [Gemini AI](https://deepmind.google/technologies/gemini) — Clinical report intelligence
- [flutter_tts](https://pub.dev/packages/flutter_tts) — Voice guidance
- [fl_chart](https://pub.dev/packages/fl_chart) — Recovery visualisation

---

<div align="center">

<br/>

**Built with clinical purpose. Designed for everyone.**

*Every session recorded. Every step analysed. Every patient closer to walking again.*

<br/>

[![Star this repo](https://img.shields.io/github/stars/your-username/stepsure?style=social)](https://github.com/your-username/stepsure)
[![Follow](https://img.shields.io/github/followers/your-username?style=social)](https://github.com/your-username)

<br/>

*StepSure — Bengaluru, India · [stepsure.health](https://stepsure.health) · [hello@stepsure.health](mailto:hello@stepsure.health)*

</div>
