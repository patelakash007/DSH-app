# Live Activity & Ongoing Task Notifications

Design for Android ongoing notifications and foreground service indicators during background agent turns.

## Structure
- Persistent notification channel displaying real-time turn step progress, tool execution badges, and cancellation action.
- Automatic transition to success/failure alerts upon turn completion.
- Battery-safe updates throttled to at most 4 updates per second.
