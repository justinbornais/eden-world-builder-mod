# Eden World Builder Mod

A binary patcher for the 64-bit v1.5.0 release of Eden World Builder. The included `eden-mod.exe` is a standalone, precompiled patcher.

## Features

| Key | Feature |
| --- | --- |
| `V` | Toggle flight; use WASD, Space, and Ctrl to move. |
| `N` | Toggle noclip through all blocks. |
| `O` | Toggle replace mode, which places into the targeted block except bedrock. |
| `I` | Toggle targeting through water and lava; underwater breaks refill from adjacent water. |
| `P` | Cycle repeat speed: 5/s, 10/s, 20/s, 50/s, maximum, then off. |
| `R` | Cycle reach: 20 blocks, 50 blocks, 100 blocks, maximum practical range, then stock. |
| `L` | Select two points and build a filled line, rectangle, or rectangular prism. |
| `K` | After selecting auto-fill point A, build a hollow shape at point B. |
| `J` | Select two points and clear the enclosed area. |
| `M` | Record, save, and replay persistent macros using presets `1`-`0`. |

- Press the active `J`, `K`, or `L` key again before placing its next point, or press `Esc`, to cancel the operation.
- Fill and clear operations replace or remove up to 1,048,576 blocks; hollow lines remain solid, rectangles use their perimeter, and prisms use their outer faces.
- Macros preserve placements, breaks, replacements, block types, orientations, and colors in `%APPDATA%\Eden\eden_macros<suffix>.dat`.
- With Caps Lock enabled, a selected macro remains armed for repeated placement and number keys switch presets directly.
- Flight has independently configurable horizontal and vertical acceleration, coasting deceleration, and maximum speed.
- A persistent text panel reports every mode and its current state.

## Configuration

`mod-config.yaml` is optional; when it is absent, the mod uses its built-in defaults.

When placed beside `Eden - Modded.exe`, the YAML file supports up to eight ordered `autoplace_presets` and `range_presets`, plus `status_panel`, `caps_lock_macro_repeat`, `macro_file_suffix`, and separate horizontal/vertical flight acceleration, deceleration, and maximum-speed values; use `max` for every-update placement and `unlimited` for Eden's practical reach limit. For example, `macro_file_suffix: "_roads"` selects `%APPDATA%\Eden\eden_macros_roads.dat`; an empty suffix preserves the default filename.

Flight acceleration is added per game update; deceleration is a coast multiplier from `0` (instant stop) to `1` (no momentum loss), and maximum speed is a positive hard cap.

## Blueprint compiler

`blueprints\eden_macro_compiler.py` converts the declarative designs in `blueprints\eden_blueprints.json` into Eden's existing macro collection format. The generated example collection uses the `_ai_examples` suffix, so the adjacent configuration loads `%APPDATA%\Eden\eden_macros_ai_examples.dat` without replacing older collections. Press `M` and then `1` to select the road segment, or `M` and then `2` to select the small house; place the selected anchor block to replay the design.

The compiler is intentionally deterministic: an LLM can produce JSON operations such as `box`, `frame`, `line`, and `block`, while the compiler expands and validates them before writing the binary macro file. Blueprint coordinates are `x,y,z` with `y` vertical; the compiler translates them to Eden's native `x,z,y` event order when writing the file.

## Build

Place the original game at `Eden - World Builder.exe`, install the MSYS2 MinGW64 tools (`as`, `ld`, `objcopy`, and `gcc`), and run:

```powershell
.\build.bat
```

This rebuilds the standalone patcher and creates `Eden - Modded.exe`. Optional source and output paths may be supplied as the first and second arguments.

The patcher validates the input executable and refuses unsupported or already-modified builds.
