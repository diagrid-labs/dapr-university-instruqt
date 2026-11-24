// dapr-workflow-aspire page 1 (create the solution), section 1 "The pre-jump
// diagnostics": the app the learner has at the end of the track, so page 1
// shows where the four labs are heading.
//
// Elements, with each name as it appears in the track (the spec's apphost.cs,
// which page 3 writes):
// - apphost.cs: the single-file Aspire AppHost. A captioned region around
//   every resource it starts.
// - engineering: `builder.AddDotnetProject("engineering", ...)`, the
//   Engineering project that holds the workflow. Green hexagon (APP[0]), the
//   house app size, with its Dapr sidecar (`.WithDaprSidecar(...)`) docked by
//   appSidecar().
// - statestore: `builder.AddDaprComponent("statestore", "state.redis")`, an
//   AppHost resource, so the Fluent document mark (the component YAML of the
//   other labs) inside the region, on the sidecar's line.
// - dapr_redis: the Redis container that `dapr init` started
//   (`redisHost` localhost:6379). Not an Aspire resource, so outside the
//   region: a gold data store with the Redis mark.
// - Aspire dashboard: started by `aspire run` (the hidden `aspire-dashboard`
//   resource), the Aspire tab. A box inside the region.
// - Dev Dashboard: `builder.AddExecutable("dev-dashboard", ...)`, the Dev
//   Dashboard tab. A box inside the region, beside the Aspire dashboard.
//
// Connections:
// - The sidecar saves the workflow history through statestore in dapr_redis
//   (two arrows on one line: sidecar -> statestore -> dapr_redis), the first
//   labelled "history" (the only gap wide enough for a label).
// - The two dashboards are the two views: the Aspire dashboard shows the
//   resources (a dashed leader up to engineering), the Dev Dashboard reads the
//   workflow history from dapr_redis (a dashed elbow to the store). Dashed,
//   because neither is part of the app's own traffic.
//
// Layout: two rows inside the region, at most three shapes in a row. Top: the
// app pair and statestore, with dapr_redis outside on the same line. Bottom:
// the two dashboards, each under the shape it looks at.
//
// Departures from the skill, on purpose: canvas 490 wide for the 424 px lab
// column; ports and the Dev Dashboard's resource name (dev-dashboard) are left
// out for readability (they are in the page text).
import { APP, C } from '../_engine/engine.mjs';
import { arrow, box, cylinder, elbowArrow, group, hexHalfWidth, label, region, STORE_RATIO } from '../_engine/shapes.mjs';
import { icon } from '../_engine/icons.mjs';
import { appSidecar, sidecarAt } from '../_engine/app.mjs';

const TEXT = 13; // every label in the scene

const W = 490;
const M = 12; // canvas margin
const PAD = 16; // region border to its contents

// The region's caption pill sits centred on its top edge.
const CAPTION_H = 26;
const CAPTION_W = 88; // "apphost.cs" at 13 (measured 68) plus half an em each side, and a little
const REG_T = M + CAPTION_H / 2;

// Bottom row: the two dashboards, side by side.
const BOX_W = 138; // "Aspire dashboard" at 13 (measured 112) plus about a character each side
const BOX_H = 34;
const BOX_GAP = 18;
const REG_L = M;
const BOX1_X = REG_L + PAD + BOX_W / 2;
const BOX2_X = BOX1_X + BOX_W + BOX_GAP;
const REG_R = BOX2_X + BOX_W / 2 + PAD;

// Top row: engineering over the Aspire dashboard, statestore over the Dev Dashboard.
const APP_R = 54;
const APP_X = BOX1_X - 10;
const APP_Y = REG_T + CAPTION_H / 2 + PAD + APP_R;
const SIDE = sidecarAt({ x: APP_X, y: APP_Y, r: APP_R, size: TEXT });
const DOC = 30; // the document mark's height
const DOC_X = BOX2_X;
const DOC_Y = SIDE.y;
const NAME_DY = 16; // a name sits this far below its shape
const WORD_DY = 14; // a label rides this far above its arrow

// Bottom row height: below the sidecar and statestore's name.
const BOX_Y = SIDE.y + SIDE.r + 22 + BOX_H / 2;
const REG_B = BOX_Y + BOX_H / 2 + PAD;

// dapr_redis: outside the region, centred in the space to its right, on the sidecar's line.
const STORE_W = 92;
const STORE_H = STORE_W / STORE_RATIO;
const STORE_X = (REG_R + W - M) / 2;
const STORE_Y = SIDE.y;
const MARK = 34;

const H = Math.ceil(Math.max(REG_B, STORE_Y + STORE_H / 2 + NAME_DY + 6) + M);

// The Aspire dashboard's leader runs up to engineering left of the sidecar.
const LEAD_X = APP_X - 24;

if (STORE_X - STORE_W / 2 - REG_R < 16) throw new Error('workflow-aspire-1-architecture: dapr_redis touches the region');

export default {
  width: W,
  height: H,
  title: 'The Aspire AppHost runs engineering, its Dapr sidecar and two dashboards',
  desc:
    'A region captioned apphost.cs holds a green hexagon labelled engineering with a Dapr sidecar '
    + 'docked on its lower right, a document mark named statestore, and two boxes, Aspire dashboard '
    + 'and Dev Dashboard. An arrow labelled history runs from the sidecar to statestore and on, out of the region, to a '
    + 'gold data store with the Redis mark named dapr_redis. A dashed line runs from the Aspire '
    + 'dashboard up to engineering, and a dashed line runs from the Dev Dashboard to dapr_redis.',

  build() {
    const doc = { x: DOC_X, y: DOC_Y, w: DOC * 0.8, h: DOC };
    const store = { x: STORE_X, y: STORE_Y, w: STORE_W, h: STORE_H };
    const sideRight = SIDE.x + hexHalfWidth(SIDE.r);
    const box2Right = BOX2_X + BOX_W / 2;
    return [
      region({
        x: REG_L, y: REG_T, w: REG_R - REG_L, h: REG_B - REG_T,
        caption: 'apphost.cs', captionSize: TEXT, captionW: CAPTION_W,
      }),

      // The workflow history: sidecar -> statestore -> dapr_redis.
      arrow({ from: [sideRight + 2, SIDE.y], to: doc }),
      label({ x: (sideRight + DOC_X - DOC * 0.4) / 2, y: SIDE.y - WORD_DY, text: 'history', size: TEXT }),
      arrow({ from: doc, to: store }),

      // The two views.
      arrow({ from: [LEAD_X, BOX_Y - BOX_H / 2 - 2], to: [LEAD_X, APP_Y + 0.5 * APP_R + 2], head: false, dash: true }),
      elbowArrow({ points: [[box2Right + 2, BOX_Y], [STORE_X, BOX_Y], [STORE_X, STORE_Y + STORE_H / 2 + 2]], dash: true }),

      appSidecar({ x: APP_X, y: APP_Y, r: APP_R, label: 'engineering', size: TEXT, ...APP[0] }),

      group([
        icon({ name: 'fluent-document', x: DOC_X, y: DOC_Y, size: DOC, color: C.navy, fit: 'ink' }),
        label({ x: DOC_X, y: DOC_Y + DOC / 2 + NAME_DY, text: 'statestore', size: TEXT }),
      ]),

      box({ x: BOX1_X, y: BOX_Y, w: BOX_W, h: BOX_H, label: 'Aspire dashboard', size: TEXT }),
      box({ x: BOX2_X, y: BOX_Y, w: BOX_W, h: BOX_H, label: 'Dev Dashboard', size: TEXT }),

      group([
        cylinder({ x: STORE_X, y: STORE_Y, w: STORE_W }),
        icon({ name: 'redis', x: STORE_X, y: STORE_Y, size: MARK, color: C.appInk, fit: 'ink' }),
        label({ x: STORE_X, y: STORE_Y - STORE_H / 2 - NAME_DY + 4, text: 'dapr_redis', size: TEXT }),
      ]),
    ];
  },
};
