import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppContext } from '../common/AppContext';
import { GameParams, robotImage, targetImage } from '../common/Assets';
import { Constants } from '../common/Constants';
import { calculateStars, GameSession, MoveResult, RobotState } from '../model/GameSession';
import { LevelData, RobotDef, TargetDef, WallDef } from '../model/Level';
import { LevelRepository } from '../model/LevelRepository';
import { ProgressStore } from '../model/ProgressStore';

const TAG = 'GamePage';
const GRID_LINE_COLOR = '#4AE600';

/** One robot sprite; re-renders when the observed robot moves or changes selection. */
@Component
struct RobotSprite {
  @ObjectLink robot: RobotState;
  @Prop cellSize: number = 0;

  build() {
    Image(robotImage(this.robot.color, this.robot.facingLeft))
      .width(this.cellSize)
      .height(this.cellSize)
      .objectFit(ImageFit.Fill)
      .scale({
        x: this.robot.selected ? Constants.SELECTED_ROBOT_SCALE : Constants.ROBOT_SCALE,
        y: this.robot.selected ? Constants.SELECTED_ROBOT_SCALE : Constants.ROBOT_SCALE
      })
      .position({ x: this.robot.x * this.cellSize, y: this.robot.y * this.cellSize })
      .zIndex(this.robot.selected ? 3 : 2)
      .hitTestBehavior(HitTestMode.None)
  }
}

@Entry
@Component
struct GamePage {
  @State level: LevelData | null = null;
  @State robots: RobotState[] = [];
  @State moveCount: number = 0;
  @State complete: boolean = false;
  @State earnedStars: number = 0;
  @State optimalMoves: number = -1;
  @State cellSize: number = 0;
  @State tileRotations: number[] = [];
  @State cells: number[] = [];
  @State boardKeys: string[] = [];
  private session: GameSession | null = null;
  private boardAreaWidth: number = 0;
  private boardAreaHeight: number = 0;
  private animating: boolean = false;
  // Touch tracking (GameGridView.onTouchEvent)
  private touchStartX: number = -1;
  private touchStartY: number = -1;
  private touchedRobot: RobotState | null = null;
  private robotActivatedBySwipe: boolean = false;
  private movedInGesture: boolean = false;

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as GameParams;
    const levelId = params !== undefined && params !== null && params.levelId > 0 ? params.levelId : 1;
    this.startLevel(levelId);
  }

  private startLevel(levelId: number): void {
    let level: LevelData;
    try {
      level = LevelRepository.loadLevel(levelId);
    } catch (e) {
      hilog.error(0x0000, TAG, 'Failed to load level %{public}d: %{public}s', levelId, JSON.stringify(e));
      this.toast(AppContext.get().resourceManager.getStringByNameSync('level_load_error', levelId));
      return;
    }
    const session = new GameSession(level);
    session.selectRobotWithTargetColor();
    this.session = session;

    const cells: number[] = [];
    const rotations: number[] = [];
    for (let i = 0; i < level.width * level.height; i++) {
      cells.push(i);
      rotations.push(Math.floor(Math.random() * 4) * 90);
    }
    this.cells = cells;
    this.tileRotations = rotations;
    this.level = level;
    this.robots = session.robots;
    this.boardKeys = [`board_${levelId}`];
    this.moveCount = 0;
    this.complete = false;
    this.earnedStars = 0;
    this.optimalMoves = LevelRepository.getOptimalMoves(levelId);
    this.animating = false;
    this.updateCellSize();
    ProgressStore.setLastPlayedLevel(levelId);
  }

  private updateCellSize(): void {
    const level = this.level;
    if (level === null || this.boardAreaWidth <= 0 || this.boardAreaHeight <= 0) {
      return;
    }
    const fit = Math.min(this.boardAreaWidth / level.width, this.boardAreaHeight / level.height);
    // Snap to whole pixels so the floor tiles line up without seams.
    const ui = this.getUIContext();
    this.cellSize = ui.px2vp(Math.floor(ui.vp2px(fit)));
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  // ── Moves ────────────────────────────────────────────────────────────

  private moveSelected(dx: number, dy: number): void {
    const session = this.session;
    if (session === null || this.animating) {
      return;
    }
    const robot = session.getSelectedRobot();
    if (robot === null) {
      return;
    }
    const dest = session.slideDestination(robot, dx, dy);
    const cells = Math.abs(dest[0] - robot.x) + Math.abs(dest[1] - robot.y);
    const duration = Math.min(Constants.ANIM_MAX_MS,
      Math.max(Constants.ANIM_MIN_MS, cells * Constants.ANIM_MS_PER_CELL));

    let result: MoveResult = new MoveResult();
    this.animating = true;
    this.getUIContext().animateTo({ duration: duration, curve: Curve.EaseOut }, () => {
      result = session.moveSelected(dx, dy);
    });
    setTimeout(() => {
      this.animating = false;
    }, result.changed ? duration : 0);

    this.moveCount = session.moveCount;
    this.complete = session.complete;
    if (result.completedNow) {
      this.onLevelComplete();
    }
  }

  private onLevelComplete(): void {
    const session = this.session;
    if (session === null) {
      return;
    }
    const levelId = session.level.id;
    const stars = calculateStars(levelId, session.moveCount, this.optimalMoves);
    this.earnedStars = stars;
    ProgressStore.saveCompletion(levelId, stars, session.moveCount);
    hilog.info(0x0000, TAG, 'Level %{public}d complete: moves=%{public}d optimal=%{public}d stars=%{public}d',
      levelId, session.moveCount, this.optimalMoves, stars);
  }

  private undo(): void {
    const session = this.session;
    if (session === null || this.animating) {
      return;
    }
    if (!session.canUndo()) {
      this.getUIContext().getRouter().back();
      return;
    }
    this.getUIContext().animateTo({ duration: Constants.ANIM_MIN_MS * 2, curve: Curve.EaseOut }, () => {
      session.undo();
    });
    this.moveCount = session.moveCount;
    this.complete = session.complete;
  }

  private reset(): void {
    const session = this.session;
    if (session === null || this.animating) {
      return;
    }
    session.reset();
    this.moveCount = 0;
    this.complete = false;
    this.earnedStars = 0;
  }

  private nextLevel(): void {
    const session = this.session;
    if (session === null) {
      return;
    }
    const nextId = session.level.id + 1;
    if (nextId > Constants.LEVEL_COUNT) {
      this.toast(AppContext.get().resourceManager.getStringByNameSync('last_level_message'));
      return;
    }
    const totalStars = ProgressStore.getTotalStars();
    if (!ProgressStore.isUnlocked(nextId, totalStars)) {
      this.toast(AppContext.get().resourceManager.getStringByNameSync('level_not_unlocked',
        ProgressStore.starsNeeded(nextId, totalStars)));
      return;
    }
    this.startLevel(nextId);
  }

  private selectRobot(robot: RobotState): void {
    const session = this.session;
    if (session === null) {
      return;
    }
    this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
      session.selectRobot(robot);
    });
  }

  // ── Touch input: tap a robot to select it, swipe it, or tap a cell to move toward it ──

  private handleTouch(event: TouchEvent): void {
    const session = this.session;
    const level = this.level;
    if (session === null || level === null || this.cellSize <= 0) {
      return;
    }
    const point = event.changedTouches.length > 0 ? event.changedTouches[0] : event.touches[0];
    if (point === undefined) {
      return;
    }
    const x = point.x;
    const y = point.y;
    const gridX = Math.floor(x / this.cellSize);
    const gridY = Math.floor(y / this.cellSize);
    const insideGrid = gridX >= 0 && gridX < level.width && gridY >= 0 && gridY < level.height;

    if (event.type === TouchType.Down) {
      this.touchStartX = x;
      this.touchStartY = y;
      this.movedInGesture = false;
      this.robotActivatedBySwipe = false;
      this.touchedRobot = insideGrid ? session.getRobotAt(gridX, gridY) : null;
      if (this.touchedRobot !== null && !this.animating) {
        this.selectRobot(this.touchedRobot);
      }
      return;
    }

    if (event.type === TouchType.Move) {
      if (this.movedInGesture || this.animating || this.touchStartX < 0) {
        return;
      }
      if (this.touchedRobot === null) {
        // Swiping over a robot activates it; a further swipe moves it.
        const over = insideGrid ? session.getRobotAt(gridX, gridY) : null;
        if (over !== null) {
          this.touchedRobot = over;
          this.robotActivatedBySwipe = true;
          this.touchStartX = x;
          this.touchStartY = y;
          this.selectRobot(over);
        }
        return;
      }
      const deltaX = x - this.touchStartX;
      const deltaY = y - this.touchStartY;
      const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);
      const threshold = this.robotActivatedBySwipe ? Constants.ROBOT_MOVE_THRESHOLD : Constants.MIN_SWIPE_DISTANCE;
      const swiped = this.touchedRobot;
      if (distance >= threshold && swiped !== null) {
        this.movedInGesture = true;
        session.selectRobot(swiped);
        if (Math.abs(deltaX) > Math.abs(deltaY)) {
          this.moveSelected(deltaX > 0 ? 1 : -1, 0);
        } else {
          this.moveSelected(0, deltaY > 0 ? 1 : -1);
        }
      }
      return;
    }

    if (event.type === TouchType.Up) {
      const deltaX = x - this.touchStartX;
      const deltaY = y - this.touchStartY;
      const isTap = !this.movedInGesture && this.touchStartX >= 0 &&
        Math.sqrt(deltaX * deltaX + deltaY * deltaY) < Constants.MIN_SWIPE_DISTANCE;
      this.resetTouch();
      if (!isTap || !insideGrid || this.animating) {
        return;
      }
      const selected = session.getSelectedRobot();
      const clicked = session.getRobotAt(gridX, gridY);
      if (clicked !== null) {
        if (clicked !== selected) {
          this.selectRobot(clicked);
        }
        return;
      }
      if (selected === null) {
        return;
      }
      const dx = gridX - selected.x;
      const dy = gridY - selected.y;
      if (selected.x === gridX) {
        this.moveSelected(0, dy > 0 ? 1 : -1);
      } else if (selected.y === gridY) {
        this.moveSelected(dx > 0 ? 1 : -1, 0);
      } else if (Math.abs(dx) > Math.abs(dy)) {
        this.moveSelected(dx > 0 ? 1 : -1, 0);
      } else {
        this.moveSelected(0, dy > 0 ? 1 : -1);
      }
      return;
    }

    if (event.type === TouchType.Cancel) {
      this.resetTouch();
    }
  }

  private resetTouch(): void {
    this.touchStartX = -1;
    this.touchStartY = -1;
    this.touchedRobot = null;
    this.movedInGesture = false;
    this.robotActivatedBySwipe = false;
  }

  // ── Board rendering (GameGridView.onDraw + WallRenderer) ─────────────

  /** The 4 walls of the cross inside the 2x2 center block are not drawn (WallRenderer.isWallInCenterSquare). */
  private isCenterCrossWall(level: LevelData, wall: WallDef): boolean {
    const cx = Math.floor(level.width / 2) - 1;
    const cy = Math.floor(level.height / 2) - 1;
    if (wall.horizontal) {
      return wall.y === cy + 1 && (wall.x === cx || wall.x === cx + 1);
    }
    return wall.x === cx + 1 && (wall.y === cy || wall.y === cy + 1);
  }

  @Builder
  WallImage(level: LevelData, wall: WallDef) {
    if (wall.horizontal) {
      Image($r('app.media.mh'))
        .objectFit(ImageFit.Fill)
        .position({
          x: wall.x * this.cellSize - this.cellSize * Constants.WALL_OFFSET_FACTOR,
          y: wall.y * this.cellSize - this.cellSize * Constants.WALL_THICKNESS_FACTOR / 2
        })
        .width(Math.min((wall.x + 1) * this.cellSize + this.cellSize * Constants.WALL_OFFSET_FACTOR,
          level.width * this.cellSize) - (wall.x * this.cellSize - this.cellSize * Constants.WALL_OFFSET_FACTOR))
        .height(this.cellSize * Constants.WALL_THICKNESS_FACTOR)
        .hitTestBehavior(HitTestMode.None)
    } else {
      Image($r('app.media.mv'))
        .objectFit(ImageFit.Fill)
        .position({
          x: wall.x * this.cellSize - this.cellSize * Constants.WALL_THICKNESS_FACTOR / 2,
          y: wall.y * this.cellSize - this.cellSize * Constants.WALL_OFFSET_FACTOR
        })
        .width(this.cellSize * Constants.WALL_THICKNESS_FACTOR)
        .height(Math.min((wall.y + 1) * this.cellSize + this.cellSize * Constants.WALL_OFFSET_FACTOR,
          level.height * this.cellSize) - (wall.y * this.cellSize - this.cellSize * Constants.WALL_OFFSET_FACTOR))
        .hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  Board(level: LevelData) {
    Stack() {
      // Floor tiles, randomly rotated, with green grid lines
      ForEach(this.cells, (cell: number) => {
        Image($r('app.media.grid_tiles'))
          .width(this.cellSize)
          .height(this.cellSize)
          .objectFit(ImageFit.Fill)
          .rotate({ angle: this.tileRotations[cell] })
          .border({ width: '1.5px', color: GRID_LINE_COLOR })
          .position({ x: (cell % level.width) * this.cellSize, y: Math.floor(cell / level.width) * this.cellSize })
          .hitTestBehavior(HitTestMode.None)
      }, (cell: number) => `${level.id}_${cell}`)

      // Roboyard logo in the 2x2 center block
      Image($r('app.media.roboyard'))
        .objectFit(ImageFit.Fill)
        .width(this.cellSize * 2)
        .height(this.cellSize * 2)
        .position({
          x: (Math.floor(level.width / 2) - 1) * this.cellSize,
          y: (Math.floor(level.height / 2) - 1) * this.cellSize
        })
        .hitTestBehavior(HitTestMode.None)

      ForEach(level.targets, (target: TargetDef) => {
        Image(targetImage(target.color))
          .objectFit(ImageFit.Fill)
          .width(this.cellSize)
          .height(this.cellSize)
          .position({ x: target.x * this.cellSize, y: target.y * this.cellSize })
          .hitTestBehavior(HitTestMode.None)
      }, (target: TargetDef, index: number) => `${level.id}_t${index}`)

      ForEach(level.walls.filter((w: WallDef) => !this.isCenterCrossWall(level, w)), (wall: WallDef) => {
        this.WallImage(level, wall)
      }, (wall: WallDef) => `${level.id}_${wall.horizontal ? 'h' : 'v'}${wall.x},${wall.y}`)

      // Faint ghosts at the robots' start positions
      ForEach(level.robots, (def: RobotDef) => {
        Image(robotImage(def.color, false))
          .objectFit(ImageFit.Fill)
          .width(this.cellSize)
          .height(this.cellSize)
          .scale({ x: Constants.ROBOT_SCALE, y: Constants.ROBOT_SCALE })
          .opacity(Constants.GHOST_OPACITY)
          .position({ x: def.x * this.cellSize, y: def.y * this.cellSize })
          .hitTestBehavior(HitTestMode.None)
      }, (def: RobotDef) => `${level.id}_g${def.color}`)

      ForEach(this.robots, (robot: RobotState) => {
        RobotSprite({ robot: robot, cellSize: this.cellSize })
      }, (robot: RobotState) => `${level.id}_r${robot.color}`)
    }
    .width(level.width * this.cellSize)
    .height(level.height * this.cellSize)
    .backgroundColor('#1E1E3C')
    .clip(true)
    .onTouch((event: TouchEvent) => this.handleTouch(event))
  }

  @Builder
  ControlButton(label: ResourceStr, highlighted: boolean, action: () => void) {
    Button(label)
      .layoutWeight(1)
      .height(44)
      .fontSize(15)
      .fontColor(Color.White)
      .backgroundColor(highlighted ? '#4CAF50' : '#1976D2')
      .borderRadius(8)
      .onClick(action)
  }

  build() {
    Column() {
      // Top bar: level and move counter
      Row() {
        if (this.level !== null) {
          Text($r('app.string.level_id_text', this.level.id))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .layoutWeight(1)
        }
        Text($r('app.string.moves_text', this.moveCount))
          .fontSize(18)
          .fontColor('#FFD700')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // Board area
      Column() {
        if (this.level !== null && this.cellSize > 0) {
          // Keyed by level id so the board is rebuilt with the new level data on "Next Level"
          // (builder parameters are passed by value and would otherwise stay stale).
          ForEach(this.boardKeys, (key: string) => {
            this.Board(this.level as LevelData)
          }, (key: string) => key)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding(4)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .onAreaChange((oldArea: Area, newArea: Area) => {
        this.boardAreaWidth = (newArea.width as number) - 8;
        this.boardAreaHeight = (newArea.height as number) - 8;
        this.updateCellSize();
      })

      // Status: completion message with stars
      Column({ space: 4 }) {
        if (this.complete) {
          Row({ space: 6 }) {
            Text($r('app.string.level_complete'))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#72FF56')
            ForEach(new Array<number>(this.earnedStars).fill(0), (_: number, index: number) => {
              Image($r('app.media.star')).width(22).height(22)
            }, (_: number, index: number) => `star_${index}`)
          }
          if (this.optimalMoves > 0) {
            Text($r('app.string.optimal_moves', this.optimalMoves))
              .fontSize(14)
              .fontColor(Color.White)
          }
        }
      }
      .width('100%')
      .height(56)
      .justifyContent(FlexAlign.Center)

      // Controls
      Row({ space: 8 }) {
        this.ControlButton($r('app.string.button_back_game'), false, () => this.undo())
        this.ControlButton($r('app.string.button_reset'), false, () => this.reset())
        this.ControlButton($r('app.string.button_menu'), false, () => this.getUIContext().getRouter().back())
        this.ControlButton($r('app.string.next_level'), this.complete, () => this.nextLevel())
      }
      .width('100%')
      .padding({ left: 12, right: 12, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_dark'))
  }
}
