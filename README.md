# Eden - World Builder Mod

This patcher targets the original 64-bit Eden World Builder v1.5.0 executable.
The included `eden-mod.exe` is a precompiled copy of the patcher for users without GCC.

## Features

- `V`: Toggle flight. Move with WASD, Space to go up, and Ctrl to go down.
- `N`: Toggle collision-free/noclip movement through blocks, including bedrock.
- `O`: Toggle replace mode. Placing replaces the block under the crosshair instead of adding beside it; coloring continues to work normally.
- `L`: Start auto-fill, place point A, press `L` again, then place point B to draw a filled line, rectangle, or rectangular prism.
- `K`: After placing auto-fill point A, arm point B as hollow; lines stay solid, rectangles use their perimeter, and prisms use their outer faces.
- `J`: Start area clear, place point A, press `J` again, then place point B to destroy the inclusive line, rectangle, or rectangular-prism area.
- Press the active `J`, `K`, or `L` key again before placing its armed point to cancel, or press `Esc` at any time.
- `P`: Cycle repeated placement/breaking through 5, 10, 20, and 50 per second, then off. This saves having to repeatedly click to place or destroy a block. Works for colors too.
- `M`: Start recording a session-only macro; press `M` again (or reach 32,768 edits), then press `1`-`0` to save it in that preset.
- To replay a saved macro, press `M`, press its preset digit before making an edit, then place the anchor block; placements, breaks, block types, and colors replay relative to it.
- `Esc` cancels macro mode before its first recorded edit, while waiting to save, or after selecting a replay preset; it does not interrupt a recording that already contains edits.
- The 20/s repeat mode extends placement and breaking reach from the stock 15 blocks to 20 blocks; 50/s extends it to 50 blocks. Lower repeat modes retain stock reach.
- HUD squares show active modes, including a flashing dark-red macro-recording indicator and a solid green ready-to-save/replay indicator.
- Auto-fill replaces occupied cells and rejects operations larger than 1,048,576 candidate cells.
- Area clear uses the same 1,048,576-cell ceiling and respects the bedrock-breaking toggle.
- The J indicator is deep red while armed and brown while waiting after point A.
- Flight retains its existing acceleration rate but has a dramatically higher terminal speed.

The patcher checks the input binary before writing and refuses unsupported or already-patched inputs.

## Build

With the MSYS2 MinGW64 tools (`as`, `ld`, `objcopy`, and `gcc`) on `PATH`, run:

```powershell
.\build.bat
```

This reads `Eden - World Builder.exe`, creates `Eden - Modded.exe`, and removes intermediate files; optional input and output paths can be supplied as the first and second arguments.

The generated `eden-mod.exe` embeds its macro payload and is standalone; release users do not need `macro-payload.S` or any other build artifact.
