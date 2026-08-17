# Agent Cypher

Agent Cypher is a premium JARVIS-style Android AI assistant built with Flutter. It combines advanced AI providers, voice control, device automation, and accessibility integration to provide a seamless personal assistant experience.

## Architecture

The system operates on a continuous feedback loop:
1. The user issues a command (via voice or text).
2. The agent captures the current screen hierarchy and device context.
3. The context is transmitted to the selected AI provider with the current task.
4. The AI determines the optimal action sequence.
5. The native Android layer executes validated actions with verification.
6. The loop continues with observability and recovery capabilities until complete.

## Capabilities

- **Screen Reading:** Parses the Android UI tree to map clickable, scrollable, and editable elements.
- **Coordinate-Based Interaction:** Simulates physical screen taps based on coordinate geometry, mitigating issues with missing text labels or inaccessible icons.
- **Multi-Provider Support:** Seamlessly switch between NVIDIA, Gemini, OpenAI, Anthropic, and other compatible AI providers.
- **Voice Control:** Native speech-to-text integration for hands-free operation.

## Installation

Download the latest APK directly from the [Releases Page](https://github.com/cypherghost/agent-cypher/releases).

Choose `app-universal-release.apk` when it is available. It supports ARM64,
32-bit ARM, and x86_64 devices in one package. If a release only provides split
APKs, most modern Android phones—including Snapdragon devices—must use
`app-arm64-v8a-release.apk`.

Agent Cypher supports Android 8.0 (API 26) and newer. Current release builds are
also checked for Android 15/16's 16 KB native-library alignment requirement.

## Setup Instructions (How to use for FREE)

This app requires an AI brain to operate. You can use it **100% for free** by using OpenRouter's free models.

1. Install the APK on your Android device (API 30+ recommended).
2. Go to [OpenRouter.ai](https://openrouter.ai/) and create a free account.
3. Generate a free API Key.
4. Launch Agent Cypher and go to the **Settings** screen.
5. Select your preferred AI Provider and configure the API key.
6. Configure voice and other settings as desired.
7. Enable the **"Agent Cypher Screen Control"** service in your Android Accessibility Settings to enable device automation.

### “Restricted setting” when enabling Screen Control

Android may block accessibility access for apps installed from an APK. This is
an operating-system safety restriction:

1. Open **Settings → Apps → Agent Cypher**.
2. Open the three-dot menu in the top-right corner.
3. Tap **Allow restricted settings** and confirm.
4. Return to Agent Cypher and open **Accessibility Settings** again.
5. Enable **Agent Cypher Screen Control**.

Agent Cypher provides clear onboarding instructions and shortcuts to both App
Info and Accessibility Settings during initial setup.

## Features

- **Voice Control:** Wake word detection and continuous voice command capability
- **Multi-Provider AI:** Switch between NVIDIA, Gemini, OpenAI, Anthropic, and other providers
- **Device Automation:** Intelligent task execution with accessibility integration
- **Memory System:** Persistent memory for preferences and recurring information
- **Task Planning:** Structured multi-step action planning with verification
- **Premium UI:** Warm, sophisticated design with floating assistant bubble

## License

This project is open-source and available for modification.
