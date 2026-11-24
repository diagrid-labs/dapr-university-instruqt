// dapr-workflow-aspire page 4 (run and inspect), section 5 "What happened":
// the learner stops engineering while jump-002 waits on its timer, starts it
// again, and the workflow carries on from its last completed step.
//
// Elements, with each name as it appears on the page and in the workflow code
// (page 2's DiagnosticsWorkflow.cs):
// - 3 diagnoses: the three DiagnoseSubsystemActivity calls (WarpCore,
//   LifeSupport, Shields), which completed before the stop.
// - 15 s timer: `context.CreateTimer(TimeSpan.FromSeconds(15))`, which the
//   workflow waits on when the app stops (section 3). Gold: a step that waits.
// - prioritize: PrioritizeDiagnosticsActivity, the first step that runs after
//   the restart (section 4).
// - stop: the learner's Stop on the engineering row (section 3), a red flash
//   over the timer.
// - dapr_redis: the Redis container behind the statestore component, where
//   the sidecar saves the history (section 5). Not part of the workflow, so a
//   gold data store with the Redis mark under the steps.
// - Lanes: before the stop, app stopped, after the restart (sections 3 and 4).
//
// Connections: 3 diagnoses -> 15 s timer -> prioritize (the workflow's order).
// 3 diagnoses -> dapr_redis, labelled "saved": the results are in the history
// before the stop. dapr_redis -> prioritize, labelled "replay": after the
// restart the workflow replays from the history and carries on.
//
// Departures from the skill, on purpose: canvas 490 wide for the 424 px lab
// column; every label, the lane captions included, is TEXT (13), the column
// minimum; step boxes are 112 x 40 rather than FLOW.W x FLOW.H so three lanes
// fit across.
import { C } from '../_engine/engine.mjs';
import { arrow, box, captionPad, captionReach, cylinder, elbowArrow, group, label } from '../_engine/shapes.mjs';
import { icon } from '../_engine/icons.mjs';
import { FLOW, flowLane } from '../_engine/flow.mjs';

const TEXT = 13;
const W = 490;
const M = 12;
const BOX_W = 112;
const BOX_H = 40;
const GAP_LANE = 16;
const LANE_W = (W - 2 * M - 2 * GAP_LANE) / 3;
const LANE_H = 112;
const REACH = captionReach();
const TOP = M + REACH;
const BOX_DY = (REACH + LANE_H) / 2 + 6; // box centre below the lane's top, under the stop mark
const ROW_Y = TOP + BOX_DY;
const G = 2; // arrows stop this far from a shape's edge

// Measured with measure-labels (weight 600 at 13), plus captionPad at each end.
const pillW = (textW) => Math.ceil(textW + 2 * captionPad(TEXT));
const BEFORE_W = pillW(96);
const STOPPED_W = pillW(79);
const AFTER_W = pillW(98);

const laneX = (i) => M + i * (LANE_W + GAP_LANE);
const colX = (i) => laneX(i) + LANE_W / 2;

// The stop mark: a red flash and the word, centred together over the timer.
const FLASH = 18;
const STOP_TEXT_W = 28; // "stop" at 13 (measured 27.6)
const STOP_GAP = 5;
const STOP_Y = TOP + (REACH + (BOX_DY - BOX_H / 2)) / 2;
const STOP_X0 = colX(1) - (FLASH + STOP_GAP + STOP_TEXT_W) / 2;

// dapr_redis under the timer.
const STORE_W = 84;
const STORE_H = STORE_W / 1.2;
const STORE_X = colX(1);
const STORE_Y = TOP + LANE_H + 26 + STORE_H / 2;
const MARK = 30;
const NAME_DY = 14;
const H = Math.ceil(STORE_Y + STORE_H / 2 + NAME_DY + 8 + M);

const WORD_DY = 12; // a label rides this far above its arrow

if (W / H < 1.33) throw new Error(`workflow-aspire-4-resume: ${W} x ${H} is narrower than 1.33`);

export default {
  width: W,
  height: H,
  title: 'After the stop, the workflow replays its history and carries on',
  desc:
    'Three lanes side by side. In the lane named before the stop, a teal box 3 diagnoses. In the '
    + 'lane named app stopped, a gold box 15 s timer under a red flash and the word stop. In the '
    + 'lane named after the restart, a teal box prioritize. Arrows run from box to box. Below the '
    + 'timer is a gold data store with the Redis mark named dapr_redis. An arrow labelled saved '
    + 'runs down from 3 diagnoses to dapr_redis, and an arrow labelled replay runs from dapr_redis '
    + 'up to prioritize.',

  build() {
    const left = colX(0);
    const right = colX(2);
    const storeL = STORE_X - STORE_W / 2;
    const storeR = STORE_X + STORE_W / 2;
    const step = { ...FLOW.step, size: TEXT };
    return [
      flowLane({ x: laneX(0), y: TOP, w: LANE_W, h: LANE_H, caption: 'before the stop', captionW: BEFORE_W }),
      flowLane({ x: laneX(1), y: TOP, w: LANE_W, h: LANE_H, caption: 'app stopped', captionW: STOPPED_W }),
      flowLane({ x: laneX(2), y: TOP, w: LANE_W, h: LANE_H, caption: 'after the restart', captionW: AFTER_W }),

      arrow({ from: [left + BOX_W / 2 + G, ROW_Y], to: [colX(1) - BOX_W / 2 - G, ROW_Y] }),
      arrow({ from: [colX(1) + BOX_W / 2 + G, ROW_Y], to: [right - BOX_W / 2 - G, ROW_Y] }),

      elbowArrow({ points: [[left, ROW_Y + BOX_H / 2 + G], [left, STORE_Y], [storeL - G, STORE_Y]] }),
      label({ x: (left + storeL) / 2 + 10, y: STORE_Y - WORD_DY, text: 'saved', size: TEXT }),
      elbowArrow({ points: [[storeR + G, STORE_Y], [right, STORE_Y], [right, ROW_Y + BOX_H / 2 + G]] }),
      label({ x: (storeR + right) / 2 - 10, y: STORE_Y - WORD_DY, text: 'replay', size: TEXT }),

      box({ x: left, y: ROW_Y, w: BOX_W, h: BOX_H, label: '3 diagnoses', ...step }),
      box({ x: colX(1), y: ROW_Y, w: BOX_W, h: BOX_H, label: '15 s timer', ...FLOW.wait, size: TEXT }),
      box({ x: right, y: ROW_Y, w: BOX_W, h: BOX_H, label: 'prioritize', ...step }),

      icon({ name: 'fluent-flash', x: STOP_X0 + FLASH / 2, y: STOP_Y, size: FLASH, color: C.red, fit: 'ink' }),
      label({ x: STOP_X0 + FLASH + STOP_GAP, y: STOP_Y, text: 'stop', size: TEXT, anchor: 'start' }),

      group([
        cylinder({ x: STORE_X, y: STORE_Y, w: STORE_W }),
        icon({ name: 'redis', x: STORE_X, y: STORE_Y, size: MARK, color: C.appInk, fit: 'ink' }),
        label({ x: STORE_X, y: STORE_Y + STORE_H / 2 + NAME_DY, text: 'dapr_redis', size: TEXT }),
      ]),
    ];
  },
};
