# Media Parameter Header v1 Specification

Defines parameter header grammar v1 for media generation commands in DSH.

## Command Syntax
Generation instructions start on the first line of the message:
`〔Generate Image [ · Ratio][ · N Images][ · Quality=Val][ · Model]〕`
`〔Generate Video [ · Ratio][ · S Seconds][ · Resolution][ · Model]〕`

Followed by newline and prompt description.
- Ratios: Two positive decimal integers connected by a colon without leading zeroes (e.g. `16:9`, `1:1`, `9:16`).
- Image count: 1 to 4.
- Video duration: 1 to 60 seconds.
- Quality / Resolution: Validated ASCII identifier.
- Model: Model label with optional `〈serviceId/modelId〉` qualification.
