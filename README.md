# Eden World Builder Mod

A binary patcher for the 64-bit v1.5.0 release of Eden World Builder. The included `eden-mod.exe` is a standalone, precompiled patcher.

## Features

| Key | Feature |
| --- | --- |
| `V` | Toggle flight; use WASD, Space, and Ctrl to move. |
| `N` | Toggle noclip through all blocks. |
| `O` | Toggle replace mode, which places into the targeted block. |
| `I` | Toggle targeting through water and lava; underwater breaks refill from adjacent water. |
| `P` | Cycle repeat speed: 5/s, 10/s, 20/s, 50/s, maximum, then off. |
| `R` | Cycle reach: 20 blocks, 50 blocks, 100 blocks, maximum practical range, then stock. |
| `L` | Select two points and build a filled line, rectangle, or rectangular prism. |
| `K` | After selecting auto-fill point A, build a hollow shape at point B. |
| `J` | Select two points and clear the enclosed area. |
| `M` | Record, save, and replay persistent macros using presets `1`-`0`. |

- Press the active `J`, `K`, or `L` key again before placing its next point, or press `Esc`, to cancel the operation.
- Fill and clear operations replace or remove up to 1,048,576 blocks; hollow lines remain solid, rectangles use their perimeter, and prisms use their outer faces.
- Macros preserve placements, breaks, replacements, block types, orientations, and colors in `%APPDATA%\Eden\eden_macros.dat`.
- With Caps Lock enabled, a selected macro remains armed for repeated placement and number keys switch presets directly.
- Flight keeps the original acceleration rate but has a substantially higher maximum speed.
- A persistent text panel reports every mode and its current state.

## Configuration

`mod-config.yaml` is optional; when it is absent, the mod uses its built-in defaults.

When placed beside `Eden - Modded.exe`, the YAML file supports up to eight ordered `autoplace_presets` and `range_presets`, plus `status_panel` and `caps_lock_macro_repeat`; use `max` for every-update placement and `unlimited` for Eden's practical reach limit.

## Build

Place the original game at `Eden - World Builder.exe`, install the MSYS2 MinGW64 tools (`as`, `ld`, `objcopy`, and `gcc`), and run:

```powershell
.\build.bat
```

This rebuilds the standalone patcher and creates `Eden - Modded.exe`. Optional source and output paths may be supplied as the first and second arguments.

The patcher validates the input executable and refuses unsupported or already-modified builds.
