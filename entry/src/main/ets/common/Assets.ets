import { Constants } from './Constants';

/** Robot sprite for a color; Android GameGridView falls back to pink for unknown colors. */
export function robotImage(color: number, facingLeft: boolean): Resource {
  switch (color) {
    case Constants.COLOR_GREEN:
      return facingLeft ? $r('app.media.robot_green_left') : $r('app.media.robot_green_right');
    case Constants.COLOR_BLUE:
      return facingLeft ? $r('app.media.robot_blue_left') : $r('app.media.robot_blue_right');
    case Constants.COLOR_YELLOW:
      return facingLeft ? $r('app.media.robot_yellow_left') : $r('app.media.robot_yellow_right');
    case Constants.COLOR_SILVER:
      return facingLeft ? $r('app.media.robot_silver_left') : $r('app.media.robot_silver_right');
    default:
      return facingLeft ? $r('app.media.robot_pink_left') : $r('app.media.robot_pink_right');
  }
}

/** Target image for a color; multi (and anything unknown) uses target_multi. */
export function targetImage(color: number): Resource {
  switch (color) {
    case Constants.COLOR_PINK:
      return $r('app.media.target_pink');
    case Constants.COLOR_GREEN:
      return $r('app.media.target_green');
    case Constants.COLOR_BLUE:
      return $r('app.media.target_blue');
    case Constants.COLOR_YELLOW:
      return $r('app.media.target_yellow');
    case Constants.COLOR_SILVER:
      return $r('app.media.target_silver');
    default:
      return $r('app.media.target_multi');
  }
}

/** Router parameters for GamePage. */
export class GameParams {
  levelId: number;

  constructor(levelId: number) {
    this.levelId = levelId;
  }
}
