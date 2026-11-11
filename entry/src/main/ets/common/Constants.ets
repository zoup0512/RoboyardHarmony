/**
 * Game constants, mirrored from the Android reference implementation
 * (shared/src/commonMain/kotlin/roboyard/logic/core/Constants.kt).
 */
export class Constants {
  static readonly COLOR_MULTI: number = -1;
  static readonly COLOR_PINK: number = 0;
  static readonly COLOR_GREEN: number = 1;
  static readonly COLOR_BLUE: number = 2;
  static readonly COLOR_YELLOW: number = 3;
  static readonly COLOR_SILVER: number = 4;
  /** Returned by the color parser for unknown color letters. */
  static readonly COLOR_UNKNOWN: number = -2;

  static readonly LEVEL_COUNT: number = 140;
  /** Stars needed per level to unlock the next one: level N needs (N - 1) * STARS_PER_LEVEL stars. */
  static readonly STARS_PER_LEVEL: number = 1;
  /** Levels 1..10 always award at least one star. */
  static readonly MIN_STAR_GUARANTEE_LEVEL: number = 10;

  static readonly DEFAULT_BOARD_SIZE: number = 14;

  /** Robot sprite scale relative to one cell (GameGridView.DEFAULT_ROBOT_SCALE / SELECTED_ROBOT_SCALE). */
  static readonly ROBOT_SCALE: number = 1.1;
  static readonly SELECTED_ROBOT_SCALE: number = 1.3;
  /** Wall image thickness and overhang relative to one cell (WallRenderer). */
  static readonly WALL_THICKNESS_FACTOR: number = 0.6;
  static readonly WALL_OFFSET_FACTOR: number = 0.24;
  /** Opacity of the start-position ghost robots (alpha 55 of 255). */
  static readonly GHOST_OPACITY: number = 55 / 255;

  /** Swipe thresholds in vp (Android uses 30 px and 60 px). */
  static readonly MIN_SWIPE_DISTANCE: number = 12;
  static readonly ROBOT_MOVE_THRESHOLD: number = 24;

  /** Robot slide animation timing. */
  static readonly ANIM_MS_PER_CELL: number = 60;
  static readonly ANIM_MIN_MS: number = 120;
  static readonly ANIM_MAX_MS: number = 450;
}
