# Community & Ecosystem Specification

Architecture and data schema for community ecosystem resources and links displayed within the DSH native app.

## Overview
The community section provides discovery of official resources, plugins, extensions, and user forums without hardcoding changing endpoints into binary releases.

## Schema
Data is delivered via `app/assets/community/community.json` or fetched from repository release metadata:
- `groups`: Logical categorization of community links (Discussion, Plugins, Prompts, Documentation).
- `items`: Individual entries specifying `id`, `name`, `description`, `url`, `icon`, and optional `qr` code preview.
- All external links must use strict HTTPS and prompt user confirmation prior to opening in an external browser.
