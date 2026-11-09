# Media Generation Protocol & Grammar Specification

Defines parameter header grammar v1 for image and video generation requests.

## Header Grammar v1
Generation commands initiate on the first line of a user turn matching:
`〔Generate Image [ · Ratio][ · N Images][ · Quality=Val][ · Model]〕`
`〔Generate Video [ · Ratio][ · S Seconds][ · Resolution][ · Model]〕`

Followed by newline and unformatted prompt description.
- Ratios: Two decimal integers `W:H` (e.g. `16:9`, `1:1`, `9:16`).
- Output: Staged media items rendered as native cards with zoomable image viewer and video playback controls.
