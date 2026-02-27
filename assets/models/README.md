# ColorSense Model Assets

Place the following model files in this directory:

## Required
- `yolov9_tiny.tflite`  — YOLOv9 object detection model

## Optional (enhances recolorization)
- `ddcolor.tflite`  — DDColor image colorization model

## How to get yolov9_tiny.tflite

```bash
pip install ultralytics
python -c "
from ultralytics import YOLO
model = YOLO('yolov9t.pt')
model.export(format='tflite', imgsz=640, int8=True)
"
# Output: yolov9t_saved_model/yolov9t_int8.tflite
# Rename to: yolov9_tiny.tflite and place here
```

See MODEL_INTEGRATION_GUIDE.md for full instructions.

The app works without this file — it uses a fallback region-based detector.
