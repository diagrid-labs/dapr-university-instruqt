// dapr-workflow-101 page 4 (monitor): one run of CoreStabilityWorkflow. It reads the
// core temperature, stops when it is stable, and otherwise waits on a durable timer
// and continues as new with the next check.
//
// Elements, with each name and number as it appears in the assignment and the demo
// (diagrid-labs/university-labs at 44ccac8, folder workflow/, Demo4-Monitor):
// - CoreStabilityWorkflow: the workflow (dotnet CoreStabilityWorkflow.cs, python
//   workflow.py, java CoreStabilityWorkflow.java, typescript workflow.ts). The lane
//   caption: everything in the lane except the activity is the workflow's own logic.
// - check n: the run's input (jump.Check / jump["check"] / jump.check()), starts at 1.
// - ReadCoreTempActivity: the only activity; takes the check number and returns
//   coreTempK (1240 - 60 * (check - 1) in python and typescript; the assignment table).
// - stable?: workflow logic, `coreTempK <= 1000` in all four languages (the label
//   "<= 1000K" beside it). yes: returns {stable: true, checks, coreTempK}.
// - check 10?: workflow logic, `check == 10` (== in dotnet and python, === in
//   typescript, == on ints in java). In all four languages it is tested AFTER the
//   stable check and BEFORE the timer, so it is a second diamond on the "no" path,
//   with the second exit {stable: false, checks, coreTempK}.
// - durable timer, 5 s: CreateTimer(TimeSpan.FromSeconds(5)), create_timer(timedelta(
//   seconds=5)), createTimer(Duration.ofSeconds(5)), createTimer(5) (seconds).
// - continue-as-new: ContinueAsNew / continue_as_new / continueAsNew with the same
//   jumpId and check + 1; the run restarts with an empty history, so the arrow goes
//   back to the start, not into a loop.
//
// Connections: check n -> ReadCoreTempActivity -> stable? (coreTempK) -> yes: done;
// no -> check 10? -> yes: done (stable false); no -> timer -> continue-as-new -> check n.
//
// Departures from the skill, on purpose:
// - Every label is TEXT (13), the column minimum; label() instead of note().
// - Canvas 476 wide for the 424 px lab column (not 16:9 at 1100+ units).
// - Both decisions use a 13-unit label inside; the condition for stable? is part of its yes label.
// - The exits are small orange circles named below them (as on page 5), not text inside.
import { C } from '../_engine/engine.mjs';
import { elbowArrow, arrow, box, decision, decisionPoints, label, node, captionReach } from '../_engine/shapes.mjs';
import { FLOW, flowLane } from '../_engine/flow.mjs';

const TEXT = 13;
const W = 476;
const M = 12;
const LANE_X = M;
const LANE_Y = M;
const LANE_W = W - 2 * M;
const REACH = captionReach();
const NODE_R = FLOW.NODE_R;
const END_R = 16; // exit circles, named below them (as on page 5)
const COL1 = 70; // start node, and the continue-as-new run up the left
const COL2 = 238; // the vertical flow
const COL3 = 406; // the two exits
const ROW = 76; // between row centres
const R1 = Math.ceil(LANE_Y + REACH + 8 + NODE_R);
const R2 = R1 + ROW;
const R3 = R2 + ROW;
const R4 = R3 + ROW;
const LANE_H = R4 + 20 + 14 - LANE_Y; // the timer's half height and the lane's pad
const H = LANE_Y + LANE_H + M;
const CAPTION_W = 176; // "CoreStabilityWorkflow" measured at 13, plus pill padding

const ACT = { x: COL2, y: R1, w: 176, h: 40 };
const D1 = { x: COL2, y: R2, w: 96, h: 50 };
const D2 = { x: COL2, y: R3, w: 112, h: 50 };
const TIMER = { x: COL2, y: R4, w: 176, h: 40 };
const START = { x: COL1, y: R1, r: NODE_R };
const END1 = { x: COL3, y: R2, r: END_R };
const END2 = { x: COL3, y: R3, r: END_R };
const EXIT = { ...FLOW.end, labelInside: false, ink: C.body, size: TEXT };
const G = 2; // arrows stop this far from a shape's edge

const d1 = decisionPoints(D1);
const d2 = decisionPoints(D2);

export default {
  width: W,
  height: H,
  title: 'One run of CoreStabilityWorkflow, the monitor pattern',
  desc:
    'Inside a lane named CoreStabilityWorkflow, a green start circle named check n leads to ReadCoreTempActivity, '
    + 'which returns coreTempK to a decision named stable?, with the condition 1000K or less. Yes, 1000K or less, leads to a small orange end circle named stable true. '
    + 'No leads to a second decision, check 10?: yes leads to a small orange end circle named stable false. '
    + 'No leads to a box, 5 s durable timer, and an arrow named continue-as-new, check n plus 1, returns to the start.',

  build() {
    return [
      flowLane({ x: LANE_X, y: LANE_Y, w: LANE_W, h: LANE_H, caption: 'CoreStabilityWorkflow', captionW: CAPTION_W }),

      arrow({ from: [COL1 + NODE_R + G, R1], to: ACT }),
      arrow({ from: [COL2, R1 + ACT.h / 2 + G], to: [COL2, d1.top[1] - G] }),
      label({ x: COL2 + 8, y: (R1 + ACT.h / 2 + d1.top[1]) / 2, text: 'coreTempK', size: TEXT, anchor: 'start' }),

      arrow({ from: [d1.right[0] + G, R2], to: [END1.x - END_R - G, R2] }),
      label({ x: (d1.right[0] + END1.x - END_R) / 2, y: R2 - 14, text: 'yes, ≤ 1000K', size: TEXT }),
      arrow({ from: [COL2, d1.bottom[1] + G], to: [COL2, d2.top[1] - G] }),
      label({ x: COL2 + 8, y: (d1.bottom[1] + d2.top[1]) / 2, text: 'no', size: TEXT, anchor: 'start' }),

      arrow({ from: [d2.right[0] + G, R3], to: [END2.x - END_R - G, R3] }),
      label({ x: (d2.right[0] + END2.x - END_R) / 2, y: R3 - 14, text: 'yes', size: TEXT }),
      arrow({ from: [COL2, d2.bottom[1] + G], to: [COL2, R4 - TIMER.h / 2 - G] }),
      label({ x: COL2 + 8, y: (d2.bottom[1] + R4 - TIMER.h / 2) / 2, text: 'no', size: TEXT, anchor: 'start' }),

      elbowArrow({
        points: [[COL2 - TIMER.w / 2 - G, R4], [COL1, R4], [COL1, R1 + NODE_R + G]],
      }),
      label({ x: COL1 + 10, y: (R1 + NODE_R + R2) / 2 - 4, text: 'continue-as-new\ncheck n + 1', size: TEXT, anchor: 'start' }),

      node({ ...START, label: 'check n', ...FLOW.start, size: TEXT }),
      box({ ...ACT, label: 'ReadCoreTempActivity', ...FLOW.step, size: TEXT }),
      decision({ ...D1, label: 'stable?', size: TEXT }),
      decision({ ...D2, label: 'check 10?', size: TEXT }),
      box({ ...TIMER, label: '5 s durable timer', ...FLOW.wait, size: TEXT }),
      node({ ...END1, label: 'stable: true', ...EXIT }),
      node({ ...END2, label: 'stable: false', ...EXIT }),
    ];
  },
};
