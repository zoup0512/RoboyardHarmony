import { Constants } from '../common/Constants';
import { LevelData } from './Level';

/** Live robot state; @Observed so robot sprites re-render when x/y/selection change. */
@Observed
export class RobotState {
  color: number;
  x: number;
  y: number;
  facingLeft: boolean = false;
  selected: boolean = false;

  constructor(color: number, x: number, y: number) {
    this.color = color;
    this.x = x;
    this.y = y;
  }
}

class MoveRecord {
  color: number;
  fromX: number;
  fromY: number;
  toX: number;
  toY: number;
  prevFacingLeft: boolean;

  constructor(color: number, fromX: number, fromY: number, toX: number, toY: number, prevFacingLeft: boolean) {
    this.color = color;
    this.fromX = fromX;
    this.fromY = fromY;
    this.toX = toX;
    this.toY = toY;
    this.prevFacingLeft = prevFacingLeft;
  }
}

export class MoveResult {
  /** Robot position changed (forward move or reverse-move undo). */
  changed: boolean = false;
  /** The move was a reverse move and was turned into an undo. */
  undone: boolean = false;
  /** Number of cells the robot travelled. */
  distance: number = 0;
  /** This move completed the level. */
  completedNow: boolean = false;
}

/**
 * Game rules, ported from GameSession.moveRobotInDirection / GameState.canRobotMoveTo:
 * a robot slides until the next cell is off the board, holds another robot, or a wall
 * lies on the shared edge. Targets do not stop robots.
 */
export class GameSession {
  readonly level: LevelData;
  readonly robots: RobotState[] = [];
  moveCount: number = 0;
  complete: boolean = false;
  private history: MoveRecord[] = [];

  constructor(level: LevelData) {
    this.level = level;
    for (const def of level.robots) {
      this.robots.push(new RobotState(def.color, def.x, def.y));
    }
  }

  getRobotAt(x: number, y: number): RobotState | null {
    for (const robot of this.robots) {
      if (robot.x === x && robot.y === y) {
        return robot;
      }
    }
    return null;
  }

  getSelectedRobot(): RobotState | null {
    for (const robot of this.robots) {
      if (robot.selected) {
        return robot;
      }
    }
    return null;
  }

  selectRobot(robot: RobotState | null): void {
    for (const r of this.robots) {
      r.selected = (r === robot);
    }
  }

  /** Selects the robot whose color matches the first target (Android selectRobotWithTargetColor). */
  selectRobotWithTargetColor(): void {
    const target = this.level.targets[0];
    for (const robot of this.robots) {
      if (robot.color === target.color) {
        this.selectRobot(robot);
        return;
      }
    }
    if (this.robots.length > 0) {
      this.selectRobot(this.robots[0]);
    }
  }

  /** Can the robot take one step from (x, y) in direction (dx, dy)? */
  private canStep(robot: RobotState, x: number, y: number, dx: number, dy: number): boolean {
    const nx = x + dx;
    const ny = y + dy;
    if (nx < 0 || nx >= this.level.width || ny < 0 || ny >= this.level.height) {
      return false;
    }
    const other = this.getRobotAt(nx, ny);
    if (other !== null && other !== robot) {
      return false;
    }
    if (dx > 0 && this.level.hasVerticalWall(nx, y)) {
      return false;
    }
    if (dx < 0 && this.level.hasVerticalWall(x, y)) {
      return false;
    }
    if (dy > 0 && this.level.hasHorizontalWall(x, ny)) {
      return false;
    }
    if (dy < 0 && this.level.hasHorizontalWall(x, y)) {
      return false;
    }
    return true;
  }

  /** Returns [endX, endY] the robot would slide to. */
  slideDestination(robot: RobotState, dx: number, dy: number): number[] {
    let x = robot.x;
    let y = robot.y;
    while (this.canStep(robot, x, y, dx, dy)) {
      x += dx;
      y += dy;
    }
    return [x, y];
  }

  /** Moves the selected robot in direction (dx, dy). */
  moveSelected(dx: number, dy: number): MoveResult {
    const result = new MoveResult();
    const robot = this.getSelectedRobot();
    if (robot === null) {
      return result;
    }
    const dest = this.slideDestination(robot, dx, dy);
    const distance = Math.abs(dest[0] - robot.x) + Math.abs(dest[1] - robot.y);

    // Reverse move = undo (only before the level is complete), like the Android app.
    if (!this.complete && this.history.length > 0) {
      const last = this.history[this.history.length - 1];
      if (last.color === robot.color && robot.x === last.toX && robot.y === last.toY &&
        dest[0] === last.fromX && dest[1] === last.fromY) {
        this.undo();
        result.changed = true;
        result.undone = true;
        result.distance = distance;
        return result;
      }
    }

    if (dx !== 0) {
      // Android only updates the sprite direction on horizontal input, even if the robot cannot move.
      const prevFacing = robot.facingLeft;
      robot.facingLeft = dx < 0;
      if (distance === 0) {
        return result;
      }
      this.history.push(new MoveRecord(robot.color, robot.x, robot.y, dest[0], dest[1], prevFacing));
    } else {
      if (distance === 0) {
        return result;
      }
      this.history.push(new MoveRecord(robot.color, robot.x, robot.y, dest[0], dest[1], robot.facingLeft));
    }

    if (!this.complete) {
      this.moveCount += 1;
    }
    robot.x = dest[0];
    robot.y = dest[1];
    result.changed = true;
    result.distance = distance;
    if (!this.complete && this.areAllRobotsAtTargets()) {
      this.complete = true;
      result.completedNow = true;
    }
    return result;
  }

  /** Undoes the last move. Returns the moved robot or null if there is nothing to undo. */
  undo(): RobotState | null {
    const last = this.history.pop();
    if (last === undefined) {
      return null;
    }
    for (const robot of this.robots) {
      if (robot.color === last.color) {
        robot.x = last.fromX;
        robot.y = last.fromY;
        robot.facingLeft = last.prevFacingLeft;
        this.selectRobot(robot);
        this.moveCount = Math.max(0, this.moveCount - 1);
        this.complete = false;
        return robot;
      }
    }
    return null;
  }

  canUndo(): boolean {
    return this.history.length > 0;
  }

  /** Puts all robots back to their start positions and clears the counters. */
  reset(): void {
    for (let i = 0; i < this.robots.length; i++) {
      const def = this.level.robots[i];
      this.robots[i].x = def.x;
      this.robots[i].y = def.y;
      this.robots[i].facingLeft = false;
    }
    this.history = [];
    this.moveCount = 0;
    this.complete = false;
    this.selectRobotWithTargetColor();
  }

  private isRobotAtTarget(robot: RobotState): boolean {
    for (const target of this.level.targets) {
      if (target.x === robot.x && target.y === robot.y &&
        (target.color === Constants.COLOR_MULTI || target.color === robot.color)) {
        return true;
      }
    }
    return false;
  }

  /** Win check from GameState.areAllRobotsAtTargets. */
  areAllRobotsAtTargets(): boolean {
    const targetCount = this.level.targets.length;
    const robotCount = Math.min(Math.max(targetCount, 1), 4);
    const required = Math.min(robotCount, targetCount);
    if (required < 1) {
      return false;
    }
    let atTarget = 0;
    for (const robot of this.robots) {
      if (this.isRobotAtTarget(robot)) {
        atTarget++;
      }
    }
    return atTarget >= required;
  }
}

/** StarRating.calculateStars plus the beginner guarantee for levels 1..10. */
export function calculateStars(levelId: number, playerMoves: number, optimalMoves: number): number {
  let stars: number;
  if (optimalMoves <= 0) {
    stars = 1;
  } else if (playerMoves === optimalMoves) {
    stars = 3;
  } else if (playerMoves <= optimalMoves + 1) {
    stars = 2;
  } else {
    stars = 1;
  }
  if (stars < 1 && levelId <= Constants.MIN_STAR_GUARANTEE_LEVEL) {
    stars = 1;
  }
  return stars;
}
