# Basira AI - Flutter Front-End

## Overview

Basira AI is an AI-powered assistive system developed as a graduation project to help visually impaired children safely navigate indoor environments.

This repository contains the complete Flutter Front-End application for both the Child and Parent.

The application works together with:

- ESP32-CAM
- FastAPI Backend
- YOLOv8
- MiDaS
- FaceNet
- BLIP / Florence Scene Understanding

---

# System Architecture

```
ESP32-CAM
     │
     ▼
Flutter Child App
     │
     ▼
FastAPI Backend
     │
 ┌───────────────┐
 │ YOLOv8        │
 │ MiDaS         │
 │ FaceNet       │
 │ Scene AI      │
 └───────────────┘
     │
     ▼
Flutter Parent App
```

---

# Project Features

## Child Application

- Live ESP32-CAM Streaming
- Object Detection
- Scene Understanding
- Text-to-Speech Feedback
- Voice Notifications
- QR Pairing
- Emergency Warning

---

## Parent Application

- Parent Login
- Child Registration
- QR Pairing
- Add Familiar Persons
- Face Management
- Unknown Person History
- Emergency Alerts
- Language Settings

---

# Technologies

Frontend

- Flutter
- Dart
- Provider
- HTTP
- Flutter TTS
- Shared Preferences
- Mobile Scanner
- Image Picker

Backend AI

- FastAPI
- YOLOv8
- MiDaS
- FaceNet
- BLIP
- Florence

Hardware

- ESP32-CAM

---

# Prerequisites

Before running the project install the following software.

---

## 1) Install Git

Download

https://git-scm.com/downloads

Verify installation

```bash
git --version
```

---

## 2) Install Flutter SDK

Official Guide

https://docs.flutter.dev/get-started/install

Download Flutter SDK

https://docs.flutter.dev/get-started/install/windows

Extract Flutter

Example

```
C:\src\flutter
```

Add Flutter to PATH

Verify

```bash
flutter --version
```

---

## 3) Install Android Studio

Download

https://developer.android.com/studio

During installation make sure the following are selected

- Android SDK
- Android SDK Platform
- Android SDK Build Tools
- Android Emulator

---

## 4) Install VS Code (Optional)

https://code.visualstudio.com/

Install extensions

- Flutter
- Dart

---

## 5) Accept Android Licenses

Run

```bash
flutter doctor --android-licenses
```

Accept all licenses.

---

## 6) Verify Flutter Installation

Run

```bash
flutter doctor
```

All checks should be green.

---

# Clone Repository

```bash
git clone https://github.com/shams-ashraf/Front_End.git
```

Move into project

```bash
cd Front_End
```

---

# Install Packages

Run

```bash
flutter pub get
```

---

# Configure Backend

Open

```
lib/config/app_config.dart
```

Update

```dart
serverIp
```

with your backend IP.

Example

```dart
192.168.1.100
```

---

Update

```dart
esp32Ip
```

Example

```dart
192.168.1.120
```

Both mobile phone and ESP32-CAM must be connected to the same Wi-Fi network.

---

# Run Application

Connect Android phone

Enable USB Debugging

Run

```bash
flutter devices
```

If device appears

Run

```bash
flutter run
```

or

```bash
flutter run -d android
```

---

# Build APK

```bash
flutter build apk --release
```

APK Location

```
build/app/outputs/flutter-apk/app-release.apk
```

---

# Project Structure

```
lib
│
├── config
├── models
├── screens
├── services
├── widgets
├── utils
├── localization
└── main.dart

assets
│
├── icons
├── images
└── sounds

android
```

---

# Required Backend

This project requires the Basira AI Backend.

Backend Responsibilities

- YOLOv8 Object Detection
- MiDaS Depth Estimation
- Face Recognition
- Scene Understanding
- Alert Generation

Backend Repository

(Add your backend GitHub repository here.)

---

# Required Hardware

- ESP32-CAM
- Android Phone
- Same Wi-Fi Network
- Backend Computer

---

# Flutter Packages

Install automatically using

```bash
flutter pub get
```

Main Packages

- provider
- http
- flutter_tts
- image_picker
- mobile_scanner
- shared_preferences

---

# Troubleshooting

## Flutter packages failed

```bash
flutter clean
```

```bash
flutter pub get
```

---

## Gradle error

Delete

```
android/.gradle
```

Run

```bash
flutter clean
```

```bash
flutter pub get
```

---

## Device not detected

Run

```bash
adb devices
```

If empty

- Enable USB Debugging
- Install USB Driver

---

## Build failed

Run

```bash
flutter doctor
```

Fix all reported issues.

---

# Authors

Graduation Project

Faculty of Computers and Artificial Intelligence

Helwan National University

Academic Year 2025–2026

Developed by

- Shams Ashraf
- Basira AI Team

---

# License

This repository is intended for educational and graduation project purposes only.
