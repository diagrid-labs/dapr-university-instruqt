// dapr-workflow-101 page 2 (task chaining): the four activities of JumpWorkflow
// and what each one passes on.
//
// Elements, with each name as it appears in the assignment and the demo
// (diagrid-labs/university-labs at 44ccac8, folder workflow/, Demo2-TaskChaining):
// - PlotCourseActivity, ChargeWarpCoreActivity, AlignNavArrayActivity,
//   EngageJumpActivity: the four calls in JumpWorkflow, in this order (all four
//   languages), full names as in the assignment table.
// - course: PlotCourseActivity returns it, ChargeWarpCoreActivity takes it.
// - warp factor: ChargeWarpCoreActivity returns it, AlignNavArrayActivity takes it.
// - aligned: AlignNavArrayActivity returns it (the nav array). The demo code
//   discards it: EngageJumpActivity takes the course and the warp factor, not
//   this. The arrow to step 4 is labelled "aligned" as the brief asks, and a
//   second arrow carries what step 4 really gets (assignment table, step 4).
// - The workflow's output is the result of the last activity; no arrow for it.
//
// Connections: PlotCourse -> ChargeWarpCore -> AlignNavArray -> EngageJump, and
// ChargeWarpCore -> EngageJump ("course + warp factor").
//
// Departures from the skill, on purpose:
// - Every label is TEXT (13), the column minimum; label() instead of note().
// - Boxes are 176 x 40 (FLOW.W is 172): full activity names at 13 units, kept
//   with their Activity suffix. Two across a 476-unit canvas, wrapped to two rows.
// - Canvas 476 wide for the 424 px lab column (not 16:9 at 1100+ units).
import { elbowArrow, arrow, box, label } from '../_engine/shapes.mjs';
import { FLOW } from '../_engine/flow.mjs';

const TEXT = 13;
const W = 476;
const M = 12;
const BOX_W = 176;
const BOX_H = 40;
const ROW1 = 32;
const ROW2 = 150;
const H = ROW2 + BOX_H / 2 + 20;
const LEFT = M + BOX_W / 2; // 100
const RIGHT = W - M - BOX_W / 2; // 376
const MID = (ROW1 + ROW2) / 2 - 10; // the horizontal run between the rows

const STEP = { ...FLOW.step, size: TEXT, w: BOX_W, h: BOX_H };
const A1 = { x: LEFT, y: ROW1, w: BOX_W, h: BOX_H };
const A2 = { x: RIGHT, y: ROW1, w: BOX_W, h: BOX_H };
const A3 = { x: LEFT, y: ROW2, w: BOX_W, h: BOX_H };
const A4 = { x: RIGHT, y: ROW2, w: BOX_W, h: BOX_H };
const GAP_X = (LEFT + RIGHT) / 2;
const OUT_X = RIGHT - 40; // where the warp factor leaves ChargeWarpCoreActivity
const IN_X = RIGHT + 40; // where course + warp factor leaves it for step 4

export default {
  width: W,
  height: H,
  title: 'The four activities of JumpWorkflow, chained',
  desc:
    'Four boxes in two rows: PlotCourseActivity, ChargeWarpCoreActivity, AlignNavArrayActivity '
    + 'and EngageJumpActivity. Arrows labelled course, warp factor and aligned join them in order. '
    + 'A second arrow, labelled course + warp factor, runs from ChargeWarpCoreActivity down to EngageJumpActivity.',

  build() {
    return [
      arrow({ from: A1, to: A2 }),
      label({ x: GAP_X, y: ROW1 - 14, text: 'course', size: TEXT }),
      elbowArrow({
        points: [[OUT_X, ROW1 + BOX_H / 2 + 2], [OUT_X, MID], [LEFT, MID], [LEFT, ROW2 - BOX_H / 2 - 2]],
      }),
      label({ x: GAP_X - 20, y: MID + 16, text: 'warp factor', size: TEXT }),
      arrow({ from: A3, to: A4 }),
      label({ x: GAP_X, y: ROW2 - 14, text: 'aligned', size: TEXT }),
      arrow({ from: [IN_X, ROW1 + BOX_H / 2 + 2], to: [IN_X, ROW2 - BOX_H / 2 - 2] }),
      label({ x: IN_X - 8, y: (ROW1 + ROW2) / 2 + 10, text: 'course +\nwarp factor', size: TEXT, anchor: 'end' }),

      box({ ...A1, label: 'PlotCourseActivity', ...STEP }),
      box({ ...A2, label: 'ChargeWarpCoreActivity', ...STEP }),
      box({ ...A3, label: 'AlignNavArrayActivity', ...STEP }),
      box({ ...A4, label: 'EngageJumpActivity', ...STEP }),
    ];
  },
};
