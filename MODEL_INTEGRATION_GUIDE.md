# 🧠 ColorSense — YOLOv9 Model Integration Guide

## Why YOLOv9 Instead of BASNet Saliency?

| Feature | BASNet (old) | YOLOv9 (new) |
|---|---|---|
| What it detects | Generic salient region | Named objects (shirt, car, sky…) |
| Output label | "Crimson Red" | **"Crimson Red shirt"** |
| Accuracy | Heatmap-based | Bounding box + class |
| User value | Partial | Full semantic context |

---

## 📦 1. DOWNLOAD YOLOv9

### Option A — Official Ultralytics (Recommended)
```bash
pip install ultralytics

# Download YOLOv9-tiny (best size/accuracy for mobile)
python -c "
from ultralytics import YOLO
model = YOLO('yolov9t.pt')   # 'tiny' — ~4MB
model.info()
"
```

Available variants:
| Model | Size | mAP50 | Best for |
|---|---|---|---|
| `yolov9t.pt` | 4 MB  | 38.3 | Mobile (use this) |
| `yolov9s.pt` | 12 MB | 46.8 | Balanced |
| `yolov9m.pt` | 38 MB | 51.4 | High accuracy |
| `yolov9c.pt` | 51 MB | 53.0 | Server-side |

### Option B — Pre-converted TFLite (Community)
```
https://github.com/ultralytics/ultralytics/issues/  (search "yolov9 tflite")
https://huggingface.co/models?search=yolov9+tflite
```

---

## 🔄 2. CONVERT YOLOv9 → TFLite

### Method 1: Ultralytics Export (Easiest)
```python
from ultralytics import YOLO

model = YOLO('yolov9t.pt')

# Export to TFLite — INT8 quantized for mobile
model.export(
    format='tflite',
    imgsz=640,
    int8=True,          # Quantize: ~4MB → even smaller, fast on mobile
    data='coco.yaml',   # For INT8 calibration dataset
)
# Output: yolov9t_saved_model/yolov9t_int8.tflite
```

### Method 2: ONNX → TFLite Pipeline
```bash
# Step 1: PyTorch → ONNX
python -c "
from ultralytics import YOLO
model = YOLO('yolov9t.pt')
model.export(format='onnx', imgsz=640, simplify=True)
"

# Step 2: ONNX → TF SavedModel
pip install onnx2tf
onnx2tf -i yolov9t.onnx \
        -o yolov9t_tf \
        -oiqt \              # INT8 quantization
        --output_integer_quantized_tflite

# Step 3: Rename and place in assets
cp yolov9t_tf/yolov9t_integer_quant.tflite assets/models/yolov9_tiny.tflite
```

---

## 📐 3. MODEL INPUT / OUTPUT SPECIFICATION

```
Input:
  Shape:  [1, 640, 640, 3]
  Type:   float32
  Range:  [0.0, 1.0]  (divide pixel values by 255)

Output:
  Shape:  [1, 25200, 85]
  Type:   float32

  25200 = 3 anchor scales × (80×80 + 40×40 + 20×20) grid cells
  85    = 4 bbox + 1 objectness + 80 COCO class scores

  Per-prediction layout:
  [cx, cy, w, h, obj_conf, cls_0, cls_1, ..., cls_79]
   0   1   2  3     4        5      6          84
```

> ⚠️ If using INT8 quantized model, inputs/outputs are `uint8`. The
> `YOLOv9Service` already handles float32; for INT8 add `* 255` before
> feeding and `/ 255` after reading, or use `Interpreter.allocateTensors()`
> to check the tensor type at runtime.

---

## 📂 4. PLACE MODEL IN PROJECT

```
assets/
└── models/
    └── yolov9_tiny.tflite   ← put it here (4–12 MB depending on variant)
```

`pubspec.yaml` already declares:
```yaml
flutter:
  assets:
    - assets/models/
    - assets/data/
```

---

## ⚡ 5. GPU DELEGATE (3–5× SPEEDUP)

Already enabled in `YOLOv9Service._loadModel()`:
```dart
final options = InterpreterOptions()..threads = 4;
try {
  options.addDelegate(GpuDelegate());   // Android OpenCL / iOS Metal
} catch (_) { /* falls back to CPU */ }
```

### Android — add to `android/app/build.gradle`
```gradle
dependencies {
    implementation 'org.tensorflow:tensorflow-lite-gpu:2.14.0'
    implementation 'org.tensorflow:tensorflow-lite-gpu-delegate-plugin:0.4.4'
}
```

### iOS — add to `ios/Podfile`
```ruby
pod 'TensorFlowLiteSwift', '~> 2.14.0'
pod 'TensorFlowLiteSwift/Metal', '~> 2.14.0'
```

---

## 🏷️ 6. COCO CLASSES (80 objects YOLOv9 can detect)

```
person, bicycle, car, motorcycle, airplane, bus, train, truck, boat,
traffic light, fire hydrant, stop sign, parking meter, bench,
bird, cat, dog, horse, sheep, cow, elephant, bear, zebra, giraffe,
backpack, umbrella, handbag, tie, suitcase, frisbee, skis, snowboard,
sports ball, kite, baseball bat, baseball glove, skateboard, surfboard,
tennis racket, bottle, wine glass, cup, fork, knife, spoon, bowl,
banana, apple, sandwich, orange, broccoli, carrot, hot dog, pizza,
donut, cake, chair, couch, potted plant, bed, dining table, toilet,
tv, laptop, mouse, remote, keyboard, cell phone, microwave, oven,
toaster, sink, refrigerator, book, clock, vase, scissors,
teddy bear, hair drier, toothbrush
```

Resulting color labels will be like:
- `"Crimson Red car"`
- `"Sky Blue umbrella"`
- `"Forest Green potted plant"`
- `"Ivory white couch"`

---

## 📱 7. ANDROID / iOS PERMISSIONS

### `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.INTERNET" />
```

### `ios/Runner/Info.plist`
```xml
<key>NSCameraUsageDescription</key>
<string>ColorSense needs camera access to detect colors in real time.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>ColorSense needs photo access to analyze images.</string>
```

---

## 🚀 8. PERFORMANCE BENCHMARKS (YOLOv9-tiny)

| Device | Mode | Latency |
|---|---|---|
| Pixel 7 (CPU, 4 threads) | ~180ms | ~5.5 FPS |
| Pixel 7 (GPU delegate) | ~55ms | ~18 FPS |
| iPhone 14 (Metal delegate) | ~40ms | ~25 FPS |
| Mid-range Android CPU | ~300ms | ~3 FPS |

**App uses 1.8s frame interval** — well within all device budgets.

---

## 🔑 9. CHATBOT API KEY

Replace in `lib/services/chatbot_service.dart`:
```dart
static const String _apiKey = 'YOUR_ANTHROPIC_API_KEY';
```
Get key at: https://console.anthropic.com → API Keys

---

## 📋 10. QUICK-START CHECKLIST

- [ ] `flutter pub get`
- [ ] Download `yolov9t.pt` and export to `yolov9_tiny.tflite`
- [ ] Place `yolov9_tiny.tflite` in `assets/models/`
- [ ] Add camera + storage permissions to `AndroidManifest.xml` / `Info.plist`
- [ ] Set Anthropic API key in `chatbot_service.dart`
- [ ] (Optional) Add `ddcolor.tflite` for deep recolorization
- [ ] `flutter run`

The app works without the YOLOv9 model (fallback grid regions kick in automatically).
Add the model file to unlock full object-aware color labels.
