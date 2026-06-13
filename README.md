<p align="center">
  <img src="Resources/Loom.png" alt="Loom icon" width="128" height="128">
</p>

<h1 align="center">Loom</h1>

Loom is a native macOS menu bar app that shows a live overlay of your Mission Control Spaces.

---

## Requirements

- macOS 14 or newer
- Apple Silicon or Intel Mac

## Build

```bash
./build.sh
```

The script writes the app bundle to `dist/Loom.app` and opens it after a successful build.

## Usage

- Hold **Control**: Show Spaces overlay
- Release **Control**: Hide Spaces overlay
- `Cmd+,`: Open Settings
- `Cmd+Q`: Quit Loom

## Project Layout

```text
Sources/Loom/      Swift source files
Resources/         App metadata and icon
dist/              Generated app bundle
build.sh           Local build script
```

## License

MIT
