export const add: (a: number, b: number, func: object) => number;
export const runTest: (testNo: number, func: object) => number;
export const runTests: (tests: Array<number>, cpu: number, ncopies: number, func: object) => number;
export const queryCpuCount: () => number;
export const clock: (coreidx: number) => number;