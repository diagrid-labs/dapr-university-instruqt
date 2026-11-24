// dapr-workflow-101 page 1 (durable execution): what runs where.
//
// Elements, with each name as it appears in the demo (diagrid-labs/university-labs
// at 44ccac8, folder workflow/):
// - "Workflow app:": a role label above the app ID, so the learner reads the
//   green hexagon as the workflow app (lab owner's request).
// - engineering: the app ID, `appID: engineering` in every language's
//   demo1 dapr.yaml (for example dotnet/Demo1-DurableExecution/dapr.yaml).
// - ChargeWarpCoreWorkflow: the workflow, ChargeWarpCoreWorkflow.cs and
//   python/demo1-durable-execution/engineering/workflow.py (name="ChargeWarpCoreWorkflow").
// - ChargeStageActivity: the activity, ChargeStageActivity.cs and workflow.py
//   (name="ChargeStageActivity").
// - The Dapr sidecar of engineering.
// - statestore: the Redis state store component, <lang>/resources/statestore.yaml
//   (metadata.name statestore, type state.redis, actorStateStore true).
//
// Connections:
// - ChargeWarpCoreWorkflow calls ChargeStageActivity (inside the app).
// - The sidecar saves the workflow history in statestore.
//
// Departures from the skill, on purpose:
// - The workflow and the activity run in the app's process, so they are drawn
//   INSIDE the engineering hexagon rather than as apps of their own. That needs a
//   hexagon wide enough for a 13-unit "ChargeWarpCoreWorkflow" box, so the app is
//   larger than the skill's 42.5 to 60, and the sidecar is a markHex() docked on
//   its lower right by hand: appSidecar() would scale the sidecar to 0.75 of this
//   radius. The sidecar keeps the house size relation to a normal app instead
//   (0.75 of 48).
// - The boxes are filled with the page ground (C.bg) so their body-ink names read
//   on the solid green in both themes; box() always sets its name in C.body.
// - The content of the hexagon ("Workflow app:", "engineering", the two boxes and
//   the "calls" arrow) is one group, centred vertically and horizontally in the
//   hexagon. The "calls" arrow and its label use the app ink (C.appInk, #11161f in
//   both themes) rather than the house navy, which is light blue in the dark theme
//   and does not stand out on the green.
// - Canvas 490 wide for the 424 px lab column (not 16:9 at 1100+ units).
import { C, APP } from '../_engine/engine.mjs';
import { arrow, box, cylinder, group, hex, hexHalfWidth, hexHalfWidthAt, label, STORE_RATIO } from '../_engine/shapes.mjs';
import { markHex, icon } from '../_engine/icons.mjs';

const W = 490;
const H = 320;

const TEXT = 13; // every label in the scene

// The app: a solid green hexagon that holds the workflow and the activity.
// The radius is what the group below needs for two characters (13 units) of
// clearance from the lower box corners to the sloping edges, plus a little.
const APP_R = 138;
const APP_X = 12 + hexHalfWidth(APP_R) + 4;
const APP_Y = H / 2 - 14;

// The group inside it, top to bottom: "Workflow app:", "engineering", the
// workflow box, the "calls" arrow, the activity box. BOX_W is the measured
// width of "ChargeWarpCoreWorkflow" plus about a character each side.
const BOX_W = 196;
const BOX_H = 34;
const BOX_GAP = 30; // room for the "calls" arrow between them
const LINE = 17; // "Workflow app:" to "engineering", centre to centre
const NAME_GAP = 24; // "engineering" centre to the workflow box's top
const GLYPH = 0.37 * TEXT; // a label's glyph top above its y
const GROUP_H = GLYPH + LINE + NAME_GAP + BOX_H + BOX_GAP + BOX_H;
const GROUP_TOP = APP_Y - GROUP_H / 2; // centred vertically in the hexagon
const ROLE_Y = GROUP_TOP + GLYPH; // "Workflow app:"
const NAME_Y = ROLE_Y + LINE; // the app's name
const WF_Y = NAME_Y + NAME_GAP + BOX_H / 2;
const ACT_Y = WF_Y + BOX_H + BOX_GAP;

// The lower box corners sit furthest down the sloping edges; keep two
// characters between them, or say so loudly.
const CORNER_CLEAR = hexHalfWidthAt(APP_R, ACT_Y + BOX_H / 2 - APP_Y) - BOX_W / 2;
if (CORNER_CLEAR < TEXT) throw new Error(`workflow-101-1-architecture: box corner clearance ${CORNER_CLEAR.toFixed(1)} < ${TEXT}`);

// The sidecar, docked on the app's lower right edge so most of it overlaps.
const SIDE_R = 36;
const SIDE = { x: APP_X + 0.66 * APP_R, y: APP_Y + 0.72 * APP_R, r: SIDE_R, hex: true };

// The state store, on the sidecar's line so the arrow runs straight.
const STORE_W = 96;
const STORE_H = STORE_W / STORE_RATIO;
const STORE_X = W - 12 - 6 - STORE_W / 2;
const STORE_Y = SIDE.y;
const STORE = { x: STORE_X, y: STORE_Y, w: STORE_W, h: STORE_H };
const MARK = 36;
const NAME_DY = 16; // a name sits this far below its shape
const WORD_DY = 14; // a label rides this far above its run

const RUN_X0 = SIDE.x + hexHalfWidth(SIDE_R);
const RUN_X1 = STORE_X - STORE_W / 2;

export default {
  width: W,
  height: H,
  title: 'The engineering app, its Dapr sidecar and the Redis state store',
  desc:
    'A green hexagon labelled Workflow app: engineering holds two boxes: ChargeWarpCoreWorkflow at the top, '
    + 'with an arrow labelled calls down to ChargeStageActivity. The Dapr sidecar overlaps the '
    + 'lower right of the hexagon. An arrow labelled workflow history runs from the sidecar to a '
    + 'gold data store with the Redis mark, named statestore.',

  build() {
    return [
      arrow({ from: [RUN_X0, SIDE.y], to: STORE }),
      label({ x: (RUN_X0 + RUN_X1) / 2, y: SIDE.y - WORD_DY, text: 'workflow history', size: TEXT }),

      hex({ x: APP_X, y: APP_Y, r: APP_R, label: '', ...APP[0] }),
      label({ x: APP_X, y: ROLE_Y, text: 'Workflow app:', size: TEXT, color: APP[0].ink }),
      label({ x: APP_X, y: NAME_Y, text: 'engineering', size: TEXT, color: APP[0].ink }),
      box({ x: APP_X, y: WF_Y, w: BOX_W, h: BOX_H, label: 'ChargeWarpCoreWorkflow', size: TEXT, fill: C.bg, solid: true }),
      arrow({ from: { x: APP_X, y: WF_Y, w: BOX_W, h: BOX_H }, to: { x: APP_X, y: ACT_Y, w: BOX_W, h: BOX_H }, color: C.appInk }),
      label({ x: APP_X + 12, y: (WF_Y + ACT_Y) / 2, text: 'calls', size: TEXT, color: C.appInk, anchor: 'start' }),
      box({ x: APP_X, y: ACT_Y, w: BOX_W, h: BOX_H, label: 'ChargeStageActivity', size: TEXT, fill: C.bg, solid: true }),

      markHex({ x: SIDE.x, y: SIDE.y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),

      group([
        cylinder({ x: STORE_X, y: STORE_Y, w: STORE_W }),
        icon({ name: 'redis', x: STORE_X, y: STORE_Y, size: MARK, color: C.appInk, fit: 'ink' }),
        label({ x: STORE_X, y: STORE_Y + STORE_H / 2 + NAME_DY, text: 'statestore', size: TEXT }),
      ]),
    ];
  },
};
