# Lexicon

Lexicon is a modern macOS AI client built with Swift + SwiftUI.

## Features

- Multi-session chat management
  - Create / switch / rename / delete sessions
  - Session history persists locally
- Collapsible/expandable left sidebar
- Independent Settings window (all connection/model/generation configs moved out of main chat UI)
- Multi-level Settings navigation
  - Workspace / Model / Generation grouped sections
  - In-app language switching inside Settings
- Multi-provider management
  - Add / switch / remove providers
  - Each provider has independent API type / API key / baseURL / model
- Model preset management
  - Save current model as preset
  - Add / delete / apply presets
- Text + image input (multi-image pick)
- Return to send
  - `Return` sends message
  - `Shift + Return` inserts newline
  - Chinese IME composition is respected (won't send while composing)
- Supports both OpenAI endpoint styles:
  - Chat Completions (`/v1/chat/completions`)
  - Responses (`/v1/responses`)
- Customizable `baseURL` (works with direct OpenAI and OpenAI-compatible proxies)
- Configurable:
  - API key
  - Model
  - System prompt
  - Context on/off
  - Temperature
  - Top P
  - Streaming on/off
- Streaming output rendering in chat UI
- Markdown rendering in assistant output
- Fenced code block rendering with lightweight syntax highlighting
- One-click code block copy button
- Chinese UI copy support
- Standard i18n localization via `Localizable.strings`
  - `en` and `zh-Hans` included
  - Automatically switches with macOS/app language preference
  - In-app language switch: Follow System / Simplified Chinese / English
- Auto light/dark theme following system appearance (with orange accent and rounded corners)

## Project Path

`/Users/luccazh/Documents/Programing☕️/Lexicon`

## Run

1. Open `Lexicon.xcodeproj` in Xcode.
2. Choose scheme `Lexicon`.
3. Run on `My Mac`.

## Notes

- `baseURL` can be entered as:
  - `https://api.openai.com`
  - `https://api.openai.com/v1`
  - `https://api.openai.com/v1/responses`
  - custom proxy domains
- Endpoint resolution is normalized automatically based on selected API type.
