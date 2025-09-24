# Haxe Standard Rules

## Language & Style
- Target Haxe 4.0.5 features; avoid deprecated APIs.
- Use explicit types for public APIs, fields, and function parameters/returns.
- Prefer meaningful, full-word names for classes, methods, and variables.
- Prefer early returns; avoid deep nesting beyond 2–3 levels.
- Handle errors explicitly; do not swallow exceptions.

## Null Safety
- Use `Null<T>` only when a value is legitimately optional.
- Initialize fields where declared when practical; guard access otherwise.

## Packages & Modules
- One top-level type per file; filename matches the type name.
- Package names are lowercase, dot-separated, aligned with directory structure.

## Collections & Iteration
- Prefer `for (x in collection)` with clear variable names.
- Avoid reflection/dynamic access unless necessary; prefer static typing.

## Macros & Conditional Compilation
- Keep macros small and well-documented; isolate in `macro` packages.
- Use `#if` flags sparingly; document build flags in `build.hxml`.

## I/O and Async
- Prefer non-blocking I/O APIs where available.
- Encapsulate async flows in well-named functions; avoid leaking implementation details.

## Formatting
- Follow the repo's `hxformat.json` where present.
- Keep lines reasonably short; wrap long expressions across lines.

## Testing & Logging
- Structure code to be testable (pure functions where possible).
- Use consistent logging; avoid printing in libraries by default.

## Builds
- Use the provided `build.hxml` files in `backend/` and `frontend/`.
- Keep external library versions pinned via `haxe_libraries/`.
