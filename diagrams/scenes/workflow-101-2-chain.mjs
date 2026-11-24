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
// - AlignNavArrayActivity's result is discarded by JumpWorkflow, so the arrow to
//   step 4 is plain (order only, no label). EngageJumpActivity gets the course
//   (from step 1) and the warp factor (from step 2); the workflow builds that
//   input itself, so it is a caption under the box, not an arrow.
// - The workflow's output is the result of the last activity; no arrow for it.
//
// Connections: PlotCourse -> ChargeWarpCore ("course") -> AlignNavArray
// ("warp factor") -> EngageJump (plain).
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
const CAPTION_GAP = 16; // box edge to caption centre, as for the arrow labels
const H = ROW2 + BOX_H / 2 + CAPTION_GAP + 20; // 20 units of canvas below the caption
const LEFT = M + BOX_W / 2; // 100
const RIGHT = W - M - BOX_W / 2; // 376
const MID = (ROW1 + ROW2) / 2 - 10; // the horizontal run between the rows

const STEP = { ...FLOW.step, size: TEXT, w: BOX_W, h: BOX_H };
const A1 = { x: LEFT, y: ROW1, w: BOX_W, h: BOX_H };
const A2 = { x: RIGHT, y: ROW1, w: BOX_W, h: BOX_H };
const A3 = { x: LEFT, y: ROW2, w: BOX_W, h: BOX_H };
const A4 = { x: RIGHT, y: ROW2, w: BOX_W, h: BOX_H };
const GAP_X = (LEFT + RIGHT) / 2;
const ARROW_GAP = 2; // arrows stop this far from a box edge, so heads do not touch it
// The warp factor arrow leaves the bottom of step 2 40 units left of its centre:
// inside the 176 wide box (half = 88) and well clear of the course arrow's head.
const WARP_EXIT_X = RIGHT - 40;

export default {
  width: W,
  height: H,
  title: 'The four activities of JumpWorkflow, chained',
  desc:
    'Four boxes in two rows: PlotCourseActivity, ChargeWarpCoreActivity, AlignNavArrayActivity '
    + 'and EngageJumpActivity. Arrows join them in order; the first two are labelled course and '
    + 'warp factor, the last has no label. A caption under EngageJumpActivity reads gets course + warp factor.',

  build() {
    return [
      arrow({ from: A1, to: A2 }),
      label({ x: GAP_X, y: ROW1 - 14, text: 'course', size: TEXT }),
      elbowArrow({
        points: [
          [WARP_EXIT_X, ROW1 + BOX_H / 2 + ARROW_GAP],
          [WARP_EXIT_X, MID],
          [LEFT, MID],
          [LEFT, ROW2 - BOX_H / 2 - ARROW_GAP],
        ],
      }),
      label({ x: GAP_X - 20, y: MID + 16, text: 'warp factor', size: TEXT }),
      arrow({ from: A3, to: A4 }),
      label({ x: RIGHT, y: ROW2 + BOX_H / 2 + CAPTION_GAP, text: 'gets course + warp factor', size: TEXT }),

      box({ ...A1, label: 'PlotCourseActivity', ...STEP }),
      box({ ...A2, label: 'ChargeWarpCoreActivity', ...STEP }),
      box({ ...A3, label: 'AlignNavArrayActivity', ...STEP }),
      box({ ...A4, label: 'EngageJumpActivity', ...STEP }),
    ];
  },
};
