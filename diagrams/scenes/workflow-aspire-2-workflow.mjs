// dapr-workflow-aspire page 2 (write the workflow), section 1 "The diagnostics
// workflow": one run of DiagnosticsWorkflow, the code the learner pastes on
// that page.
//
// Elements, with each name as it appears in the page's DiagnosticsWorkflow.cs
// and Activities.cs:
// - start: the run starts with a DiagnosticsInput (id, stardate).
// - DiagnoseSubsystemActivity: called three times at once (fan-out), with
//   "WarpCore", "LifeSupport" and "Shields", in that order in the code. The
//   activity name is a heading over the stack (as in workflow-101-3-fan-out).
// - 15 s durable timer: `context.CreateTimer(TimeSpan.FromSeconds(15))`, after
//   `Task.WhenAll` (fan-in), while the sensors settle. Gold: a wait.
// - PrioritizeDiagnosticsActivity: takes the three reports, returns the priority.
// - Urgent?: `if (priority == "Urgent")`, workflow logic, so a decision.
// - NotifyBridgeActivity: only on the yes path.
// - done: the workflow returns its DiagnosticsOutput on both paths.
//
// Connections: start -> each of the three checks (fan-out) -> the timer
// (fan-in) -> PrioritizeDiagnosticsActivity -> Urgent? -> yes: NotifyBridge-
// Activity -> done; no: done.
//
// Layout: the fan-out/fan-in reads left to right on the top rows, then the
// flow turns down the right column and comes back right to left on the bottom
// row, so the canvas stays wider than tall. At most three shapes in a row.
//
// Departures from the skill, on purpose:
// - Every label is TEXT (13), the column minimum; label() instead of note().
// - The three check boxes are 110 x 28 (shorter than FLOW.H), as on the
//   workflow-101 fan-out page.
// - Canvas 484 wide for the 424 px lab column (not 16:9 at 1100+ units).
import { C } from '../_engine/engine.mjs';
import { arrow, box, decision, decisionPoints, elbowArrow, label, node } from '../_engine/shapes.mjs';
import { FLOW } from '../_engine/flow.mjs';

const TEXT = 13;
const W = 484;
const M = 12;
const G = 2; // arrows stop this far from a shape's edge

// Columns: the start node, the stack of checks, the right-hand column.
const START_R = 26;
const COL1 = M + START_R;
const COL2 = 172;
const COL3 = W - M - 106;

// The stack of three checks under its heading.
const TOP = 42;
const CHECK_W = 110;
const CHECK_H = 28;
const CHECK_GAP = 8;
const rowY = (i) => TOP + CHECK_H / 2 + i * (CHECK_H + CHECK_GAP);
const MID = rowY(1);
const SUBSYSTEMS = ['WarpCore', 'LifeSupport', 'Shields'];

const TIMER = { x: COL3, y: MID, w: 152, h: 44 };
const PRIORITIZE = { x: COL3, y: 162, w: 212, h: 44 };
const URGENT = { x: COL3, y: 234, w: 104, h: 52 };
const NOTIFY = { x: 184, y: URGENT.y, w: 152, h: 44 };
const END_R = 24;
const END = { x: M + END_R + 2, y: URGENT.y, r: END_R };
const NO_Y = URGENT.y + URGENT.h / 2 + 22; // the no path runs back along here
const H = NO_Y + 16;

const STEP = { ...FLOW.step, size: TEXT };
const u = decisionPoints(URGENT);

export default {
  width: W,
  height: H,
  title: 'One run of DiagnosticsWorkflow',
  desc:
    'A green start circle has three arrows, labelled fan-out, to three boxes under the heading '
    + 'DiagnoseSubsystemActivity: WarpCore, LifeSupport and Shields. Three arrows, labelled fan-in, lead from them '
    + 'to a gold box, 15 s durable timer. It leads down to PrioritizeDiagnosticsActivity, then to a decision, '
    + 'Urgent?. Yes leads left to NotifyBridgeActivity and on to an orange end circle, done. No runs below the row '
    + 'back to the same end circle.',

  build() {
    const out = [];
    const checkLeft = COL2 - CHECK_W / 2;
    const checkRight = COL2 + CHECK_W / 2;
    const timerLeft = TIMER.x - TIMER.w / 2;
    SUBSYSTEMS.forEach((_, i) => {
      const y = rowY(i);
      // Fan-out from the start circle's edge, towards each check.
      const dy = y - MID;
      const len = Math.hypot(checkLeft - COL1, dy);
      const from = [COL1 + ((checkLeft - COL1) / len) * (START_R + G), MID + (dy / len) * (START_R + G)];
      out.push(arrow({ from, to: [checkLeft - G, y] }));
      // Fan-in to the timer's left edge, spread over its height.
      out.push(arrow({ from: [checkRight + G, y], to: [timerLeft - G, MID + (i - 1) * 13] }));
    });
    out.push(label({ x: COL2, y: TOP - 18, text: 'DiagnoseSubsystemActivity', size: TEXT }));
    // Each above the top arrow of its fan, clear of the boxes and the heading.
    out.push(label({ x: COL1 + 22, y: rowY(0) - 14, text: 'fan-out', size: TEXT }));
    out.push(label({ x: (checkRight + timerLeft) / 2, y: rowY(0) - 14, text: 'fan-in', size: TEXT }));

    out.push(arrow({ from: [COL3, TIMER.y + TIMER.h / 2 + G], to: [COL3, PRIORITIZE.y - PRIORITIZE.h / 2 - G] }));
    out.push(arrow({ from: [COL3, PRIORITIZE.y + PRIORITIZE.h / 2 + G], to: [COL3, u.top[1] - G] }));

    // yes: left to NotifyBridgeActivity, then on to done.
    out.push(arrow({ from: [u.left[0] - G, URGENT.y], to: [NOTIFY.x + NOTIFY.w / 2 + G, URGENT.y] }));
    out.push(label({ x: (u.left[0] + NOTIFY.x + NOTIFY.w / 2) / 2, y: URGENT.y - 14, text: 'yes', size: TEXT }));
    out.push(arrow({ from: [NOTIFY.x - NOTIFY.w / 2 - G, URGENT.y], to: [END.x + END_R + G, URGENT.y] }));

    // no: down, back along the bottom, up into done.
    out.push(elbowArrow({ points: [[COL3, u.bottom[1] + G], [COL3, NO_Y], [END.x, NO_Y], [END.x, END.y + END_R + G]] }));
    out.push(label({ x: COL3 + 8, y: (u.bottom[1] + NO_Y) / 2, text: 'no', size: TEXT, anchor: 'start' }));

    out.push(node({ x: COL1, y: MID, r: START_R, label: 'start', ...FLOW.start, size: TEXT }));
    SUBSYSTEMS.forEach((name, i) => {
      out.push(box({ x: COL2, y: rowY(i), w: CHECK_W, h: CHECK_H, label: name, ...STEP }));
    });
    out.push(box({ ...TIMER, label: '15 s durable timer', ...FLOW.wait, size: TEXT }));
    out.push(box({ ...PRIORITIZE, label: 'PrioritizeDiagnosticsActivity', ...STEP }));
    out.push(decision({ ...URGENT, label: 'Urgent?', size: TEXT }));
    out.push(box({ ...NOTIFY, label: 'NotifyBridgeActivity', ...STEP }));
    out.push(node({ ...END, label: 'done', ...FLOW.end, size: TEXT }));
    return out;
  },
};
