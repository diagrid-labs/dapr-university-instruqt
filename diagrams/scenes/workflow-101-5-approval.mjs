// dapr-workflow-101 page 5 (approval): one run of AuthorizedJumpWorkflow. It plots the
// course, waits up to 60 s for the external event jump-authorized, then jumps, stops on
// a denial or aborts when nobody answers. The captain's authorize call raises the event.
//
// Elements, with each name and number as it appears in the assignment and the demo
// (diagrid-labs/university-labs at 44ccac8, folder workflow/, Demo5-HumanInTheLoop):
// - AuthorizedJumpWorkflow: the workflow (dotnet AuthorizedJumpWorkflow.cs, python
//   workflow.py, java AuthorizedJumpWorkflow.java, typescript workflow.ts). The lane
//   caption: everything in the lane except the two activities is the workflow's own logic.
// - PlotCourseActivity: first step in all four languages (CallActivityAsync / call_activity /
//   callActivity); its result, the course, is only passed on to the engage step.
// - wait for jump-authorized, 60 s: WaitForExternalEventAsync("jump-authorized",
//   TimeSpan.FromSeconds(60)), wait_for_external_event(..., timeout=timedelta(seconds=60)),
//   waitForExternalEvent("jump-authorized", Duration.ofSeconds(60), ...),
//   waitForExternalEvent("jump-authorized", { timeoutInSeconds: 60 }). The timeout is part
//   of the wait (TaskCanceledException / TimeoutError / TaskTimeoutError): no timer of its own.
// - timeout: the catch leads to {status: "ABORTED_NO_AUTHORIZATION"}, no authorizedBy.
// - approved?: workflow logic on the event's `approved` field (authorization.Approved,
//   authorization["approved"], authorization.approved(), authorization.approved).
//   false: {status: "DENIED", authorizedBy: officer}, no engage.
// - EngageJumpActivity: the second and last activity, called only when approved (warp
//   factor 6), then {status: "JUMPED", authorizedBy: officer}.
// - POST /jumps/{jumpId}/authorize: the endpoint (Jumps.cs, app.py, JumpController.java)
//   that raises jump-authorized for the jump's ID; the captain calls it (assignment table).
//   It is the app's HTTP endpoint, outside the workflow, so it sits outside the lane.
// - Exits: JUMPED, DENIED, ABORTED_NO_AUTHORIZATION, the exact status strings.
//
// Connections: PlotCourseActivity -> wait; POST -> wait (event); wait -> approved?
// (event) / -> ABORTED_NO_AUTHORIZATION (timeout); approved? -> no: DENIED, yes:
// EngageJumpActivity -> JUMPED.
//
// Departures from the skill, on purpose:
// - Every label is TEXT (13), the column minimum; label() instead of note().
// - Canvas 476 wide for the 424 px lab column (not 16:9 at 1100+ units).
// - The exits are small orange circles named below them (not inside): the full status
//   strings do not fit in a circle, and the long one fits below at 13 units unwrapped.
import { C } from '../_engine/engine.mjs';
import { elbowArrow, arrow, box, decision, decisionPoints, label, node, captionReach } from '../_engine/shapes.mjs';
import { FLOW, flowLane } from '../_engine/flow.mjs';

const TEXT = 13;
const W = 476;
const M = 12;
const G = 2; // arrows stop this far from a shape's edge
const END_R = 16; // exit circles, named below them
const COL_L = 120; // PlotCourseActivity, the timeout leg and the exits JUMPED and ABORTED
const COL_R = 330; // the wait, approved?, EngageJumpActivity
const COL_D = 424; // DENIED

const POST = { x: COL_R, y: M + 22, w: 164, h: 44 };
const LANE_X = M;
const LANE_Y = POST.y + POST.h / 2 + 30;
const LANE_W = W - 2 * M;
const R1 = Math.ceil(LANE_Y + captionReach() + 10 + 25);
const R2 = R1 + 78;
const R3 = R2 + 73;
const LANE_H = R3 + END_R + 14 + 8 + 6 - LANE_Y; // exit name below the last circle, plus pad
const H = LANE_Y + LANE_H + M;
const CAPTION_W = 176; // "AuthorizedJumpWorkflow" measured at 13, plus pill padding

const PLOT = { x: COL_L, y: R1, w: 164, h: 40 };
const WAIT = { x: COL_R, y: R1, w: 176, h: 50 };
const D1 = { x: COL_R, y: R2, w: 92, h: 50 };
const ENGAGE = { x: COL_R, y: R3, w: 164, h: 40 };
const ABORT = { x: COL_L, y: R2, r: END_R };
const DENY = { x: COL_D, y: R2, r: END_R };
const JUMP = { x: COL_L, y: R3, r: END_R };
const TIMEOUT_X = WAIT.x - WAIT.w / 2 + 20; // the timeout leaves the wait here, clear of approved?

const d1 = decisionPoints(D1);
const EXIT = { ...FLOW.end, labelInside: false, ink: C.body, size: TEXT };

export default {
  width: W,
  height: H,
  title: 'AuthorizedJumpWorkflow waits for the captain, the human in the loop pattern',
  desc:
    'A box named captain, POST /jumps/{jumpId}/authorize, sits above a lane named AuthorizedJumpWorkflow and has an '
    + 'arrow into a gold box in the lane, jump-authorized, 60 s timeout. In the lane, PlotCourseActivity leads to that '
    + 'wait. From the wait, an arrow named event leads to a decision, approved?, and an arrow named timeout leads to an '
    + 'end circle, ABORTED_NO_AUTHORIZATION. From the decision, no leads to an end circle, DENIED, and yes leads to '
    + 'EngageJumpActivity and then to an end circle, JUMPED.',

  build() {
    return [
      flowLane({ x: LANE_X, y: LANE_Y, w: LANE_W, h: LANE_H, caption: 'AuthorizedJumpWorkflow', captionW: CAPTION_W }),

      arrow({ from: [POST.x, POST.y + POST.h / 2 + G], to: [COL_R, R1 - WAIT.h / 2 - G] }),
      arrow({ from: [PLOT.x + PLOT.w / 2 + G, R1], to: [WAIT.x - WAIT.w / 2 - G, R1] }),

      arrow({ from: [COL_R, R1 + WAIT.h / 2 + G], to: [COL_R, d1.top[1] - G] }),
      label({ x: COL_R + 8, y: (R1 + WAIT.h / 2 + d1.top[1]) / 2, text: 'event', size: TEXT, anchor: 'start' }),
      elbowArrow({ points: [[TIMEOUT_X, R1 + WAIT.h / 2 + G], [TIMEOUT_X, R2], [ABORT.x + END_R + G, R2]] }),
      label({ x: (ABORT.x + END_R + TIMEOUT_X) / 2, y: R2 - 14, text: 'timeout', size: TEXT }),

      arrow({ from: [d1.right[0] + G, R2], to: [DENY.x - END_R - G, R2] }),
      label({ x: (d1.right[0] + DENY.x - END_R) / 2, y: R2 - 14, text: 'no', size: TEXT }),
      arrow({ from: [COL_R, d1.bottom[1] + G], to: [COL_R, R3 - ENGAGE.h / 2 - G] }),
      label({ x: COL_R + 8, y: (d1.bottom[1] + R3 - ENGAGE.h / 2) / 2, text: 'yes', size: TEXT, anchor: 'start' }),
      arrow({ from: [ENGAGE.x - ENGAGE.w / 2 - G, R3], to: [JUMP.x + END_R + G, R3] }),

      box({ ...POST, label: 'captain\nPOST …/authorize', stroke: C.caption, fill: C.navyFill, size: TEXT }),
      box({ ...PLOT, label: 'PlotCourseActivity', ...FLOW.step, size: TEXT }),
      box({ ...WAIT, label: 'jump-authorized\n60 s timeout', ...FLOW.wait, size: TEXT }),
      decision({ ...D1, label: 'approved?', size: TEXT }),
      box({ ...ENGAGE, label: 'EngageJumpActivity', ...FLOW.step, size: TEXT }),
      node({ ...ABORT, label: 'ABORTED_NO_AUTHORIZATION', ...EXIT }),
      node({ ...DENY, label: 'DENIED', ...EXIT }),
      node({ ...JUMP, label: 'JUMPED', ...EXIT }),
    ];
  },
};
