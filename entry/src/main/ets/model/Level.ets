import { Constants } from '../common/Constants';

/** A robot as defined in the level file (start position). */
export class RobotDef {
  color: number;
  x: number;
  y: number;

  constructor(color: number, x: number, y: number) {
    this.color = color;
    this.x = x;
    this.y = y;
  }
}

export class TargetDef {
  color: number;
  x: number;
  y: number;

  constructor(color: number, x: number, y: number) {
    this.color = color;
    this.x = x;
    this.y = y;
  }
}

/**
 * A wall on a cell edge.
 * Horizontal: top edge of cell (x, y), y in 0..height.
 * Vertical: left edge of cell (x, y), x in 0..width.
 */
export class WallDef {
  horizontal: boolean;
  x: number;
  y: number;

  constructor(horizontal: boolean, x: number, y: number) {
    this.horizontal = horizontal;
    this.x = x;
    this.y = y;
  }
}

export class LevelData {
  id: number;
  width: number;
  height: number;
  walls: WallDef[] = [];
  robots: RobotDef[] = [];
  targets: TargetDef[] = [];
  private hWalls: boolean[];
  private vWalls: boolean[];

  constructor(id: number, width: number, height: number) {
    this.id = id;
    this.width = width;
    this.height = height;
    this.hWalls = new Array<boolean>(width * (height + 1)).fill(false);
    this.vWalls = new Array<boolean>((width + 1) * height).fill(false);
  }

  addHorizontalWall(x: number, y: number): void {
    if (x < 0 || x >= this.width || y < 0 || y > this.height) {
      return;
    }
    const index = y * this.width + x;
    if (!this.hWalls[index]) {
      this.hWalls[index] = true;
      this.walls.push(new WallDef(true, x, y));
    }
  }

  addVerticalWall(x: number, y: number): void {
    if (x < 0 || x > this.width || y < 0 || y >= this.height) {
      return;
    }
    const index = y * (this.width + 1) + x;
    if (!this.vWalls[index]) {
      this.vWalls[index] = true;
      this.walls.push(new WallDef(false, x, y));
    }
  }

  /** Wall between rows y-1 and y in column x. */
  hasHorizontalWall(x: number, y: number): boolean {
    if (x < 0 || x >= this.width || y < 0 || y > this.height) {
      return false;
    }
    return this.hWalls[y * this.width + x];
  }

  /** Wall between columns x-1 and x in row y. */
  hasVerticalWall(x: number, y: number): boolean {
    if (x < 0 || x > this.width || y < 0 || y >= this.height) {
      return false;
    }
    return this.vWalls[y * (this.width + 1) + x];
  }
}

class RawEntry {
  type: string;
  data: string;

  constructor(type: string, data: string) {
    this.type = type;
    this.data = data;
  }
}

function parseColorChar(c: string): number {
  switch (c) {
    case 'm':
      return Constants.COLOR_MULTI;
    case 'r':
      return Constants.COLOR_PINK;
    case 'g':
      return Constants.COLOR_GREEN;
    case 'b':
      return Constants.COLOR_BLUE;
    case 'y':
      return Constants.COLOR_YELLOW;
    case 's':
      return Constants.COLOR_SILVER;
    default:
      return Constants.COLOR_UNKNOWN;
  }
}

function isDigit(c: string): boolean {
  return c >= '0' && c <= '9';
}

/** Tokenizer identical to LevelFormatParser.parseRawEntries: split on ';' and newlines, skip '#' comments. */
function parseRawEntries(content: string): RawEntry[] {
  const entries: RawEntry[] = [];
  const parts = content.split(new RegExp('[;\\n]'));
  for (const rawLine of parts) {
    const line = rawLine.trim();
    if (line.length === 0 || line.startsWith('#')) {
      continue;
    }
    const colonIndex = line.indexOf(':');
    let firstDigitIndex = -1;
    for (let i = 0; i < line.length; i++) {
      if (isDigit(line.charAt(i))) {
        firstDigitIndex = i;
        break;
      }
    }
    if (colonIndex !== -1 && (firstDigitIndex === -1 || colonIndex < firstDigitIndex)) {
      entries.push(new RawEntry(line.substring(0, colonIndex).trim(), line.substring(colonIndex + 1).trim()));
    } else if (firstDigitIndex !== -1) {
      entries.push(new RawEntry(line.substring(0, firstDigitIndex).trim(), line.substring(firstDigitIndex).trim()));
    }
  }
  return entries;
}

/** Parses "x,y" into [x, y], or returns null if malformed. */
function parseCoords(data: string): number[] | null {
  const parts = data.split(',');
  if (parts.length !== 2) {
    return null;
  }
  const x = parseInt(parts[0].trim(), 10);
  const y = parseInt(parts[1].trim(), 10);
  if (isNaN(x) || isNaN(y)) {
    return null;
  }
  return [x, y];
}

/**
 * Parses a Roboyard level file (same format as the Android app's Maps/level_N.txt):
 * board:W,H; hX,Y; (top wall) vX,Y; (left wall) t<c>X,Y; (target) r<c>X,Y; (robot)
 */
export function parseLevel(id: number, content: string): LevelData {
  const entries = parseRawEntries(content);
  let width = Constants.DEFAULT_BOARD_SIZE;
  let height = Constants.DEFAULT_BOARD_SIZE;
  for (const entry of entries) {
    if (entry.type === 'board') {
      const size = parseCoords(entry.data.startsWith(':') ? entry.data.substring(1) : entry.data);
      if (size !== null) {
        width = size[0];
        height = size[1];
      }
      break;
    }
  }

  const level = new LevelData(id, width, height);
  for (const entry of entries) {
    const type = entry.type;
    if (type === 'board' || type === 'solution' || type === 'num_moves') {
      continue;
    }
    const coords = parseCoords(entry.data);
    if (coords === null) {
      continue;
    }
    if (type === 'h' || type === 'mh') {
      level.addHorizontalWall(coords[0], coords[1]);
    } else if (type === 'v' || type === 'mv') {
      level.addVerticalWall(coords[0], coords[1]);
    } else if (type.length === 2 && type.charAt(0) === 't') {
      const color = parseColorChar(type.charAt(1));
      if (color !== Constants.COLOR_UNKNOWN) {
        level.targets.push(new TargetDef(color, coords[0], coords[1]));
      }
    } else if (type.length === 2 && type.charAt(0) === 'r') {
      const color = parseColorChar(type.charAt(1));
      if (color >= 0) {
        level.robots.push(new RobotDef(color, coords[0], coords[1]));
      }
    }
  }

  if (level.targets.length === 0) {
    throw new Error(`Level ${id} has no target`);
  }
  return level;
}
