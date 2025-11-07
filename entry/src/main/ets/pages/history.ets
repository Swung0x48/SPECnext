import { JSON, util } from '@kit.ArkTS';
import { fileIo as fs, ListFileOptions } from '@kit.CoreFileKit';
import { Font } from '@kit.ArkUI';

enum TestType {
  INTrate,
  FPrate,
  INTspeed,
  FPspeed,
  Other
}

enum Status {
  Skipped = 0,
  Pending,
  Initializing,
  Running,
  Message,
  Failed,
  Completed,
  Error,
  Idle,
}

interface benchmarkSaveType {
  name: string,
  type: TestType,
  status: Status,
  reftime: number,
  time: number,
  score: number,
  errmsg: string
}

interface benchHistoryType {
  benchmark: benchmarkSaveType[],
  date: string,
  message: string,
  coreSelect: string,
  nCopies: string
}

const readHistoryData = async (filename: string) => {
  const path = `${getContext().filesDir}/benchmark_history/${filename}`
  const file = await fs.open(path, fs.OpenMode.READ_ONLY)

  const stat = await fs.stat(path);
  const buf = new ArrayBuffer(stat.size);

  await fs.read(file.fd, buf);
  await fs.close(file.fd);

  const decoder = new util.TextDecoder('utf-8');
  const text = decoder.decode(new Uint8Array(buf));

  return JSON.parse(text) as benchHistoryType
}

const listBenchmarkDir = async (): Promise<string[]> => {
  try {
    const path = `${getContext().filesDir}/benchmark_history`
    const listFileOption: ListFileOptions = {
      recursion: false,
      listNum: 0,
    }
    return fs.listFile(path, listFileOption)
  }
  catch (err) {
    console.error(`HISTORY: Read Error: ${err}`)
    return []
  }
}

@Component
export struct history {
  @State barStyle: BarStyle = BarStyle.STANDARD;
  pageInfo: NavPathStack = new NavPathStack()
  @State benchmarkList: Array<benchHistoryType> = []
  @State bShowDetail: boolean = false
  @State currentShowBenchmark: benchHistoryType = {
    benchmark: [],
    message: '',
    date: '',
    coreSelect: '',
    nCopies: ''
  }

  @Builder
  modalDetail() {
    Scroll() {
      Column({ space: 12 }) {
        Column() {
          Text('Message')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_emphasize'))
          Text(this.currentShowBenchmark.message)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        Column() {
          Text('Tests')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_emphasize'))
          Column({ space: 4 }) {
            ForEach(this.currentShowBenchmark.benchmark, (item: benchmarkSaveType, index) => {
              Row() {
                Text(item.name)
                Text(`${item.score}`)
                  .fontWeight(FontWeight.Bold)
              }
              .justifyContent(FlexAlign.SpaceBetween)
              .width('100%')
              if (index != this.currentShowBenchmark.benchmark.length - 1) {
                Divider()
                  .lineCap(LineCapStyle.Round)
                  .strokeWidth(1)
              }
            })
          }
          .padding(12)
          .backgroundColor($r('sys.color.background_tertiary'))
          .borderRadius(24)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        Column() {
          Text('Core Selection')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_emphasize'))
          Text(this.currentShowBenchmark.coreSelect)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        Column() {
          Text('n Copies')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_emphasize'))
          Text(this.currentShowBenchmark.nCopies)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('calc(100% - 30vp)')
    }
    .nestedScroll({
      scrollForward: NestedScrollMode.PARENT_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST,
    })
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 8 }) {
          ForEach(this.benchmarkList, (item: benchHistoryType, index) => {
            Column() {
              Column() {
                Row({ space: 8 }) {
                  Text('Benchmark')
                    .fontWeight(FontWeight.Bold)
                  Text(item.date)
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
                Row({ space: 8 }) {
                  Text(`Selected ${item.benchmark.length} Tests`)
                    .fontWeight(FontWeight.Bold)
                  Scroll() {
                    Column() {
                      ForEach(item.benchmark, (bench_item: benchmarkSaveType, bench_index) => {
                        Text(bench_item.name)
                      })
                    }
                    .alignItems(HorizontalAlign.End)
                  }
                  .edgeEffect(EdgeEffect.Spring,{ alwaysEnabled:true })
                  .fadingEdge(true)
                  .scrollBar(BarState.Off)
                }
                .height(50)
                .width('100%')
                .alignItems(VerticalAlign.Top)
                .justifyContent(FlexAlign.SpaceBetween)
              }
              .padding('5%')
              Row() {
                Column() {
                  Text(item.coreSelect)
                    .fontSize(16)
                  Text('Core Selection')
                    .fontSize(12)
                    .fontColor($r('sys.color.font_secondary'))
                }
                .width('50%')
                Column() {
                  Text(item.nCopies)
                    .fontSize(16)
                  Text('n Copies')
                    .fontSize(12)
                    .fontColor($r('sys.color.font_secondary'))
                }
                .width('50%')
              }
              .padding('5%')
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .backgroundColor($r('sys.color.background_tertiary'))
            }
            .onClick(() => {
              this.currentShowBenchmark = item
              this.bShowDetail = true
            })
            .key(item.date)
            .width('90%')
            .borderRadius(24)
            .clip(true)
            .backgroundColor($r('sys.color.background_secondary'))
          })
        }
        .margin({ top: 12 })
      }
      .bindSheet($$this.bShowDetail, this.modalDetail(), {
        preferType: SheetType.BOTTOM,
        title: { title: 'Benchmark Detail', subtitle: this.currentShowBenchmark.date },
        detents: ['90%']
      })
      .width('100%')
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring,{ alwaysEnabled:true })
    }
    .onReady(async (context: NavDestinationContext) => {
      this.pageInfo = context.pathStack

      let benchmarkDirs = await listBenchmarkDir()

      const readPromises: Promise<benchHistoryType>[] = benchmarkDirs.map((dir: string): Promise<benchHistoryType> => readHistoryData(dir))

      let benchmarkDataList = await Promise.all(readPromises)

      benchmarkDataList.sort((a: benchHistoryType, b: benchHistoryType): number => {
        let date_a = new Date(a.date)
        let date_b = new Date(b.date)

        return date_b.getTime() - date_a.getTime()
      })

      this.benchmarkList = benchmarkDataList
    })
    .title(
      {
        main: 'Benchmark History',
        sub: 'SPECnext'
      },
      {
        backgroundBlurStyle: BlurStyle.COMPONENT_THICK,
        barStyle: this.barStyle,
      }
    )
  }
}

@Builder
export function historyBuilder(name: string, param: Object) {
  history()
}