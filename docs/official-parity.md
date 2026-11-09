# Feature Parity with DeepSeek Harness

This document outlines the feature alignment between the **DSH Native Android Client** and the official upstream **DeepSeek Harness** web/CLI implementations.

---

## 1. Feature Parity Matrix

| Feature | Upstream Web / CLI | DSH Native Android | Notes |
|---|---|---|---|
| **Turn/Step Execution Loop** | Yes | Yes | Identical protocol semantics |
| **Tool Calling & Schema Support** | Yes | Yes | Supported natively with interactive approval cards |
| **Streaming Responses (SSE)** | Yes | Yes | Real-time token streaming with thinking process display |
| **Conversation History & Forking** | Yes | Yes | Full timeline navigation and branch forking |
| **On-Device Direct Execution** | No (requires server) | **Yes (Native)** | Runs directly on Android without PRoot or containers |
| **Phone Control Automation** | No | **Yes (Native)** | Accessibility-driven screen interaction |
| **Companion Mascots** | No | **Yes (Native)** | Deepy & Whale girl interactive animations |
| **End-to-End Encrypted Sharing** | Partial | **Yes (Native)** | Client-side encrypted link generation and replay |
| **Custom Plugin UI Cards** | Web only | **Yes (Native)** | Native Flutter rendering of plugin forms and cards |

---

## 2. Platform-Specific Adaptations

1. **Native On-Device Execution**: Upstream requires Node.js on a server. DSH Native embeds an in-process Go engine that runs locally on Android.
2. **Mobile Screen Real Estate**: Touch-optimized message bubbles, collapsible execution details, and adaptive tablet/split-screen layouts.
3. **Hardware Integration**: Vibration haptics, camera image input, microphone voice input, and floating desktop overlays.
