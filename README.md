#  StepSure

### AI-Powered Real-Time Gait Rehabilitation Assistant

StepSure is a cross-platform Flutter application that transforms a smartphone camera into an intelligent physiotherapy assistant.

It performs real-time gait analysis using pose estimation, calculates biomechanical recovery metrics, evaluates fall risk, and generates AI-powered rehabilitation reports with exportable medical PDFs.

---

# 🚀 Overview

StepSure is designed for stroke survivors and individuals undergoing lower-limb rehabilitation who need:

* Objective gait monitoring at home
* Continuous recovery tracking
* Real-time corrective feedback
* Structured rehabilitation reports

The system combines:

* Computer Vision (Pose Estimation)
* Biomechanical Analysis
* AI-generated Medical Reports
* Cloud-based Session Storage (Supabase)

---

# 🧠 Core Capabilities

## ✅ Real-Time Gait Analysis

* Live camera pose detection
* Skeleton overlay aligned to body orientation
* Joint angle computation (hip, knee, ankle)
* Step detection using hysteresis-based state machine
* Cadence, symmetry, and stability metrics

## 📹 Video Upload Analysis

* Frame extraction at 5 FPS
* Per-frame pose detection
* Session-level biomechanical aggregation
* Fall risk classification

## 📊 Recovery Metrics

* Recovery Score (0–100)
* Gait Symmetry Index
* Stride Consistency
* Stability Indicator
* Fall Risk Classification (Low / Moderate / High)

## 📈 Progress Tracking

* Historical session storage
* Improvement trend visualization
* Longitudinal recovery monitoring

## 🧾 AI Rehab Report Generator

* Natural language session summary
* Abnormality identification
* Exercise suggestions
* Risk explanation
* Exportable medical-grade PDF report

## ☁ Supabase Backend

* Authentication
* PostgreSQL session storage
* Secure video upload
* Cloud sync

---

# 🏗 System Architecture

User
→ Flutter App
→ Camera / Video Input
→ Pose Detection (ML Kit)
→ GaitAnalysisService
→ Session Metrics Computation
→ Supabase Storage
→ AI Report Generator
→ Results Dashboard + PDF Export

---

# 🛠 Technical Implementation Details

## 1️⃣ Step Detection (gait_analysis_service.dart)

Replaced naive angle threshold logic with a **per-leg rising-edge state machine using 20° hysteresis**:

* Arm condition: <140°
* Fire condition: >160°

This prevents false triggering and ensures medically realistic cadence instead of inflated 10–30× step counts.

---

## 2️⃣ Camera Input Handling (recording_screen.dart)

Platform-specific image processing:

* Android → Concatenates YUV planes (NV21 format)
* iOS → Uses BGRA8888 single-plane format
* Dynamically reads sensor orientation from:
  `_cameraController.description.sensorOrientation`
* No hardcoded rotation assumptions

---

## 3️⃣ Skeleton Coordinate Transformation (skeleton_painter.dart)

* Accepts `InputImageRotation`
* Applies correct axis swap for:

  * 0°
  * 90°
  * 180°
  * 270°
* Ensures accurate body alignment
* Fixes quadrant misalignment issues

---

## 4️⃣ Video Analysis Pipeline (video_analysis_service.dart)

* Extracts frames at 5 FPS
* Uses `VideoPlayerController`
* Captures frames via `RenderRepaintBoundary.toImage()`
* Uses `PoseDetectionMode.single` (correct for non-sequential frames)
* Feeds frames to `GaitAnalysisService.processFrame()`
* Aggregates metrics using `computeSessionMetrics()`
* Throws descriptive errors if:

  * Video too short
  * <5 pose detections

---

## 5️⃣ Upload Screen Processing (upload_screen.dart)

* Off-screen hidden VideoPlayer
* RepaintBoundary positioned at `left: -4000` to preserve key integrity
* Full ML pipeline execution:

  * Frame extraction
  * Pose detection
  * Gait analysis
  * Session save to Supabase
  * PDF generation
  * Navigation to ResultsScreen
* Live progress percentage display
* Retry mechanism on failure

---

## 6️⃣ PDF Report Generator (pdf_generator.dart)

Generates a structured A4 medical report:

Includes:

* Header bar
* Score & Risk banner
* 6-row metrics table (color-coded Normal/Good/Poor)
* AI-generated summary
* Abnormalities list
* Exercise suggestions
* Risk explanation
* Medical disclaimer footer

Functions:

* `generateSessionReport(session, report) → Uint8List`
* `sharePdf()` → opens system share sheet

---

## 7️⃣ Results Screen (results_screen.dart)

* Displays computed metrics
* Risk classification badge
* “Export PDF Report” button
* Loading state during PDF generation

---

# 📂 Folder Structure

```
lib/
 ├── core/
 ├── data/
 ├── domain/
 ├── features/
 │    ├── recording/
 │    ├── upload/
 │    ├── results/
 │    ├── analysis/
 ├── services/
 ├── presentation/
 ├── widgets/
assets/
test/
```

---

# 📱 Supported Platforms

* Android
* iOS
* Web (limited camera support)
* Windows
* macOS
* Linux

---

# 🔐 Security & Data Handling

* Supabase Authentication
* Secure PostgreSQL storage
* Controlled access to uploaded videos
* No third-party sharing
* Designed for future HIPAA-compliant expansion

---

# ⚠ Limitations

* Prototype stage (no clinical validation yet)
* Camera positioning affects accuracy
* Lighting conditions impact pose detection
* Not a replacement for licensed physiotherapy

---

# 🔮 Future Roadmap

* Clinician dashboard
* Remote monitoring portal
* Multi-language support
* Wearable sensor integration
* Clinical trial validation
* Predictive relapse detection

---

# 🧪 Getting Started

## 1. Install Flutter

[https://docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install)

## 2. Clone Repository

```
git clone <repo-url>
cd StepSure
```

## 3. Install Dependencies

```
flutter pub get
```

## 4. Configure Supabase

* Add your Supabase URL
* Add anon/public key
* Configure storage bucket for videos

## 5. Run Application

```
flutter run
```

---

# 📄 License

(Academic Use).

---

# 👩‍⚕ Disclaimer

StepSure is a research and prototype application.
It does not replace professional medical diagnosis or treatment.
Always consult a licensed physiotherapist or medical professional for rehabilitation guidance.

---


