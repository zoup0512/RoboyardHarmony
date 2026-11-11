import { common } from '@kit.AbilityKit';

/** Holds the ability context so non-UI code (levels, progress) can reach resources and preferences. */
export class AppContext {
  private static context: common.UIAbilityContext | null = null;

  static init(context: common.UIAbilityContext): void {
    AppContext.context = context;
  }

  static get(): common.UIAbilityContext {
    if (AppContext.context === null) {
      throw new Error('AppContext not initialized');
    }
    return AppContext.context;
  }
}
