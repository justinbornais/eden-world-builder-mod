# Eden Mod Improvement Report

## Building Tools

- Add bounded undo and redo for building, breaking, painting, and replacing.
- Let middle-click select the targeted block type and color.
- Add line, wall, plane, and box construction tools.
- Support region copy, rotation, mirroring, and paste previews.
- Add symmetry across configurable X, Y, or Z planes.
- Add continuous painting using the existing repeat-rate controls.
- Allow replacement to filter by the targeted block type.
- Add size-limited flood fill for connected blocks and colors.

## Movement and Camera

- Add precise, fast, and extreme flight-speed modes.
- Let Shift rapidly brake flight momentum.
- Provide separate vertical ascent and descent speed limits.
- Allow movement to be locked along selected axes.
- Add a detachable spectator camera.
- Record recent positions for quick return teleportation.
- Display coordinates, direction, selected block, and target distance.

## Placement Refinements

- Make 15-, 20-, and 50-block reach independent of repeat speed.
- Add fixed-distance and face-lock placement options.
- Prevent blocks from being placed inside the player.
- Show a transparent preview of the affected block cell.
- Add manual orientation controls for directional blocks.
- Provide a precision mode that temporarily suppresses repetition.

## World Safety

- Create rotating timestamped backups before saves and bulk edits.
- Journal pending edits for recovery after crashes.
- Generate a readable index mapping world files to world names.
- Validate world structure before loading or uploading.
- Require confirmation before exceptionally large edits.
- Add a read-only mode for safely inspecting worlds.

## Interface

- Add compact text labels for active mod states.
- Move keys, colors, speeds, reach, and limits into a configuration file.
- Show a brief on-screen control reference from a help key.
- Let users choose which settings persist between sessions.
- Play distinct sounds when toggles are enabled or disabled.

## Recommended Priorities

1. Add automatic rotating world backups.
2. Add undo and redo.
3. Add a targeted-block picker.
4. Separate reach and flight-speed controls from other modes.
5. Add coordinate and target information to the HUD.
6. Add line, wall, and box construction tools.
