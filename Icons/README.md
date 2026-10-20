# Buzzy Icons & Assets

Original assets and generated icons for **Buzzy** (macOS Soft Kawaii Pomodoro App).

- `Buzzy.png`: Master 1024x1024 macOS App Icon (Option 3 Dark Charcoal & Gold style).
- `BuzzyCharacter.png`: Master 1024x1024 pure bee character on transparent background.
- `tomato-filled.png`: Master high-res Menu Bar template icon (Option C Happy Eyes style).
- `apply_icons.py`: Production Python script to generate and apply all required icon resolutions into `Buzzy/Assets.xcassets/AppIcon.appiconset` and `Buzzy/Assets.xcassets/BarIcon*.imageset`.

### Usage
```bash
python3 Icons/apply_icons.py --app-icon 3 --menubar A
```
