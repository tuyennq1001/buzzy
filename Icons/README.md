# Tomik Icons & Assets

Original assets and generated icons for **Tomik** (macOS Soft Kawaii Pomodoro App).

- `Tomik.png`: Master 1024x1024 macOS App Icon (Soft Kawaii 2D Vector style).
- `tomato-filled.png`: Master high-res Menu Bar template icon (Kawaii Face style).
- `apply_icons.py`: Production Python script to generate and apply all required icon resolutions into `Tomik/Assets.xcassets/AppIcon.appiconset` and `Tomik/Assets.xcassets/BarIcon*.imageset`.

### Usage
```bash
python3 Icons/apply_icons.py --app-icon 3 --menubar A
```
