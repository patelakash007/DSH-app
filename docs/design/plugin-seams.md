# Plugin Seams & Lifecycle Integration

Defines boundary interfaces between host lifecycle events and plugin dispatchers.

## Hooks
- `session.start`, `session.end`: Conversation initialization and teardown.
- `turn.start`, `turn.end`: Step-level event interceptors.
- `tool.call`, `tool.result`: Presentation card injection points.
