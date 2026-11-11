# Roboyard for HarmonyOS

HarmonyOS (ArkTS, Stage model) phone port of [Roboyard](../Roboyard). It keeps only the game screen and the 140 built-in levels. Achievements, random games, hints, the level editor, history and settings are not included.

## Open and run

1. Open this folder in DevEco Studio (HarmonyOS SDK API 12 or newer).
2. Let it sync, then set up signing: **File > Project Structure > Signing Configs > Automatically generate signature**.
3. Run the `entry` module on a phone or emulator.

## Layout

| Path | Content |
|---|---|
| `entry/src/main/ets/model/Level.ets` | Level file parser (same format as `Roboyard/shared/src/commonMain/resources/Maps`) |
| `entry/src/main/ets/model/GameSession.ets` | Movement rules, win check, undo, reverse-move undo, star rating |
| `entry/src/main/ets/model/ProgressStore.ets` | Stars per level, best moves, last played level (preferences) |
| `entry/src/main/ets/pages/LevelSelectPage.ets` | Level grid with stars and unlock logic |
| `entry/src/main/ets/pages/GamePage.ets` | Board rendering and touch input |
| `entry/src/main/resources/rawfile/Maps/` | The 140 level files, copied unchanged from the Android app |
| `entry/src/main/resources/rawfile/optimal_moves.json` | Optimal move count per level, used for stars |

## Optimal moves

The Android app computes the optimal move count at runtime with the DriftingDroids solver. This port ships a precomputed table instead. After changing level files, regenerate it:

```
node tools/compute_optimal_moves.js
```
