import { preferences } from '@kit.ArkData';
import { AppContext } from '../common/AppContext';
import { Constants } from '../common/Constants';

/**
 * Level progress, stored in preferences. Mirrors the parts of the Android
 * LevelCompletionManager that the level selection needs: best stars per level
 * (only ever increases), fewest moves, and the last played level.
 */
export class ProgressStore {
  private static prefs: preferences.Preferences | null = null;

  private static store(): preferences.Preferences {
    if (ProgressStore.prefs === null) {
      const options: preferences.Options = { name: 'roboyard_progress' };
      ProgressStore.prefs = preferences.getPreferencesSync(AppContext.get(), options);
    }
    return ProgressStore.prefs;
  }

  static getStars(levelId: number): number {
    return ProgressStore.store().getSync(`stars_${levelId}`, 0) as number;
  }

  static isCompleted(levelId: number): boolean {
    return ProgressStore.store().getSync(`completed_${levelId}`, false) as boolean;
  }

  static getBestMoves(levelId: number): number {
    return ProgressStore.store().getSync(`best_moves_${levelId}`, 0) as number;
  }

  static getTotalStars(): number {
    let total = 0;
    for (let id = 1; id <= Constants.LEVEL_COUNT; id++) {
      total += ProgressStore.getStars(id);
    }
    return total;
  }

  static getCompletedCount(): number {
    let count = 0;
    for (let id = 1; id <= Constants.LEVEL_COUNT; id++) {
      if (ProgressStore.isCompleted(id)) {
        count++;
      }
    }
    return count;
  }

  /** Level N is unlocked once the player has (N - 1) * STARS_PER_LEVEL stars in total. */
  static isUnlocked(levelId: number, totalStars: number): boolean {
    return Constants.STARS_PER_LEVEL * (levelId - 1) <= totalStars;
  }

  static starsNeeded(levelId: number, totalStars: number): number {
    return Math.max(0, (levelId - 1) * Constants.STARS_PER_LEVEL - totalStars);
  }

  static saveCompletion(levelId: number, stars: number, moves: number): void {
    const store = ProgressStore.store();
    const clamped = Math.max(0, Math.min(3, stars));
    if (clamped > ProgressStore.getStars(levelId)) {
      store.putSync(`stars_${levelId}`, clamped);
    }
    const best = ProgressStore.getBestMoves(levelId);
    if (best <= 0 || moves < best) {
      store.putSync(`best_moves_${levelId}`, moves);
    }
    store.putSync(`completed_${levelId}`, true);
    store.flush();
  }

  static getLastPlayedLevel(): number {
    return ProgressStore.store().getSync('last_played_level', 1) as number;
  }

  static setLastPlayedLevel(levelId: number): void {
    const store = ProgressStore.store();
    store.putSync('last_played_level', levelId);
    store.flush();
  }
}
