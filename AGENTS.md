# Repository Guidelines

## Project Structure & Module Organization
- Core Flutter source lives in `lib/`, with the application entry point in `lib/main.dart`.
- Widget and integration tests reside in `test/`; mirror production file names (e.g., `main_test.dart`).
- Platform scaffolding is generated under `macos/` and `windows/`; keep custom native code isolated in `Runner/` subfolders.
- Shared configuration is tracked at the root (`pubspec.yaml`, `analysis_options.yaml`); update these before checking in new dependencies or lints.

## Build, Test, and Development Commands
- `flutter pub get` installs declared dependencies; run whenever `pubspec.yaml` changes.
- `flutter run -d macos` (or another device id) launches the app for interactive testing.
- `flutter analyze` surfaces static analysis issues defined by the Flutter lint set.
- `flutter test` runs all Dart tests in `test/`; combine with `--coverage` when validating coverage locally.

## Coding Style & Naming Conventions
- Follow the default Dart formatter (`dart format .`); commit only formatted code (two-space indentation, trailing commas where helpful).
- Use `UpperCamelCase` for classes/widgets, `lowerCamelCase` for fields, and `SCREAMING_SNAKE_CASE` for constants.
- Keep widget build methods lean; extract helper widgets into `lib/widgets/` (create the folder if absent) for reuse.
- Respect the `flutter_lints` ruleset; silence lints inline only with clear justification.

## Testing Guidelines
- Pair each new view model or service with a focused unit or widget test in `test/` named `<feature>_test.dart`.
- Stub external platform interactions with lightweight fakes or test-only wrappers; avoid hitting live services in tests.
- When modifying UI flows, update the relevant widget or integration tests before merging to prevent regressions.

## Commit & Pull Request Guidelines
- Write Conventional Commit-style messages (e.g., `feat: add launcher localization`); keep the summary under 72 characters.
- Group related changes per commit and ensure `flutter analyze` and `flutter test` pass before pushing.
- Pull requests should describe user-facing changes, link relevant issues, and attach screenshots for UI updates.
- Request at least one reviewer and respond to feedback with follow-up commits rather than force-pushes.
