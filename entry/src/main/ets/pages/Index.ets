import { hilog } from '@kit.PerformanceAnalysisKit';
import testNapi, { clock, queryCpuCount } from 'libentry.so';
import { fileIo as fs } from '@kit.CoreFileKit';
import common from '@ohos.app.ability.common';
import window from '@ohos.window';
import { zlib } from '@kit.BasicServicesKit';
import deviceInfo from '@ohos.deviceInfo';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { JSON } from '@kit.ArkTS';
import { systemLoad } from '@kit.BasicServicesKit';

async function resourceFile(resourcePath: string) {
  let uint8Array: Uint8Array = getContext()
    .resourceManager
    .getRawFileContentSync(resourcePath);
  let fileName = resourcePath.substring(resourcePath.lastIndexOf('/') + 1);
  // console.log("${tag} fileName:${fileName}");

  let filePath = getContext().filesDir + '/' + fileName;
  if (fs.accessSync(filePath)) {
    fs.unlinkSync(filePath)
  }
  let file: fs.File = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
  fs.writeSync(file.fd, uint8Array.buffer);
  fs.closeSync(file);
  console.log(`Resource file path: ${filePath}`);
  return filePath;
}

async function decompressBundle(bundleRelPath: string) {
  // let uint8Array: Uint8Array
  // try {
  //   uint8Array = getContext()
  //     .resourceManager
  //     .getRawFileContentSync(bundleRelPath)
  // }
  // catch (error) {
  //   throw new Error(error)
  // }
  const fileName = bundleRelPath.substring(bundleRelPath.lastIndexOf('/') + 1)

  const cwd = getContext().filesDir

  const destPath = cwd + "/refdata"

  const exists = fs.accessSync(destPath)
  if (exists) {
    fs.rmdirSync(destPath)
  }
  fs.mkdirSync(destPath)

  const bundlePath = cwd + '/' + fileName
  await zlib.decompressFile(bundlePath, destPath)
  await fs.listFile(destPath).then((filenames: Array<string>) => {
    console.info("listFile decompressBundle succeed");
    for (let i = 0; i < filenames.length; i++) {
      console.info("fileName: %s", destPath + '/' + filenames[i]);
    }
  })
}

const TEST_GLOBAL = -1

async function runTestList(testList: Array<TestItem>, cpu: number, ncopies: number, doSplit: boolean, func: Function) {
  // Show preflight message
  let msg =
    "Preflight check:\n" +
      `affinity = ${cpu}\n` +
      `copies = ${ncopies}\n` +
      `tests = [`

  for (let test of testList) {
    msg += (test.name + ", ")
  }
  msg += "]\n"

  func(Status.Message, TEST_GLOBAL, 0, msg)

  // Set up tests
  func(Status.Message, TEST_GLOBAL, 0, `Setting up tests...`)

  const cwd = getContext().filesDir
  const srcPath = cwd + "/refdata"

  try {
    const rundir = cwd + "/run";
    const exists = await fs.access(rundir)
    if (exists) {
      await fs.rmdir(rundir)
    }
    try {
      await fs.mkdir(rundir)
    } catch (err) {
      console.log(`${rundir} exists`)
    }

    // const srcExists = await fs.access(srcPath)
    // if (!srcExists)
    //   throw Error("src not exist")
  } catch (err) {
    func(Status.Message, TEST_GLOBAL, 0, `Setup run dir failed: ${err}`)
  }

  for (let i = 0; i < ncopies; ++i) {
    const curRunDir = `${cwd}/run/${i}`
    await fs.mkdir(curRunDir)
    for (let test of testList) {
      const localSrcPath = `${srcPath}/${test.name}`
      const localDstPath = curRunDir
      try {
        await fs.copyDir(localSrcPath, localDstPath, 1)
      } catch (err) {
        func(Status.Message, TEST_GLOBAL, 0, `Copy #${i}: ${test.name} failed: ${err}`)
        func(Status.Error, test.id, 0, `Copy #${i} prep failed: ${err}`)
        // return new Promise<number>((res, rej) => {
        //   rej(err)
        // })
      }
      func(Status.Message, TEST_GLOBAL, 0, `Setup Copy #${i}: ${test.name} completed.`)
    }

    // await fs.listFile(curRunDir + "/507.cactuBSSN_r").then((filenames: Array<string>) => {
    //   console.info(`ls ${curRunDir}/507.cactuBSSN_r`);
    //   for (let i = 0; i < filenames.length; i++) {
    //     console.info("fileName: %s",  `${filenames[i]}`);
    //   }
    // })
  }

  func(Status.Message, TEST_GLOBAL, 0, `Initiating tests...`)
  // Run tests
  return new Promise<number>((resolve, reject) => {
    let ret = testNapi.runTests(testList.map(test => test.id), cpu, ncopies, doSplit, func);
    if (ret == 0) {
      resolve(0);
    } else {
      reject(ret);
    }
  })
}

async function runTest(testNo: number, func: object) {
  return new Promise<number>((resolve, reject) => {
    let ret = testNapi.runTest(testNo, func);
    if (ret == 0) {
      resolve(0);
    } else {
      reject(ret);
    }
  })
}

enum TestType {
  INTrate,
  FPrate,
  INTspeed,
  FPspeed,
  Other
}

function testTypeToString(type: TestType) {
  switch (type) {
    case TestType.INTrate:
      return "INT(Rate)"
    case TestType.FPrate:
      return "FP(Rate)"
    case TestType.INTspeed:
      return "INT(Speed)"
    case TestType.FPspeed:
      return "FP(Speed)"
    case TestType.Other:
    default:
      return "Other"
  }
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

function statusToString(status: Status) {
  switch (status) {
    case Status.Skipped:
      return "Skipped";
    case Status.Pending:
      return "Pending";
    case Status.Initializing:
      return "Initializing";
    case Status.Running:
      return "Running";
    case Status.Pending:
      return "Pending";
    case Status.Failed:
      return "Failed";
    case Status.Completed:
      return "Completed";
    case Status.Failed:
      return "Failed";
    case Status.Error:
      return "Error";
  }
  return "";
}

@Observed
class TestItem {
  public id: number
  public name: string;
  public type: TestType;
  public checked: boolean;
  public status: Status;
  public reftime: number;
  public time: number;
  public score: number;
  public errmsg: string;

  constructor(name: string, type: TestType, checked: boolean, status: Status, reftime: number, time: number,
    score: number, errmsg: string) {
    this.id = parseInt(name.split('.')[0])
    this.name = name;
    this.type = type;
    this.checked = checked;
    this.status = status;
    this.reftime = reftime;
    this.time = time;
    this.score = score;
    this.errmsg = errmsg
  }
}

// Benchmark History
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

interface benchRunnningHistoryType {
  name: string,
  score: number,
  status: Status
}

const getFormattedTime = (): string => {
  const date = new Date()
  const year = date.getFullYear()
  const month = ("0" + (date.getMonth() + 1)).slice(-2)
  const day = ("0" + date.getDate()).slice(-2)
  const hours = ("0" + date.getHours()).slice(-2)
  const minutes = ("0" + date.getMinutes()).slice(-2)
  const seconds = ("0" + date.getSeconds()).slice(-2)
  return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`
}

const writeHistoryData = async (historyData: string, filename: string) => {
  const dirPath = `${getContext().filesDir}/benchmark_history`
  const path = `${getContext().filesDir}/benchmark_history/${filename}.json`
  try {
    fs.statSync(dirPath).isDirectory()
  } catch (err) {
    fs.mkdirSync(dirPath)
  }
  try {
    // console.log(`History: is Dic - ${fs.statSync(dirPath).isDirectory()}`)
    const file = await fs.open(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)

    await fs.write(file.fd, historyData)
    await fs.close(file.fd)
  } catch (err) {
    console.error('History: Saved Error' + err)
  }
}

const handleSaveData = async (tests: Array<TestItem>, benchMessage: string, core: string, ncopy: string) => {
  let benchList: benchmarkSaveType[] = []
  for (let i of tests) {
    if (i.checked) {
      benchList.push({
        name: i.name,
        type: i.type,
        status: i.status,
        reftime: i.reftime,
        time: i.time,
        score: i.score,
        errmsg: i.errmsg
      })
    }
  }
  let benchHistory: benchHistoryType = {
    benchmark: benchList,
    date: getFormattedTime(),
    message: benchMessage,
    coreSelect: core,
    nCopies: ncopy
  }

  writeHistoryData(JSON.stringify(benchHistory), String(Date.now()))
}

AppStorage.setOrCreate('nCopies', 1)
AppStorage.setOrCreate('debugMode', false)
AppStorage.setOrCreate('splitRun', false)

@Entry
@Component
struct Index {
  @State message: string = '';
  @State sz: number = 20;
  cpuCount: number = 0;
  @State cpuOptions: MenuElement[] = [];
  @State currentCpuSelection: number = -1;
  @StorageLink('nCopies') nCopies: number = 1;
  @StorageLink('debugMode') debugMode: boolean = false;
  @StorageLink('splitRun') splitRun: boolean = false;
  path: string = "";
  selectTextSize: number = 12
  @State refreshCount: number = 0;
  @State globalStatus: Status = Status.Idle;
  @State barStyle: BarStyle = BarStyle.STANDARD;
  @State bShowInitializeScreen: boolean = false
  @State bShowLoading: boolean = false
  @State nowSelection: string = 'All'
  @State initLog: string = ''
  @State initError: boolean = false
  @State currentRunning: string = 'None'
  categoryColor: ResourceStr = $r('sys.color.font_tertiary')
  dividerColor: ResourceStr = $r('sys.color.font_fourth')
  errorScroller: Scroller = new Scroller()
  runningStatusScroller: Scroller = new Scroller()
  pageInfo: NavPathStack = new NavPathStack()
  @State currentRunningHistory: Array<benchRunnningHistoryType> = []
  @State systemLoadLevel: string = ''

  @State menuItems: Array<NavigationMenuItem> = [
    {
      value: 'history',
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_counterclockwise_clock')),
      action: () => {
        this.pageInfo.pushPathByName('History', null)
      }
    },
    {
      value: 'setting',
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.gearshape')),
      action: () => {
        this.pageInfo.pushPathByName('Settings', null)
      }
    },
  ]

  onSystemLoadChange = (res: systemLoad.SystemLoadLevel) => {
    switch (res) {
      case systemLoad.SystemLoadLevel.LOW:
        this.systemLoadLevel = 'LOW'
        break
      case systemLoad.SystemLoadLevel.NORMAL:
        this.systemLoadLevel = 'NORMAL'
        break
      case systemLoad.SystemLoadLevel.MEDIUM:
        this.systemLoadLevel = 'MEDIUM'
        break
      case systemLoad.SystemLoadLevel.HIGH:
        this.systemLoadLevel = 'HIGH'
        break
      case systemLoad.SystemLoadLevel.OVERHEATED:
        this.systemLoadLevel = 'OVERHEATED'
        break
      case systemLoad.SystemLoadLevel.WARNING:
        this.systemLoadLevel = 'WARNING'
        break
      case systemLoad.SystemLoadLevel.EMERGENCY:
        this.systemLoadLevel = 'EMERGENCY'
        break
      case systemLoad.SystemLoadLevel.ESCAPE:
        this.systemLoadLevel = 'ESCAPE'
        break
    }
  }

  debugMenuOptions: MenuElement[] = [
    {
      value: 'Toggle Init Modal',
      action: () => this.bShowInitializeScreen = !this.bShowInitializeScreen
    },
    {
      value: 'Toggle Loading Modal',
      action: () => this.bShowLoading = !this.bShowLoading
    },
    {
      value: 'Set Global Status to IDLE',
      action: () => this.globalStatus = Status.Idle
    },
    {
      value: 'Set Global Status to ERROR',
      action: () => this.globalStatus = Status.Error
    },
    {
      value: 'Set Global Status to RUNNING',
      action: () => this.globalStatus = Status.Running
    },
    {
      value: 'Set Global Status to COMPETED',
      action: () => this.globalStatus = Status.Completed
    },
  ]

  benchTypeOptions: SelectOption[] = [
    {
      value: "All"
    },
    {
      value: "INT(Rate)"
    },
    {
      value: "FP(Rate)"
    },
    {
      value: "INT(Speed)"
    },
    {
      value: "FP(Speed)"
    },
    {
      value: "Other"
    },
  ]

  @Builder
  modalDecompressing() {
    Column({ space: 8 }) {
      Text('Initializing')
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 12 })
      LoadingProgress()
        .width('30%')
        .color(this.initError ? $r('sys.color.font_secondary') : $r('sys.color.warning'))
      Text(this.initLog)
        .fontSize(12)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  modalLoading() {
    Column() {
      Text(`SystemLoadLevel: ${this.systemLoadLevel.toString()}`)
        .fontWeight(FontWeight.Bold)

      Text('SPECnext Benchmark Running')
        .fontWeight(FontWeight.Bold)

      Text(this.currentRunning)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 12 })

      List({ scroller: this.runningStatusScroller }) {
        ForEach(this.currentRunningHistory, (item: benchRunnningHistoryType, index) => {
          ListItem() {
            Row() {
              Text(item.name)
              Text(`[${statusToString(item.status)}] ${item.score.toFixed(2)}pts`)
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
          }
        })
      }
      .scrollBar(BarState.Off)
      .width('90%')
      .height('20%')

      List({ scroller: this.errorScroller }) {
        ListItem() {
          Text(this.message)
            .fontColor($r('sys.color.font_tertiary'))
            .fontSize(12)
        }
      }
      .scrollBar(BarState.Off)
      .width('90%')
      .height('20%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  private context: common.BaseContext = getContext(this) as common.BaseContext
  @State testList: Array<TestItem> = [
    // INTrate
    new TestItem('500.perlbench_r', TestType.INTrate, false, Status.Skipped, 1592, -1, -1, ""),
    new TestItem('502.gcc_r', TestType.INTrate, false, Status.Skipped, 1416, -1, -1, ""),
    new TestItem('505.mcf_r', TestType.INTrate, false, Status.Skipped, 1616, -1, -1, ""),
    new TestItem('520.omnetpp_r', TestType.INTrate, false, Status.Skipped, 1312, -1, -1, ""),
    new TestItem('523.xalancbmk_r', TestType.INTrate, false, Status.Skipped, 1056, -1, -1, ""),
    new TestItem('525.x264_r', TestType.INTrate, false, Status.Skipped, 1751, -1, -1, ""),
    new TestItem('531.deepsjeng_r', TestType.INTrate, false, Status.Skipped, 1146, -1, -1, ""),
    new TestItem('541.leela_r', TestType.INTrate, false, Status.Skipped, 1656, -1, -1, ""),
    new TestItem('548.exchange2_r', TestType.INTrate, false, Status.Skipped, 2620, -1, -1, ""),
    new TestItem('557.xz_r', TestType.INTrate, false, Status.Skipped, 1080, -1, -1, ""),

    // FPrate
    new TestItem('503.bwaves_r', TestType.FPrate, false, Status.Skipped, 10028, -1, -1, ""),
    new TestItem('507.cactuBSSN_r', TestType.FPrate, false, Status.Skipped, 1266, -1, -1, ""),
    new TestItem('508.namd_r', TestType.FPrate, false, Status.Skipped, 950, -1, -1, ""),
    new TestItem('510.parest_r', TestType.FPrate, false, Status.Skipped, 2616, -1, -1, ""),
    new TestItem('511.povray_r', TestType.FPrate, false, Status.Skipped, 2335, -1, -1, ""),
    new TestItem('519.lbm_r', TestType.FPrate, false, Status.Skipped, 1054, -1, -1, ""),
    new TestItem('521.wrf_r', TestType.FPrate, false, Status.Skipped, 2240, -1, -1, ""),
    new TestItem('526.blender_r', TestType.FPrate, false, Status.Skipped, 1523, -1, -1, ""),
    new TestItem('527.cam4_r', TestType.FPrate, false, Status.Skipped, 1749, -1, -1, ""),
    new TestItem('538.imagick_r', TestType.FPrate, false, Status.Skipped, 2487, -1, -1, ""),
    new TestItem('544.nab_r', TestType.FPrate, false, Status.Skipped, 1683, -1, -1, ""),
    new TestItem('549.fotonik3d_r', TestType.FPrate, false, Status.Skipped, 3897, -1, -1, ""),
    new TestItem('554.roms_r', TestType.FPrate, false, Status.Skipped, 1103, -1, -1, ""),

    // INTspeed
    new TestItem('600.perlbench_s', TestType.INTspeed, false, Status.Skipped, 1774, -1, -1, ""),
    new TestItem('602.gcc_s', TestType.INTspeed, false, Status.Skipped, 3981, -1, -1, ""),
    new TestItem('605.mcf_s', TestType.INTspeed, false, Status.Skipped, 4721, -1, -1, ""),
    new TestItem('620.omnetpp_s', TestType.INTspeed, false, Status.Skipped, 1630, -1, -1, ""),
    new TestItem('623.xalancbmk_s', TestType.INTspeed, false, Status.Skipped, 1417, -1, -1, ""),
    new TestItem('625.x264_s', TestType.INTspeed, false, Status.Skipped, 1764, -1, -1, ""),
    new TestItem('631.deepsjeng_s', TestType.INTspeed, false, Status.Skipped, 1432, -1, -1, ""),
    new TestItem('641.leela_s', TestType.INTspeed, false, Status.Skipped, 1706, -1, -1, ""),
    new TestItem('657.xz_s', TestType.INTspeed, false, Status.Skipped, 6182, -1, -1, ""),

    // FPspeed
    new TestItem('619.lbm_s', TestType.FPspeed, false, Status.Skipped, 5238, -1, -1, ""),
    new TestItem('638.imagick_s', TestType.FPspeed, false, Status.Skipped, 14425, -1, -1, ""),
    new TestItem('644.nab_s', TestType.FPspeed, false, Status.Skipped, 17472, -1, -1, ""),

    // Other
    new TestItem('9992.latency2',     TestType.Other, false, Status.Skipped, 1,  -1, -1, ""),
    new TestItem('9993.cuprobe',      TestType.Other, false, Status.Skipped, 1,  -1, -1, ""),
    new TestItem('9994.stream',       TestType.Other, false, Status.Skipped, 1,  -1, -1, ""),
    new TestItem('9995.ffmpeg',       TestType.Other, false, Status.Skipped, 1,  -1, -1, ""),
    new TestItem('9996.p7zip',        TestType.Other, false, Status.Skipped, 1,  -1, -1, ""),
    new TestItem('9997.llama-bench',  TestType.Other, false, Status.Skipped, 1,  -1, -1, ""),
    new TestItem('9998.c2clat',       TestType.Other, false, Status.Skipped, 1,  -1, -1, ""),
    new TestItem('9999.vkpeak',       TestType.Other, false, Status.Skipped, 1,  -1, -1, ""),
  ];

  onStateChange = async (newStatus: Status, test: number, time: number, msg: string, timestamp: number) => {
    time = Math.max(time, 0.1)
    const TEST_GLOBAL = -1
    // this.message = message
    let dateStr = ''
    if (timestamp) {
      const dateNew = new Date(Math.floor(timestamp / 1000))
      const formatterCN = new Intl.DateTimeFormat("zh-CN", {
        timeZone: "Asia/Shanghai",
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
        hour12: false
      });
      dateStr = formatterCN.format(dateNew)
    }
    else {
      dateStr = 'Event Log'
    }

    if (test == TEST_GLOBAL) {
      if (newStatus != Status.Message) {
        this.globalStatus = newStatus
      }
      switch (newStatus) {
        case Status.Initializing:
          this.message += `\n[${dateStr}] `
          this.message += "Initializing..."
          return
        case Status.Message:
          this.message += `\n[${dateStr}] `
          this.message += msg
          return
        case Status.Error:
          this.message += `\n[${dateStr}] `
          this.message += "Failed with error: " + msg
          return
        case Status.Completed:
          this.message += `\n[${dateStr}] `
          this.message += "All tests completed."
          this.bShowLoading = false
          await handleSaveData(this.testList, this.message,
            `${(this.currentCpuSelection == -1) ? "Any" : this.cpuOptions[this.currentCpuSelection]?.value}`, `${this.nCopies}`)
          return
      }
      // if (newStatus == Status.Completed) {
      //   this.message = "All tests completed."
      //   return
      // }
    }

    let idx = this.testList.findIndex(e => e.id == test);
    if (newStatus != Status.Message)
      this.testList[idx].status = newStatus
    this.testList[idx].errmsg = msg

    switch (newStatus) {
      case Status.Initializing:
        this.message += `\n[${dateStr}] `
        this.message += "Setting up " + this.testList[idx].name + "..."
        break
      case Status.Running:
        this.message += `\n[${dateStr}] `
        this.message += "Running " + this.testList[idx].name + "..."
        this.currentRunning = `${this.testList[idx].name} ${this.testList[idx].errmsg}`
        break
      case Status.Completed:
        this.message += `\n[${dateStr}] `
        this.testList[idx].time = time
        this.testList[idx].score = this.testList[idx].reftime / time
        this.message += this.testList[idx].name + " completed, elapsed " +
        this.testList[idx].time.toFixed(2) + "s, scored " +
        (this.testList[idx].reftime / time).toFixed(2) + "pts."

        this.currentRunningHistory.push({
          name: this.testList[idx].name,
          score: this.testList[idx].score,
          status: newStatus
        })
        break
      case Status.Error:
        this.message += `\n[${dateStr}] `
        this.message += this.testList[idx].name + " failed with: " + msg

        this.currentRunningHistory.push({
          name: this.testList[idx].name,
          score: this.testList[idx].score,
          status: newStatus
        })
        break
      case Status.Idle:
        this.message += `\n[${dateStr}] `
        this.message += "Idle"
        break
      case Status.Message:
        this.message += `\n[${dateStr}] [${this.testList[idx].name}] `
        this.message += msg
        break
      default:
        this.message += `\n[${dateStr}] `
        this.message += "Unknown"
        break
    }

    this.errorScroller.scrollEdge(Edge.Bottom)
    this.runningStatusScroller.scrollEdge(Edge.Bottom)
    // this.message = "state: " + status + ", " + test.toString() + ", msg: " + message
  }

  build() {
    Navigation(this.pageInfo) {
      Stack() {
        Row() {
          Column() {
            if (this.debugMode === true) {
              Row() {
                Text('DEBUG MODE')
                  .fontColor('#FFFFFF')
              }
              .bindMenu(this.debugMenuOptions)
              .alignItems(VerticalAlign.Center)
              .justifyContent(FlexAlign.Center)
              .backgroundColor($r('sys.color.background_emphasize'))
              .width('100%')
              .padding(4)
            }
            // Header Checkbox
            Row({ space: 8 }) {
              Select(this.benchTypeOptions)
                .value(this.nowSelection)
                .width('calc(100% - 144vp)')
                .onSelect((index, value) => {
                  this.nowSelection = value
                })
              // Remove All Selections
              Button() {
                Row() {
                  SymbolGlyph($r('sys.symbol.trash'))
                    .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
                    .fontColor([$r('sys.color.alert')])
                }
                .alignItems(VerticalAlign.Center)
                .justifyContent(FlexAlign.Center)
                .width(40)
                .height(40)
              }
              .role(ButtonRole.ERROR)
              .buttonStyle(ButtonStyleMode.NORMAL)
              .onClick(() => {
                for (let i of this.testList) {
                  i.checked = false
                }
              })

              // Remove Current Type Selection
              Button() {
                Row() {
                  SymbolGlyph($r('sys.symbol.circle_dashed'))
                    .renderingStrategy(SymbolRenderingStrategy.SINGLE)
                    .fontColor([$r('sys.color.warning')])
                }
                .alignItems(VerticalAlign.Center)
                .justifyContent(FlexAlign.Center)
                .width(40)
                .height(40)
              }
              .buttonStyle(ButtonStyleMode.NORMAL)
              .onClick(() => {
                for (let i of this.testList) {
                  if (this.nowSelection === 'All') {
                    i.checked = false
                  } else if (testTypeToString(i.type) === this.nowSelection) {
                    i.checked = false
                  }
                }
              })

              // Select All Current Type
              Button() {
                Row() {
                  SymbolGlyph($r('sys.symbol.checkmark_circle'))
                    .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
                    .fontColor([$r('sys.color.icon_emphasize'), $r('sys.color.icon_sub_emphasize')])
                }
                .alignItems(VerticalAlign.Center)
                .justifyContent(FlexAlign.Center)
                .width(40)
                .height(40)
              }
              .buttonStyle(ButtonStyleMode.NORMAL)
              .onClick(() => {
                for (let i of this.testList) {
                  if (this.nowSelection === 'All' || testTypeToString(i.type) === this.nowSelection) {
                    i.checked = true
                  }
                }
              })
            }
            .width('100%')
            .padding(12)
            .justifyContent(FlexAlign.SpaceBetween)

            // Test scroll view
            Scroll() {
              Column() {
                if (this.nowSelection === 'All' || this.nowSelection === 'INT(Rate)') {
                  // INTrate tests
                  Text(testTypeToString(TestType.INTrate))
                    .fontSize(15)
                    .fontColor(this.categoryColor)
                    .width('100%')
                    .padding('2%')
                    .textAlign(TextAlign.Start)
                  Divider().strokeWidth(2).color(this.dividerColor)
                  ForEach(this.testList, (item: TestItem) => {
                    if (item.type == TestType.INTrate) {
                      TestRow({ globalStatus: this.globalStatus, test: item })
                    }
                  })
                }

                if (this.nowSelection === 'All' || this.nowSelection === 'FP(Rate)') {
                  // FPrate tests
                  Text(testTypeToString(TestType.FPrate))
                    .fontSize(15)
                    .fontColor(this.categoryColor)
                    .width('100%')
                    .padding('2%')
                    .textAlign(TextAlign.Start)
                  Divider().strokeWidth(2).color(this.dividerColor)
                  ForEach(this.testList, (item: TestItem) => {
                    if (item.type == TestType.FPrate) {
                      TestRow({ globalStatus: this.globalStatus, test: item })
                    }
                  })
                }

                if (this.nowSelection === 'All' || this.nowSelection === 'INT(Speed)') {
                  // INTspeed tests
                  Text(testTypeToString(TestType.INTspeed))
                    .fontSize(15)
                    .fontColor(this.categoryColor)
                    .width('100%')
                    .padding('2%')
                    .textAlign(TextAlign.Start)
                  Divider().strokeWidth(2).color(this.dividerColor)
                  ForEach(this.testList, (item: TestItem) => {
                    if (item.type == TestType.INTspeed) {
                      TestRow({ globalStatus: this.globalStatus, test: item })
                    }
                  })
                }

                if (this.nowSelection === 'All' || this.nowSelection === 'FP(Speed)') {
                  // FPspeed tests
                  Text(testTypeToString(TestType.FPspeed))
                    .fontSize(15)
                    .fontColor(this.categoryColor)
                    .width('100%')
                    .padding('2%')
                    .textAlign(TextAlign.Start)
                  Divider().strokeWidth(2).color(this.dividerColor)
                  ForEach(this.testList, (item: TestItem) => {
                    if (item.type == TestType.FPspeed) {
                      TestRow({ globalStatus: this.globalStatus, test: item })
                    }
                  })

                }

                if (this.nowSelection === 'All' || this.nowSelection === 'Other') {
                  // Other tests
                  Text(testTypeToString(TestType.Other))
                    .fontSize(15)
                    .fontColor(this.categoryColor)
                    .width('100%')
                    .padding('2%')
                    .textAlign(TextAlign.Start)
                  Divider().strokeWidth(2).color(this.dividerColor)
                  ForEach(this.testList, (item: TestItem) => {
                    if (item.type == TestType.Other) {
                      TestRow({ globalStatus: this.globalStatus, test: item })
                    }
                  })
                }
              }
              .padding({ bottom: '100%' })
            }
            .scrollable(ScrollDirection.Vertical)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .fadingEdge(true)
            .padding({ bottom: 100 })
          }
        }
        .width('100%')
        .height('100%')
        .onAppear(async () => {
          systemLoad.getLevel().then((res: systemLoad.SystemLoadLevel) => {
            this.onSystemLoadChange(res)
          })

          systemLoad.on('systemLoadChange', this.onSystemLoadChange);

          this.cpuCount = queryCpuCount()

          for (let i = 0; i < this.cpuCount; ++i) {
            const freqHz = clock(i)
            const freqMHz = freqHz / 1e3 / 1e3
            this.cpuOptions.push({
              value: `${i.toString()} - ${freqMHz.toFixed(2)}MHz`,
              action: () => {
                this.currentCpuSelection = i
              }
            })
            console.log(`core ${i} freq est. ${freqHz}Hz => ${freqMHz.toFixed(2)}MHz`)
          }
          this.cpuOptions.push({
            value: `Any`,
            action: () => {
              this.currentCpuSelection = -1
            }
          })

          this.globalStatus = Status.Pending

          this.globalStatus = Status.Idle

          this.bShowInitializeScreen = true
          this.initLog = `Start Decompressing Bundle`

          resourceFile('spec_payload.zip')

          decompressBundle('spec_payload.zip').then(() => {
            this.bShowInitializeScreen = false
            this.globalStatus = Status.Idle
          })
            .catch((e: Error) => {
              this.initLog = `Decompress Error: ${e}`
            })

          // Keep screen always on
          let windowClass = await window.getLastWindow(this.context)
          await windowClass.setWindowKeepScreenOn(true)
        })

        Column() {
          // TextArea({ text: this.message })
          //   .height('20%')
          //   .padding('28px')
          //   .fontSize(16)
          Row() {
            Row() {
              Text('Core Selection: ')
                .fontWeight(FontWeight.Bold)
              Text(`${(this.currentCpuSelection == -1) ? "Any" : this.cpuOptions[this.currentCpuSelection]?.value}`)
            }

            Row() {
              Text('n Copies: ')
                .fontWeight(FontWeight.Bold)
              Text(String(this.nCopies))
            }

            // Select(this.cpuOptions)
            //   .value(this.currentCpuSelectionText)
            //   .enabled(this.globalStatus == Status.Idle)
            //   .onSelect((index: number, text: string) => {
            //     if (index >= this.cpuCount)
            //       this.currentCpuSelection = -1;
            //     this.currentCpuSelection = index;
            //     this.currentCpuSelectionText = text
            //   })
            //   .width('100%')
          }
          .padding(12)
          .justifyContent(FlexAlign.SpaceBetween)
          .width('100%')

          Row({ space: 8 }) {
            Button() {
              Row() {
                Image($r('app.media.ic_public_chip'))
                  .width(24)
                  .height(24)
              }
              .alignItems(VerticalAlign.Center)
              .justifyContent(FlexAlign.Center)
              .width(40)
              .height(40)
              .bindMenu(this.cpuOptions)
            }
            .enabled(this.globalStatus === Status.Idle)

            if (this.globalStatus === Status.Idle) {
              Button("Run")
                .fontSize(this.sz)
                .fontWeight(FontWeight.Bold)
                .onClick(async () => {
                  this.globalStatus = Status.Running;
                  this.bShowLoading = true

                  this.testList.forEach(item => {
                    if (item.checked) {
                      item.status = Status.Pending
                    } else {
                      item.status = Status.Skipped
                    }
                  })

                  let testsToRun = this.testList.filter(item => item.checked)
                  // .map(item => item.id)
                  runTestList(testsToRun, this.currentCpuSelection, this.nCopies, this.splitRun, this.onStateChange)
                    .then((res) => {
                      this.globalStatus = Status.Completed
                    })
                    .catch(() => {
                      this.bShowLoading = false
                      this.globalStatus = Status.Completed
                    })
                })
                .width('calc(100% - 48vp)')
                .enabled(this.globalStatus == Status.Idle)
            } else if (this.globalStatus == Status.Running || this.globalStatus == Status.Initializing) {
              Button("Show Running Status")
                .fontSize(this.sz)
                .fontWeight(FontWeight.Bold)
                .onClick(async () => {
                  this.bShowLoading = true
                })
                .width('calc(100% - 48vp)')
                .enabled(!this.bShowLoading)
            } else {
              Button("Reset")
                .fontSize(this.sz)
                .fontWeight(FontWeight.Bold)
                .onClick(async () => {
                  // await handleSaveData(this.testList, this.message,
                  //   `${(this.currentCpuSelection == -1) ? "Any" : this.cpuOptions[this.currentCpuSelection]?.value}`, `${this.nCopies}`)
                  this.globalStatus = Status.Idle
                  this.message = ''
                  this.bShowLoading = false
                  this.currentRunning = 'None'
                  this.currentRunningHistory = []
                })
                .width('calc(100% - 48vp)')
                .enabled(this.globalStatus == Status.Completed)
            }
          }
        }
        .justifyContent(FlexAlign.SpaceBetween)
        .width('100%')
        .bindContentCover($$this.bShowLoading, this.modalLoading(), {
          backgroundColor: $r('app.color.modal_transparent_background'),
          modalTransition: ModalTransition.NONE
        })
        .borderRadius({
          topLeft: 20,
          topRight: 20
        })
        .backgroundColor($r('sys.color.comp_background_primary'))
        // .backdropBlur(24)
        .padding('24px')
      }
      .bindContentCover($$this.bShowInitializeScreen, this.modalDecompressing, {
        backgroundColor: $r('app.color.modal_transparent_background'),
        modalTransition: ModalTransition.NONE
      })
      .alignContent(Alignment.Bottom)
    }
    .menus(this.menuItems)
    .hideToolBar(true)
    .mode(NavigationMode.Stack)
    .titleMode(NavigationTitleMode.Free)
    .title(
      {
        main: 'SPECnext',
        sub: `${deviceInfo.marketName} / Harmony OS ${deviceInfo.majorVersion}`
      },
      {
        backgroundBlurStyle: BlurStyle.COMPONENT_THICK,
        barStyle: this.barStyle,
      }
    )
  }
}


@Component
struct TestRow {
  @Prop globalStatus: Status;
  @ObjectLink test: TestItem;
  @State rowColor: ResourceStr = $r('sys.color.background_primary')
  statusText = () => {
    switch (this.test.status) {
      case Status.Pending:
        return "Pending";
      case Status.Initializing:
        return "Initializing...";
      case Status.Running:
        return `Running...${this.test.errmsg}`;
      case Status.Completed:
        if (this.test.type != TestType.Other) {
          return `${this.test.reftime.toFixed(0)} / ${this.test.time.toFixed(2)} = ${this.test.score.toFixed(2)}pts`
        } else {
          return "Completed"
        }
      case Status.Error:
        return `Error: ${this.test.errmsg}`
      case Status.Skipped:
        return "Skipped";
      default:
        return "---";
    }
  }
  statusFontColor = () => {
    if (this.globalStatus == Status.Idle) {
      return $r('sys.color.font_primary');
    }
    switch (this.test.status) {
      case Status.Skipped:
        return $r('sys.color.font_tertiary');
      default:
        return $r('sys.color.font_primary');
    }
  }
  statusRowBackground = () => {
    if (this.globalStatus == Status.Idle) {
      return this.test.checked ? $r('app.color.history_item_background') : $r('sys.color.background_primary');
    }
    return (this.test.status == Status.Initializing || this.test.status == Status.Running) ? $r('sys.color.background_secondary') :
      $r('sys.color.background_primary');
  }

  build() {
    Row() {
      Text(this.test.name)
        .fontSize(18)
        .fontColor(this.statusFontColor())
      if (this.globalStatus != Status.Idle) {
        Text(this.statusText())
          .fontSize(12)
          .fontColor(this.statusFontColor())
      }

      if (this.globalStatus == Status.Idle) {
        Checkbox({ group: testTypeToString(this.test.type) })
          .select($$this.test.checked)
      }
    }
    .onClick(() => {
      this.test.checked = !this.test.checked
    })
    .backgroundColor(this.statusRowBackground())
    .animation({
      duration: 100
    })
    .padding('2%')
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)

  }
}
