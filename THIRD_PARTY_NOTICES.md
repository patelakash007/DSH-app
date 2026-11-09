# Third-Party Notices

This document details third-party open-source components, bundled libraries, fonts, and assets incorporated into DSH.

- In-app license notices are available in **Settings -> Open Source Licenses**.
- Dart and Flutter dependencies are declared in `app/pubspec.lock`.
- License texts for third-party components are reproduced below.
- Project code is licensed under GNU AGPL-3.0 (see [LICENSE](LICENSE)). Brand assets and artwork are governed by [ASSETS.md](ASSETS.md).

---

## 1. Code Incorporated or Adapted into Source

### Phase (Used with Author's Permission)

| Item | Details |
|---|---|
| Project | Phase, https://github.com/CikeSeven/phase (commit `c209f6f`) |
| Copyright | Copyright (c) 2026 CikeSeven |
| License | Used with author's permission |
| Purpose | Phone control: accessibility screen reading and actions, floating control overlay, and non-disruptive virtual screen mode |

Upstream path prefix: `android/app/src/main/kotlin/app/xiangyue/phase/`; repository path prefix: `app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/phone/`.

| Repository File | Upstream Source |
|---|---|
| `a11y/Actuator.kt` | `accessibility/AccessibilityDriver.kt`, `vision/VisualDriver.kt` |
| `a11y/ControlOverlay.kt` | `accessibility/TaskOverlay.kt` |
| `a11y/MainScreenDriver.kt` | `accessibility/AccessibilityDriver.kt` |
| `a11y/PhoneA11yService.kt` | `accessibility/PhaseAccessibilityService.kt` |
| `a11y/ScreenShooter.kt` | `vision/VisualDriver.kt` |
| `background/PrivilegedDisplayCore.kt` | `shizuku/ShizukuDeviceService.kt`, `DisplayTextConnection.kt`, `DisplayTextInput.kt` |
| `background/PrivilegedDisplayEntry.kt` | `shizuku/ShizukuDeviceService.kt` |
| `background/PrivilegedProtocol.kt` | Failure cause reason code collection |
| `background/ShizukuStarter.kt` | `shizuku/ShizukuConnection.kt` |
| `app/android/app/src/main/res/xml/phone_accessibility_service.xml` | `accessibility_service.xml` |

Original notice:
```text
Portions of the phone control feature are derived from Phase
(https://github.com/CikeSeven/phase), Copyright (c) 2026 CikeSeven,
used with the author's permission.
```

### DSH Showcase Landing Site

| Item | Details |
|---|---|
| Work | DSH Showcase Web Site: HTML, CSS, JavaScript, content check scripts, showcase images |
| Author | ClayGao233 (https://github.com/ClayGao233) |
| License | Delivered by author for showcase site usage |
| Purpose | Web landing page under `site/home/` |

### PiPilot (MIT License)

| Item | Details |
|---|---|
| Project | PiPilot, https://github.com/CikeSeven/pi_pilot |
| Copyright | Copyright (c) 2026 CikeSeven |
| License | MIT License |
| Purpose | Chat interface, common components, drawer shell, and dynamic theming structure |

Files located under `app/lib/ui/`:
- `chat/`: `chat_header.dart`, `chat_list.dart`, `chat_screen.dart`, `composer.dart`, `model_sheet.dart`
- `chat/render/`: `ansi_text.dart`, `code_block.dart`, `diff_view.dart`, `markdown_body.dart`
- `chat/widgets/`: `approval_card.dart`, `assistant_message.dart`, `question_card.dart`, `thinking_pill.dart`, `tool_row.dart`, `user_bubble.dart`
- `common/`: `app_sheet.dart`, `glass_pill.dart`, `overscroll_forwarder.dart`, `sheet_navigator.dart`, `status_dot.dart`, `streaming_cursor.dart`, `tool_glyph.dart`, `typing_indicator.dart`
- `settings/`: `diagnostics_page.dart`, `settings_widgets.dart`
- `shell/`: `drawer_drag.dart`, `home_shell.dart`, `sessions_drawer.dart`
- `theme/`: `accent.dart`, `app_theme.dart`, `backdrop.dart`, `highlight_theme.dart`, `motion.dart`, `palette.dart`, `semantic_colors.dart`, `shapes.dart`, `squircle.dart`, `typography.dart`

### DeepSeek Harness (MIT License)

| Item | Details |
|---|---|
| Project | DeepSeek Harness, https://github.com/deepseek-ai/deepseek-harness |
| Copyright | Copyright (c) 2026 DeepSeek |
| License | MIT License |
| Purpose | Client algorithms, secret masking, deliverable cards, and cron parsing |

| Repository File | Upstream Source | Purpose |
|---|---|---|
| `app/lib/ui/chat/secret_mask.dart` | `@deepseek-ai/dsh-client-ui-secret-mask` | Credential pattern matching and masking |
| `app/lib/ui/chat/widgets/artifact_card.dart` | `@deepseek-ai/dsh-client-ui-deliverables` | Deliverable presentation cards |
| `app/lib/state/session_search.dart` | `@deepseek-ai/dsh-client-ui-workspace` | Session search result merging |
| `app/lib/ui/features/schedule_editor/cron.dart` | `@deepseek-ai/dsh-client-ui-schedule` | Cron schedule parsing and description |
| `app/lib/ui/common/think_glyph.dart` | `@deepseek-ai/dsh-web-frontend` | Reasoning/thinking outline icon |
| `packages/dsh_client/lib/src/binary_response.dart` | `@deepseek-ai/dsh-client-connection` | Binary response decoding |
| `packages/dsh_client/lib/src/deliverables.dart` | `@deepseek-ai/dsh-client-ui-deliverables` | Deliverable validation and turn selection |

### DS Bot (Apache License 2.0, Modified)

| Item | Details |
|---|---|
| Project | DS Bot, https://github.com/Fei2411/DeepSeek-Bot (commit `1bebe82`) |
| Copyright | Copyright 2026 Fei2411 and the DS Bot contributors |
| License | Apache License 2.0 |
| Purpose | Interactive response (dsh-ui) normalization, validation, limits, view summaries, and chart scales |

Modified files under `app/lib/ui/chat/dsh_ui/`:
- `dsh_ui_model.dart`: View schema normalization and limits (`ds-bot/src/shared/views.js`)
- `dsh_ui_view.dart`: View tree rendering and callback dispatch
- `dsh_ui_chart.dart`: Linear chart interpolation and axis scaling

---

## 2. Bundled Fonts and Icons

### Lucide Icons (ISC License)
- Origin: https://github.com/lucide-icons/lucide
- Copyright (c) for portions of Lucide are held by Cole Bemis 2013-2022 as part of Feather (MIT). All other portions Copyright (c) Lucide Contributors 2026.
- License: ISC License

### JetBrains Mono (SIL Open Font License 1.1)
- Location: `app/assets/fonts/JetBrainsMono-*.ttf`
- Copyright (c) 2020 JetBrains s.r.o.
- License: SIL Open Font License, Version 1.1

### Inter (SIL Open Font License 1.1)
- Location: `app/assets/fonts/Inter-*.otf`
- Copyright (c) 2016-2020 The Inter Project Authors (https://github.com/rsms/inter)
- License: SIL Open Font License, Version 1.1

---

## 3. Runtime & Auxiliary Dependencies

### Unicode Character Database 15.0.0 (Unicode License)
- Generated validation data tables under `app/lib/pets/pet_unicode_data.g.dart` using Unicode 15.0.0 NFC and casefold tables.
- Copyright (c) 1991-2026 Unicode, Inc.
- License: Unicode License Agreement - Data Files and Software (2016)

### Compatibility and Attributions (No code copied)
- **Clawd on Desk** (https://github.com/rullerzhou-afk/clawd-on-desk, AGPL-3.0): Mascot asset package structure and status naming compatibility. No source code copied.
- **Streamdown** (https://github.com/vercel/streamdown): Streaming markdown end repair pattern referenced by `app/lib/ui/chat/render/stream_repair.dart`.

---

## 4. Full License Texts

### MIT License
```text
MIT License

Copyright (c) 2026 CikeSeven
Copyright (c) 2026 DeepSeek

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Apache License 2.0
```text
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.
      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work.

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and
      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and
      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work; and
      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      shall any Contributor be liable to You for damages, including any
      direct, indirect, special, incidental, or consequential damages of any
      character arising as a result of this License or out of the use or
      inability to use the Work.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License.
```

### ISC License
```text
ISC License

Copyright (c) 2026 Lucide Contributors

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
```

### SIL Open Font License 1.1
```text
SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007

PREAMBLE
The goals of the Open Font License (OFL) are to stimulate worldwide
development of collaborative font projects, to support the font creation
efforts of academic and linguistic communities, and to provide a free and
open framework in which fonts may be shared and improved in partnership
with others.

PERMISSION & CONDITIONS
Permission is hereby granted, free of charge, to any person obtaining
a copy of the Font Software, to use, study, copy, merge, embed, modify,
redistribute, and sell modified and unmodified copies of the Font
Software, subject to the following conditions:

1) Neither the Font Software nor any of its individual components,
in Source or Binary forms, may be sold by itself.

2) Original or Modified Versions of the Font Software may be bundled,
redistributed and/or sold with any software, provided that each copy
contains the above copyright notice and this license. These can be
included either as stand-alone text files, human-readable headers or
in the appropriate machine-readable metadata fields within text or
binary files as long as those fields can be easily viewed by the user.

3) No Modified Version of the Font Software may use the Reserved Font
Name(s) unless prominent written permission is granted by the
corresponding Copyright Holder. This restriction only applies to the
primary font name as presented to the users.

4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font
Software shall not be used to promote, endorse or advertise any
Modified Version, except to acknowledge the contribution(s) of the
Copyright Holder(s) and the Author(s) or with their explicit written
permission.

5) The Font Software, modified or unmodified, in part or in whole,
must be distributed entirely under this license, and must not be
distributed under any other license. The requirement for fonts to
remain under this license does not apply to any document created
using the Font Software.

TERMINATION
This license becomes null and void if any of the above conditions are
not met.

DISCLAIMER
THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE
COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL
DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE USE OR INABILITY TO USE THE
FONT SOFTWARE OR FROM OTHER DEALINGS IN THE FONT SOFTWARE.
```
