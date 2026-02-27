# 🎨 ColorSense
### AI-Powered Color Detection App for Colorblind Users
**Flutter · YOLOv9 · Claude AI · Cross-Platform**

---

## ✨ Features
| Feature | Description |
|---|---|
| 📷 **Live Camera** | Real-time YOLOv9 object detection with color labels per object |
| 🖼️ **Gallery Upload** | Analyze any image from your photo library |
| 🏷️ **Compound Labels** | "Crimson Red shirt", "Sky Blue car" — not just colors, but named objects |
| 🎨 **Recolorization** | CVD correction matrices for all 5 colorblindness types |
| 🔊 **Voice Assistance** | Speaks detected colors automatically (flutter_tts) |
| 📳 **Vibration Alerts** | Haptic patterns when color changes detected |
| 🤖 **AI Chatbot** | Ask Claude questions about colors, outfit matching, etc. |
| ⚙️ **Personalization** | CVD type, voice speed, label style, all persistent |

---

## 🚀 Quick Start

### Prerequisites
- Flutter 3.16+ — [install](https://flutter.dev/docs/get-started/install)
- Android Studio or Xcode
- Physical device recommended (camera features)

### 1. Clone & Install
```bash
git clone <your-repo>
cd colorsense
flutter pub get
```

### 2. Add YOLOv9 Model (optional but recommended)
```bash
pip install ultralytics
python -c "
from ultralytics import YOLO
YOLO('yolov9t.pt').export(format='tflite', imgsz=640, int8=True)
"
mv yolov9t_saved_model/yolov9t_int8.tflite assets/models/yolov9_tiny.tflite
```
> Without the model, the app uses fallback region-based detection. Everything else works.

### 3. Add Anthropic API Key (optional — for chatbot)
Edit `lib/services/chatbot_service.dart`:
```dart
static const String _apiKey = 'sk-ant-...your-key-here...';
```
Get key at: https://console.anthropic.com

### 4. Run
```bash
bash build.sh    # interactive build menu
# OR
flutter run      # run on connected device
```

---

## 📁 Project Structure
```
colorsense/
├── lib/
│   ├── main.dart                      # Entry point, providers, theme
│   ├── core/
│   │   └── theme.dart                 # Dark theme, color constants
│   ├── models/
│   │   └── scan_result.dart           # ScanResult, DetectedColor, SaliencyRegion
│   ├── providers/
│   │   ├── app_provider.dart          # Detection pipeline state
│   │   └── settings_provider.dart     # CVD type, voice, vibration prefs
│   ├── screens/
│   │   ├── home_screen.dart           # Home + bottom nav shell
│   │   ├── camera_screen.dart         # Live camera + YOLO bbox overlays
│   │   ├── result_screen.dart         # Analysis result + color cards
│   │   ├── chatbot_screen.dart        # Claude AI chat with image support
│   │   └── settings_screen.dart       # Full personalization UI
│   └── services/
│       ├── yolov9_service.dart        # YOLOv9 TFLite inference + NMS
│       ├── color_detection_service.dart # K-Means + color name lookup
│       ├── recolorization_service.dart # CVD correction matrices
│       ├── voice_service.dart         # flutter_tts wrapper
│       ├── haptic_service.dart        # Vibration patterns
│       └── chatbot_service.dart       # Anthropic Claude API
├── assets/
│   ├── models/
│   │   └── yolov9_tiny.tflite        # ← Add this file
│   └── data/
│       └── color_names.json           # 70+ named colors
├── android/
│   └── app/
│       ├── build.gradle               # TFLite GPU delegate
│       └── src/main/AndroidManifest.xml
├── ios/
│   ├── Runner/Info.plist             # All permissions
│   └── Podfile                       # TFLite Metal delegate
├── build.sh                           # Interactive build/deploy script
└── MODEL_INTEGRATION_GUIDE.md        # Full model conversion guide
```

---

## 🧠 Detection Pipeline

```
Image / Camera Frame
        ↓
   YOLOv9-tiny TFLite
   [1, 640, 640, 3] → [1, 25200, 85]
        ↓
   NMS + Confidence Filter (≥ 0.35)
        ↓
   Per-box K-Means Clustering (k=1)
        ↓
   Nearest Color Name (70+ colors)
        ↓
   Compound Label: "Sky Blue sky"
        ↓
   Bounding Box Overlay + Voice + Haptic
```

---

## 🎨 Supported Colorblindness Types

| Type | Description | Correction |
|---|---|---|
| Deuteranopia | Missing M cones (most common) | Viénot matrix |
| Protanopia | Missing L cones | Brettel matrix |
| Tritanopia | Missing S cones | Brettel matrix |
| Monochromacy | No color vision | Grayscale enhance |
| Anomalous | Shifted color perception | Adjusted matrix |

---

## 📦 Dependencies

| Package | Purpose |
|---|---|
| `tflite_flutter` | YOLOv9 inference |
| `camera` | Live camera feed |
| `image_picker` | Gallery access |
| `image` | Image preprocessing |
| `flutter_tts` | Text-to-speech |
| `vibration` | Haptic feedback |
| `http` | Claude API calls |
| `hive_flutter` | Scan history storage |
| `provider` | State management |
| `google_fonts` | Syne + DM Sans fonts |
| `permission_handler` | Runtime permissions |

---

## 🔑 API Keys

- **Anthropic (Claude chatbot):** https://console.anthropic.com → API Keys
- No other API keys required

---

## 🤝 Contributing

1. Fork the repo
2. Create branch: `git checkout -b feature/my-feature`
3. Commit: `git commit -m 'Add my feature'`
4. Push: `git push origin feature/my-feature`
5. Open Pull Request

---

*Built with ❤️ to make the world more colorful for everyone*
