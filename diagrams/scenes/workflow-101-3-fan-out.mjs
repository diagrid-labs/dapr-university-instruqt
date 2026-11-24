// dapr-workflow-101 page 3 (fan-out/fan-in): RouteScanWorkflow starts five
// ScanSectorActivity calls at once and joins them into routeRisk and verdict.
//
// Elements, with each name and number as it appears in the assignment and the demo
// (diagrid-labs/university-labs at 44ccac8, folder workflow/, Demo3-FanOutFanIn):
// - RouteScanWorkflow: the workflow (dotnet RouteScanWorkflow.cs, python workflow.py,
//   java RouteScanWorkflow.java, typescript workflow.ts all name it that way).
// - alpha, beta, gamma, delta, epsilon: the five arrays, in this order in all four
//   languages; each is the input of one ScanSectorActivity call (the lane caption).
// - Hazard 12, 7, 31, 4, 18: the fixed scores in ScanSectorActivity (python
//   scan_sector_activity, typescript hazards; the assignment table). Each scan returns
//   its score ({array, hazard}), so the arrows into the join carry them.
// - Join step: after Task.WhenAll / when_all / allOf / whenAll the workflow computes
//   routeRisk = max hazard and verdict = CLEAR when routeRisk < 50, else HAZARDOUS
//   (same expression in all four languages). Drawn as a tall box named routeRisk and
//   verdict, with a caption "max hazard" and "CLEAR below 50".
// - The workflow input (jump) is ignored by the demo, so no arrow for it.
//
// Connections: RouteScanWorkflow -> each of the five scans -> join.
// Horizontal arrows: the left and right boxes are as tall as the stack of scans.
//
// Departures from the skill, on purpose:
// - Every label is TEXT (13), the column minimum; label() instead of note().
// - The five scan boxes are 100 x 30 (shorter than FLOW.H); three columns across.
//   The activity name is a label over the stack rather than a lane (a lane's pill
//   for "ScanSectorActivity" is wider than the column of boxes).
// - Canvas 476 wide for the 424 px lab column (not 16:9 at 1100+ units).
import { arrow, box, label } from '../_engine/shapes.mjs';
import { FLOW } from '../_engine/flow.mjs';

const TEXT = 13;
const W = 476;
const M = 12;
const SCAN_W = 100;
const SCAN_H = 30;
const SCAN_GAP = 10;
const SIDE_W = 100; // RouteScanWorkflow and the join box
const TOP = 40; // room for the ScanSectorActivity label above the stack
const N = 5;
const STACK_H = N * SCAN_H + (N - 1) * SCAN_GAP; // 190
const BOTTOM = TOP + STACK_H;
const CAPTION_GAP = 22; // box bottom to the first caption line centre
const H = BOTTOM + CAPTION_GAP + 30; // two caption lines and the margin
const MID_Y = TOP + STACK_H / 2;

const LEFT = { x: M + SIDE_W / 2, y: MID_Y, w: SIDE_W, h: STACK_H };
const RIGHT = { x: W - M - SIDE_W / 2, y: MID_Y, w: SIDE_W, h: STACK_H };
const MIDX = W / 2;
const GAP = 2; // arrows stop this far from a box edge

// [array, hazard] in the order of the demo's loop.
const SCANS = [['alpha', 12], ['beta', 7], ['gamma', 31], ['delta', 4], ['epsilon', 18]];
const rowY = (i) => TOP + SCAN_H / 2 + i * (SCAN_H + SCAN_GAP);

const STEP = { ...FLOW.step, size: TEXT };

export default {
  width: W,
  height: H,
  title: 'RouteScanWorkflow fans out to five scans and joins them',
  desc:
    'Three columns. RouteScanWorkflow on the left has five arrows to five boxes under the heading '
    + 'ScanSectorActivity: alpha 12, beta 7, gamma 31, delta 4 and epsilon 18. Five arrows join them in a box '
    + 'named routeRisk and verdict, captioned max hazard and CLEAR below 50.',

  build() {
    const out = [];
    SCANS.forEach((_, i) => {
      const y = rowY(i);
      const mid = { x: MIDX, y, w: SCAN_W, h: SCAN_H };
      out.push(arrow({ from: [LEFT.x + SIDE_W / 2 + GAP, y], to: mid }));
      out.push(arrow({ from: mid, to: [RIGHT.x - SIDE_W / 2 - GAP, y] }));
    });
    out.push(label({ x: MIDX, y: TOP - 20, text: 'ScanSectorActivity', size: TEXT }));
    SCANS.forEach(([array, hazard], i) => {
      out.push(box({ x: MIDX, y: rowY(i), w: SCAN_W, h: SCAN_H, label: `${array} \u00b7 ${hazard}`, ...STEP }));
    });
    out.push(box({ ...LEFT, label: 'RouteScan\nWorkflow', ...STEP }));
    out.push(box({ ...RIGHT, label: 'routeRisk\nverdict', ...STEP }));
    out.push(label({ x: RIGHT.x, y: BOTTOM + CAPTION_GAP, text: 'max hazard\nCLEAR below 50', size: TEXT }));
    return out;
  },
};
