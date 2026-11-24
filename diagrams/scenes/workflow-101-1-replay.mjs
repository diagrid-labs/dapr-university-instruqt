// dapr-workflow-101 page 1 (durable execution): what the replay after the
// restart does with each of the five charge stages.
//
// Elements, with each name and number as it appears in the assignment and the
// demo (diagrid-labs/university-labs at 44ccac8, folder workflow/):
// - stage 1 to stage 5: the five calls of ChargeStageActivity. Five from
//   `Stages = 5` in dotnet/Demo1-DurableExecution/Engineering/ChargeWarpCoreWorkflow.cs,
//   `STAGES = 5` in python/.../engineering/workflow.py, java/.../ChargeWarpCoreWorkflow.java
//   and typescript/.../engineering/workflow.ts. Each stage sleeps 3 seconds in the
//   activity (Task.Delay 3 s, time.sleep(3), TimeUnit.SECONDS.sleep(3), sleep(3000)).
//   The labels follow the log line "charge stage <n>/5 complete".
// - crash: assignment section 3, Ctrl+C right after "charge stage 2/5 complete",
//   which "stops the app and its sidecar while stage 3 is running".
// - from history (stages 1 and 2), runs again (stage 3), first run (stages 4 and
//   5): assignment sections 4 and 5.
// - replay, from the top: section 5, "The workflow code itself ran again, from
//   the top" (the sidecar replays ChargeWarpCoreWorkflow).
//
// Connections: replay -> stage 1 -> stage 2 -> stage 3 -> stage 4 -> stage 5.
//
// The three states are told apart by their lane captions, not by colour alone.
// The two stored stages are also drawn in grey (C.caption on the navy tint):
// they do not run. The three that run take the house step teal.
//
// Departures from the skill, on purpose:
// - Every label, the lane captions included, is TEXT (13), the column minimum.
//   flow.mjs's note() is 12, so the remark "from the top" is a label() at TEXT.
// - Step boxes are 96 x 40 rather than FLOW.W x FLOW.H (172 x 46): three of
//   them have to fit across a 476-unit canvas, and "stage 3" is short.
// - Canvas 476 wide for the 424 px lab column (not 16:9 at 1100+ units).
import { C } from '../_engine/engine.mjs';
import { arrow, box, CAPTION_INSET, captionPad, captionReach, elbowArrow, label, node } from '../_engine/shapes.mjs';
import { icon } from '../_engine/icons.mjs';
import { FLOW, flowLane } from '../_engine/flow.mjs';

const TEXT = 13; // every label in the scene, as in workflow-101-1-architecture

const M = 12; // canvas margin
const BOX_W = 96;
const BOX_H = 40;
const PAD = FLOW.PAD; // a lane's inset round its boxes, sideways
const GAP_IN = 36; // between two boxes inside one lane
const GAP_LANE = 24; // between the two lanes of the top row
const GAP_ROW = 44; // between the two rows of lanes

// A lane is tall enough for the crash mark between its pill and its box; every
// lane takes the same height so the rows read as one grid. The box is centred
// in what the pill leaves.
const LANE_H = 120;
const REACH = captionReach();
const BOX_DY = (REACH + LANE_H) / 2; // box centre below the lane's top

// Measured with measure-labels (weight 600 at 13), plus captionPad at each end.
const pillW = (textW) => Math.ceil(textW + 2 * captionPad(TEXT));
const HISTORY_W = pillW(77);
const AGAIN_W = pillW(66);
const FIRST_W = pillW(50);

// The top lanes start one pill reach below the margin, so their pills keep the
// margin too.
const TOP = M + REACH;

// Top row: "from history" [stage 1, stage 2], then "runs again" [stage 3].
const L1 = { x: M, y: TOP, w: 2 * PAD + 2 * BOX_W + GAP_IN, h: LANE_H };
const L2 = { x: L1.x + L1.w + GAP_LANE, y: TOP, w: 2 * PAD + BOX_W, h: LANE_H };
const W = L2.x + L2.w + M;
const ROW1_Y = TOP + BOX_DY;
const S1 = { x: L1.x + PAD + BOX_W / 2, y: ROW1_Y, w: BOX_W, h: BOX_H };
const S2 = { x: S1.x + BOX_W + GAP_IN, y: ROW1_Y, w: BOX_W, h: BOX_H };
const S3 = { x: L2.x + PAD + BOX_W / 2, y: ROW1_Y, w: BOX_W, h: BOX_H };

// Bottom row: "first run" [stage 4, stage 5], right-aligned under the top row
// and as wide as the "from history" lane, so stage 5 sits under stage 3.
const L3 = { x: L2.x + L2.w - L1.w, y: TOP + LANE_H + GAP_ROW, w: L1.w, h: LANE_H };
const ROW2_Y = L3.y + BOX_DY;
const S5 = { x: S3.x, y: ROW2_Y, w: BOX_W, h: BOX_H };
const S4 = { x: S5.x - BOX_W - GAP_IN, y: ROW2_Y, w: BOX_W, h: BOX_H };
const H = L3.y + L3.h + M;

// The replay start, under stage 1, on the bottom row's line.
const START = { x: S1.x, y: ROW2_Y, r: FLOW.NODE_R };
const GAP_MID = TOP + LANE_H + GAP_ROW / 2; // the horizontal line between the rows

// The crash mark: a red flash and the word, centred together over stage 3, in
// the band between the lane's pill and the box.
const FLASH = 18;
const CRASH_TEXT_W = 36; // measured "crash"
const CRASH_GAP = 5;
const CRASH_Y = TOP + (REACH + (BOX_DY - BOX_H / 2)) / 2;
const CRASH_X0 = S3.x - (FLASH + CRASH_GAP + CRASH_TEXT_W) / 2;

const HISTORY = { stroke: C.caption, fill: C.navyFill, size: TEXT };
const RUNS = { ...FLOW.step, size: TEXT };

export default {
  width: W,
  height: H,
  title: 'What the replay after the restart does with each charge stage',
  desc:
    'Five boxes for the stages of ChargeWarpCoreWorkflow, in two rows. A green start circle '
    + 'named replay has an arrow labelled from the top up to stage 1. Stages 1 and 2 are grey, '
    + 'in a lane named from history. An arrow runs on to stage 3, in a lane named runs again, '
    + 'marked with a red flash and the word crash. An arrow drops to the second row, to '
    + 'stages 4 and 5 in a lane named first run.',

  build() {
    return [
      flowLane({ ...L1, caption: 'from history', captionW: HISTORY_W }),
      flowLane({ ...L2, caption: 'runs again', captionW: AGAIN_W }),
      // The pill sits on the right of the lane: the leg from stage 3 comes down
      // through the top border over stage 4. Inset by CAPTION_INSET, as region() does on the left.
      flowLane({ ...L3, caption: 'first run', captionW: FIRST_W, captionX: L3.x + L3.w - CAPTION_INSET - FIRST_W / 2 }),

      arrow({ from: START, to: S1 }),
      label({ x: S1.x + 12, y: GAP_MID, text: 'from the top', size: TEXT, anchor: 'start' }),
      arrow({ from: S1, to: S2 }),
      arrow({ from: S2, to: S3 }),
      elbowArrow({
        points: [[S3.x, S3.y + BOX_H / 2 + 2], [S3.x, GAP_MID], [S4.x, GAP_MID], [S4.x, S4.y - BOX_H / 2 - 2]],
      }),
      arrow({ from: S4, to: S5 }),

      node({ ...START, label: 'replay', ...FLOW.start, size: TEXT }),
      box({ ...S1, label: 'stage 1', ...HISTORY }),
      box({ ...S2, label: 'stage 2', ...HISTORY }),
      box({ ...S3, label: 'stage 3', ...RUNS }),
      box({ ...S4, label: 'stage 4', ...RUNS }),
      box({ ...S5, label: 'stage 5', ...RUNS }),

      icon({ name: 'fluent-flash', x: CRASH_X0 + FLASH / 2, y: CRASH_Y, size: FLASH, color: C.red, fit: 'ink' }),
      label({ x: CRASH_X0 + FLASH + CRASH_GAP, y: CRASH_Y, text: 'crash', size: TEXT, anchor: 'start' }),
    ];
  },
};
