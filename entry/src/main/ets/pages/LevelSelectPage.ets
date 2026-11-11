import { AppContext } from '../common/AppContext';
import { GameParams } from '../common/Assets';
import { Constants } from '../common/Constants';
import { ProgressStore } from '../model/ProgressStore';

// Card colors from bg_level_card_gold / _blue / _locked.xml
const GOLD_GRADIENT: Array<[ResourceColor, number]> = [['#C8A415', 0.0], ['#E8C840', 0.5], ['#A07A10', 1.0]];
const BLUE_GRADIENT: Array<[ResourceColor, number]> = [['#1565C0', 0.0], ['#1E88E5', 0.5], ['#0D47A1', 1.0]];
const LOCKED_GRADIENT: Array<[ResourceColor, number]> = [['#9E9E9E', 0.0], ['#BDBDBD', 0.5], ['#757575', 1.0]];
// bg_level_screen.xml and bg_level_header.xml
const SCREEN_GRADIENT: Array<[ResourceColor, number]> = [['#7CB342', 0.0], ['#CCDB44', 0.5], ['#848436', 1.0]];
const HEADER_GRADIENT: Array<[ResourceColor, number]> = [['#1B5E20', 0.0], ['#2E7D32', 1.0]];
const SHADOW_LAST_PLAYED: ShadowOptions = { radius: 8, color: '#80000000', offsetY: 2 };
const SHADOW_DEFAULT: ShadowOptions = { radius: 2, color: '#40000000' };

class LevelCardInfo {
  id: number;
  stars: number;
  completed: boolean;
  unlocked: boolean;
  lastPlayed: boolean;

  constructor(id: number, stars: number, completed: boolean, unlocked: boolean, lastPlayed: boolean) {
    this.id = id;
    this.stars = stars;
    this.completed = completed;
    this.unlocked = unlocked;
    this.lastPlayed = lastPlayed;
  }

  key(): string {
    return `${this.id}_${this.stars}_${this.completed}_${this.unlocked}_${this.lastPlayed}`;
  }
}

/** Level selection: a 3-column grid of level cards, like Android LevelSelectionFragment. */
@Entry
@Component
struct LevelSelectPage {
  @State cards: LevelCardInfo[] = [];
  @State totalStars: number = 0;
  @State completedCount: number = 0;
  private scroller: Scroller = new Scroller();
  private lastPlayed: number = 1;
  private firstShow: boolean = true;

  onPageShow(): void {
    this.refresh();
    if (this.firstShow) {
      this.firstShow = false;
      const index = Math.max(0, this.lastPlayed - 1);
      setTimeout(() => {
        this.scroller.scrollToIndex(index, false, ScrollAlign.CENTER);
      }, 50);
    }
  }

  private refresh(): void {
    const total = ProgressStore.getTotalStars();
    this.lastPlayed = ProgressStore.getLastPlayedLevel();
    const cards: LevelCardInfo[] = [];
    let completed = 0;
    for (let id = 1; id <= Constants.LEVEL_COUNT; id++) {
      const isCompleted = ProgressStore.isCompleted(id);
      if (isCompleted) {
        completed++;
      }
      cards.push(new LevelCardInfo(id, ProgressStore.getStars(id), isCompleted,
        ProgressStore.isUnlocked(id, total), id === this.lastPlayed));
    }
    this.totalStars = total;
    this.completedCount = completed;
    this.cards = cards;
  }

  private openLevel(card: LevelCardInfo): void {
    if (!card.unlocked) {
      const needed = ProgressStore.starsNeeded(card.id, this.totalStars);
      const message = AppContext.get().resourceManager.getStringByNameSync('level_locked', needed);
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
      return;
    }
    this.getUIContext().getRouter().pushUrl({ url: 'pages/GamePage', params: new GameParams(card.id) });
  }

  @Builder
  StarsRow(count: number) {
    Row({ space: 1 }) {
      ForEach(new Array<number>(count).fill(0), (_: number, index: number) => {
        Image($r('app.media.star')).width(14).height(14)
      }, (_: number, index: number) => `${index}`)
    }
    .height(14)
  }

  @Builder
  LevelCard(card: LevelCardInfo) {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 2 }) {
        if (card.completed) {
          if (card.stars > 0) {
            this.StarsRow(card.stars)
          } else {
            Text('✔').fontSize(14).fontColor('#4CAF50').height(14)
          }
        } else {
          Blank().height(14)
        }
        if (card.unlocked) {
          Text(`${card.id}`)
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .textShadow({ radius: 3, color: '#80000000', offsetX: 1, offsetY: 1 })
          if (card.completed) {
            Blank().height(16)
          } else {
            Text('▶').fontSize(14).fontColor(Color.White).height(16)
          }
        } else {
          Text('🔒').fontSize(28).height(36)
          Text(`${card.id}`).fontSize(11).fontColor(Color.White).height(16)
        }
      }
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .aspectRatio(1)
    .borderRadius(8)
    .border({
      width: card.lastPlayed ? 4 : 2,
      color: card.lastPlayed ? '#72FF56' : (card.completed ? '#FFD700' : (card.unlocked ? '#42A5F5' : '#A0A0A0'))
    })
    .linearGradient({
      angle: 135,
      colors: card.completed ? GOLD_GRADIENT : (card.unlocked ? BLUE_GRADIENT : LOCKED_GRADIENT)
    })
    .opacity(card.unlocked ? 1.0 : 0.8)
    .shadow(card.lastPlayed ? SHADOW_LAST_PLAYED : SHADOW_DEFAULT)
    .onClick(() => this.openLevel(card))
    .accessibilityText(`Level ${card.id}`)
  }

  build() {
    Column() {
      // Header: title, total stars and progress
      Column({ space: 6 }) {
        Row() {
          Text($r('app.string.level_selection_title'))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .layoutWeight(1)
          Image($r('app.media.star')).width(24).height(24)
          Text(`${this.totalStars}`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFD700')
            .margin({ left: 4 })
        }
        .width('100%')

        Progress({ value: this.completedCount, total: Constants.LEVEL_COUNT, type: ProgressType.Linear })
          .width('100%')
          .height(10)
          .color('#FFD700')
          .backgroundColor('#33000000')
          .style({ strokeWidth: 10 })
        Text($r('app.string.level_progress', this.completedCount, Constants.LEVEL_COUNT))
          .fontSize(13)
          .fontColor(Color.White)
      }
      .width('100%')
      .padding(12)
      .borderRadius(4)
      .linearGradient({ angle: 0, colors: HEADER_GRADIENT })
      .border({ width: 1, color: '#4CAF50' })

      Grid(this.scroller) {
        ForEach(this.cards, (card: LevelCardInfo) => {
          GridItem() {
            this.LevelCard(card)
          }
        }, (card: LevelCardInfo) => card.key())
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(10)
      .rowsGap(10)
      .padding({ top: 12, bottom: 12 })
      .layoutWeight(1)
      .width('100%')
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 12, right: 12, top: 8 })
    .border({ width: 3, color: '#FFD700' })
    .borderRadius(14)
    .linearGradient({ angle: 180, colors: SCREEN_GRADIENT })
  }
}
