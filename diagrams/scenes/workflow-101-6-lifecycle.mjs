// dapr-workflow-101 page 6 (management): the states of a LongRangeJumpWorkflow instance
// and the operations that move it between them. A state picture, not a flow of steps.
//
// Elements, with each name as it appears in the assignment and the demo
// (diagrid-labs/university-labs at 44ccac8, folder workflow/, Demo6-Management):
// - RUNNING, SUSPENDED, COMPLETED, TERMINATED: the status values the lab prints in the
//   curl output (`"status": "RUNNING"` ... sections 3, 5, 6, 7) and in `dapr workflow list`.
// - PURGED: not a status. After a purge the instance is gone (section 7: 404
//   JUMP_NOT_FOUND), so the box is drawn like the other finished states (grey outline)
//   and named after the operation ("Purges the workflow's history").
// - pause / resume: POST /jumps/{jumpId}/pause and /resume (SuspendWorkflow /
//   ResumeWorkflow); RUNNING <-> SUSPENDED (sections 3 and 5).
// - terminate: POST /jumps/{jumpId}/terminate. From RUNNING (section 6). From SUSPENDED:
//   the demo code only rejects finished jumps (ensure_active: COMPLETED, FAILED,
//   TERMINATED -> 409) and section 10 says "If the list shows a jump that is RUNNING or
//   SUSPENDED, terminate it", so both are drawn.
// - complete: the jump finishing by itself, RUNNING -> COMPLETED (section 7, output JUMPED).
// - purge: DELETE /jumps/{jumpId}, only from COMPLETED and TERMINATED (section 4: a
//   paused jump is refused with 500 WORKFLOW_ERROR; sections 7 and 9). The refusal for
//   RUNNING and SUSPENDED is left to the text.
// Not drawn: FAILED (never shown in the lab), pause/resume of a finished jump (409).
//
// Departures from the skill, on purpose:
// - Every label is TEXT (13), the column minimum; label() instead of note().
// - Canvas 476 wide for the 424 px lab column (not 16:9 at 1100+ units).
// Colours as in the flow scenes: teal = runs, gold = deliberately idle (a suspended
// workflow gets no work), grey = finished. No red (it means a crash).
import { C } from '../_engine/engine.mjs';
import { elbowArrow, arrow, box, label } from '../_engine/shapes.mjs';
import { FLOW } from '../_engine/flow.mjs';

const TEXT = 13;
const W = 476;
const M = 12;
const G = 2; // arrows stop this far from a shape's edge
const BW = 150;
const BH = 44;
const COL_L = M + BW / 2 + 12; // 99
const COL_R = W - M - BW / 2 - 12; // 377
const ROW1 = M + BH / 2 + 4; // 38
const ROW2 = ROW1 + 118;
const ROW3 = ROW2 + 104;
const H = ROW3 + BH / 2 + M;
const MID_X = (COL_L + COL_R) / 2;
const PURGED = { x: MID_X, y: ROW3, w: 120, h: BH };
const MID1 = ROW1 + 59 + 8; // the run from RUNNING to TERMINATED, between rows 1 and 2

const RUN = { x: COL_L, y: ROW1, w: BW, h: BH };
const SUS = { x: COL_R, y: ROW1, w: BW, h: BH };
const DONE = { x: COL_L, y: ROW2, w: BW, h: BH };
const TERM = { x: COL_R, y: ROW2, w: BW, h: BH };

const FINISHED = { stroke: C.caption, fill: C.navyFill, size: TEXT };

export default {
  width: W,
  height: H,
  title: 'The states of a jump and the operations between them',
  desc:
    'Five state boxes. RUNNING and SUSPENDED sit on top with arrows between them named pause and resume. '
    + 'COMPLETED and TERMINATED sit below. RUNNING has an arrow named complete to COMPLETED and an arrow named '
    + 'terminate to TERMINATED; SUSPENDED has an arrow named terminate to TERMINATED. PURGED sits at the bottom, with '
    + 'an arrow named purge from COMPLETED and one from TERMINATED.',

  build() {
    const tx1 = COL_R - 50; // the two terminate arrows enter TERMINATED apart
    const tx2 = COL_R + 30;
    return [
      // pause / resume
      arrow({ from: [RUN.x + BW / 2 + G, ROW1 - 8], to: [SUS.x - BW / 2 - G, ROW1 - 8] }),
      label({ x: MID_X, y: ROW1 - 22, text: 'pause', size: TEXT }),
      arrow({ from: [SUS.x - BW / 2 - G, ROW1 + 8], to: [RUN.x + BW / 2 + G, ROW1 + 8] }),
      label({ x: MID_X, y: ROW1 + 24, text: 'resume', size: TEXT }),

      // complete
      arrow({ from: [COL_L, ROW1 + BH / 2 + G], to: [COL_L, ROW2 - BH / 2 - G] }),
      label({ x: COL_L - 8, y: (ROW1 + ROW2) / 2, text: 'complete', size: TEXT, anchor: 'end' }),

      // terminate from RUNNING (elbow) and from SUSPENDED (straight)
      elbowArrow({
        points: [[COL_L + 50, ROW1 + BH / 2 + G], [COL_L + 50, MID1], [tx1, MID1], [tx1, ROW2 - BH / 2 - G]],
      }),
      label({ x: (COL_L + 50 + tx1) / 2, y: MID1 + 16, text: 'terminate', size: TEXT }),
      arrow({ from: [tx2, ROW1 + BH / 2 + G], to: [tx2, ROW2 - BH / 2 - G] }),
      label({ x: tx2 + 8, y: (ROW1 + ROW2) / 2 - 10, text: 'terminate', size: TEXT, anchor: 'start' }),

      // purge, only from the two finished states
      elbowArrow({ points: [[COL_L, ROW2 + BH / 2 + G], [COL_L, ROW3], [PURGED.x - PURGED.w / 2 - G, ROW3]] }),
      label({ x: (COL_L + PURGED.x - PURGED.w / 2) / 2 + 4, y: ROW3 - 14, text: 'purge', size: TEXT }),
      elbowArrow({ points: [[COL_R, ROW2 + BH / 2 + G], [COL_R, ROW3], [PURGED.x + PURGED.w / 2 + G, ROW3]] }),
      label({ x: (COL_R + PURGED.x + PURGED.w / 2) / 2 - 4, y: ROW3 - 14, text: 'purge', size: TEXT }),

      box({ ...RUN, label: 'RUNNING', ...FLOW.step }),
      box({ ...SUS, label: 'SUSPENDED', ...FLOW.wait }),
      box({ ...DONE, label: 'COMPLETED', ...FINISHED }),
      box({ ...TERM, label: 'TERMINATED', ...FINISHED }),
      box({ ...PURGED, label: 'PURGED', ...FINISHED }),
    ];
  },
};
