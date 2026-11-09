# DS Bot Runtime Integration

Integration layer for embedded bot runtimes and task-specific agent workflows.

## Design
- Isolated execution environment with sandboxed file storage per bot instance.
- Direct bridge dispatch into native conversation channels.
- Configurable model endpoints, system prompts, and tool permissions per bot.
