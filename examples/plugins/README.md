# Example Plugins

Sample plugins demonstrating the native DSH plugin API.

| Plugin | Features Demonstrated | Requires Bridge |
|---|---|---|
| [`dsh-go-example-weather`](dsh-go-example-weather/) | Tool Card: Tool execution result rendered as a native weather card (`presentationMeta`) | No |
| [`dsh-go-example-usage`](dsh-go-example-usage/) | Status strip + panel + real-time data streaming: session / daily token stats | Yes |
| [`dsh-go-example-quick`](dsh-go-example-quick/) | Capsule (static effects, invocations) + message menu + deferred effect (LLM translation) | Yes |
| [`dsh-go-example-readaloud`](dsh-go-example-readaloud/) | v1.2 Capabilities: Text-to-speech audio playback, stop on speech, real-time synchronized subtitles | Yes |
| [`dsh-go-example-styles`](dsh-go-example-styles/) | View v2: Semantic typography, rich text, readable contrast colors, cards, and proportional columns | Yes |
| [`dsh-go-example-album`](dsh-go-example-album/) | Chat sheet: Image galleries, empty states, circular progress, trend lines, theme awareness | Yes |
| [`dsh-go-example-toolbox`](dsh-go-example-toolbox/) | Plus-menu tool, conversation actions, turn footnotes, and plugin badge count | Yes |

Installation: `dsh plugin --profile web add /absolute/path/<plugin-directory>`.
