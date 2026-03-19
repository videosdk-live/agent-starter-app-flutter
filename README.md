# Agent Starter Flutter (VideoSDK)
A Flutter starter template for building real-time conversational AI agents using VideoSDK.

## Features
- **Voice Support:** Real-time audio communication with mic toggle and device switching.
- **AI Agent Integration:** Interact with an AI agent with real-time responses.
- **Live Transcription:** Display ongoing conversation transcripts.
- **Screen Sharing:** Share your screen during sessions.
- **Device Management:** Switch between audio input/output devices.

## Prerequisites
Before you begin, ensure you have the following installed:
- [Flutter](https://flutter.dev/docs/get-started/install) (v3.8.0 or later)
- [Dart](https://dart.dev/get-dart) (v3.x or later)
- [Android Studio](https://developer.android.com/studio) or [Xcode](https://developer.apple.com/xcode/) for device/emulator setup

## Getting Started
Use the following steps to run the project locally:

### 1. Clone the repository
```bash
git clone https://github.com/videosdk-live/agent-starter-app-flutter.git
cd agent-starter-flutter
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Setup Environment Variables
Create a `.env` file in the root directory by copying the example:
```bash
cp .env.example .env
```

Update the `.env` file with the following values:
```env
AUTH_TOKEN=your_videosdk_auth_token
AGENT_ID=your_agent_id
MEETING_ID=your_meeting_id (optional)
```

> [!TIP]
> You can obtain your `AUTH_TOKEN` from the [VideoSDK Dashboard](https://app.videosdk.live/).

### 4. Run the app
```bash
# Android
flutter run

# iOS
cd ios && pod install && cd ..
flutter run -d ios
```

## Configuration
| Variable | Description | Required |
|----------|------------|----------|
| `AUTH_TOKEN` | VideoSDK authorization token | Yes |
| `AGENT_ID` | ID of the AI agent to connect with | Yes |
| `MEETING_ID` | Meeting ID to join (optional) | No |

## Permissions
The app requires the following permissions:

**Android** — add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.CAMERA" />
```

**iOS** — add to `Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for audio calls.</string>
<key>NSCameraUsageDescription</key>
<string>Camera access is required for video calls.</string>
```

---
<p align="center">
  Built with ❤️ by <a href="https://www.videosdk.live/">VideoSDK</a>
</p>
