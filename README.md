<p align="center">
  <img src="Icons/Buzzy.png" width="128" height="128" alt="Buzzy App Icon"/>
</p>

<h1 align="center">🐝 Buzzy</h1>

<p align="center">
  <b>A cute, delightful Soft Kawaii Pomodoro & To-Do Menu Bar App for macOS</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2012.0+-lightgrey?style=flat-square&logo=apple" alt="macOS 12.0+"/>
  <img src="https://img.shields.io/badge/Swift-5.0-orange?style=flat-square&logo=swift" alt="Swift 5"/>
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-blue?style=flat-square" alt="SwiftUI"/>
  <img src="https://img.shields.io/badge/license-MIT-pink?style=flat-square" alt="MIT License"/>
</p>

---

## ✨ Overview

**Buzzy** is a charming, lightweight Pomodoro timer and task manager that lives comfortably in your macOS menu bar. Designed with a gentle **Soft Kawaii Card** aesthetic, Buzzy transforms your workday into an enjoyable, mindful, and rewarding journey.

Whether you're studying, coding, or organizing tasks, Buzzy keeps you focused without feeling overwhelming.

---

## 🌸 Key Features

### 🍅 Mindful Pomodoro Timer
- **Menu Bar Circular Progress**: Real-time progress ring right on your Mac's top bar.
- **Customizable Intervals**: Flexible work time, short breaks, and long breaks.
- **Gentle Controls**: Start, pause, resume, and cancel sessions smoothly.

### 🎨 Soft Kawaii Pastel Themes
- **6 Handpicked Pastel Themes**:
  - 🔴 Tomato Red
  - 🌸 Strawberry Pink
  - 🍊 Apricot Orange
  - 🍵 Matcha Green
  - 🌊 Sky Blue
  - 💜 Lavender Purple
- **Card Containers**: Soft rounded corners (`14px`), subtle pastel borders, and interactive press animations.

### 📝 Integrated Two-Tier To-Do List
- **One-Click Focus**: Tap any task to immediately set it as your active focus subject.
- **Drag-and-Drop Reordering**: Easily organize your priorities.
- **Mutual Accordion Layout**:
  - **Today's To-Do List**: Active pending tasks and today's completed achievements (`🎉`).
  - **Past Completed Tasks**: Archived tasks from previous days with a single-click clean-up button.
  - Toggling one section smoothly collapses the other to keep your menu bar clean and compact.

### 📊 Bento Statistics & Productivity Streaks
- **Day Streaks**: Track consecutive focus days to build rewarding study and work habits.
- **Daily Harvest Badge**: Keep track of your daily tomato targets (e.g., `🍅 4/8`).
- **18-Week Activity Heatmap**: GitHub-style visual log of your completed pomodoros.

### 🎵 Cute Audio Chimes & Typography
- **5 Charming Completion Sounds**: Songbird 🐦, Kitten 🐱, Duckling 🦆, Puppy 🐶, and Morning Rooster 🐓.
- **Cute Font Selection**: SF Rounded, Avenir, Helvetica, and Chalkboard.
- **Dynamic Font Scaling**: Adjust the app's font size directly from the Settings slider.
- **Break Suggestions**: Gentle reminders to stretch, hydrate, and relax your eyes during breaks.

### 🌐 Multilingual
- Full native localization for **English**, **Tiếng Việt**, and **日本語**.

---

## 🚀 Building & Running from Source

### Prerequisites
- macOS 12.0 (Monterey) or later
- Xcode 14.0 or later

### Build Instructions
```bash
# 1. Clone the repository
git clone git@github.com:tuyennq1001/tomik.git
cd tomik

# 2. Build via Xcode command line or open in Xcode
xcodebuild -scheme Buzzy -configuration Debug build

# 3. Launch the app
open "build/Build/Products/Debug/Buzzy Dev.app"
```

Or open `Buzzy.xcodeproj` in Xcode and hit **⌘R**.

---

## ⌨️ Shortcuts & URL Scheme

Buzzy supports global keyboard shortcuts and URL schemes for seamless automation:
- Default global shortcut: `⌘ + ⇧ + S` (`Cmd + Shift + S`)
- Toggle timer from Terminal or Raycast/Alfred:
  ```bash
  open buzzy://startStop
  ```

---

## 👨‍💻 Author

- **Terry** ([tuyennq.1001@gmail.com](mailto:tuyennq.1001@gmail.com))

---

## 📄 License & Credits

- Buzzy is distributed under the **[MIT License](LICENSE)**.
- Built upon the open-source foundations of [TomatoBar](https://github.com/ivoronin/TomatoBar) by Ilya Voronin, evolved and redesigned with love into **Buzzy**.
