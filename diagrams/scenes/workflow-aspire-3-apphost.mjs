// dapr-workflow-aspire page 3 (orchestrate with Aspire), section 2 "What the
// AppHost adds": how each call in apphost.cs becomes a resource that the
// Aspire dashboard shows.
//
// Elements, with each name as it appears in the page's apphost.cs and in the
// Aspire dashboard:
// - apphost.cs: a captioned region on the left with the three calls, set in
//   the code font, one box per resource:
//   `AddDaprComponent`, `AddDotnetProject` + `.WithDaprSidecar` (one box, two
//   lines: the sidecar is chained onto the project), `AddExecutable`.
// - Aspire dashboard: a captioned region on the right with the resources:
//   - statestore: the Dapr component, the Fluent document mark (the component
//     YAML of the other labs), as on page 1.
//   - engineering and its sidecar engineering-dapr: the green app hexagon
//     with the docked Dapr sidecar, the sidecar's resource name below it.
//   - dev-dashboard: the executable, a box.
//
// Connections: one arrow per call, left to right, from the call to the
// resource it adds.
//
// Layout: three rows, each a call and its resource, so a row holds two
// shapes. The engineering row is the tallest (the hexagon and its sidecar).
//
// Departures from the skill, on purpose: canvas 490 wide for the 424 px lab
// column; every label is TEXT (13), the column minimum. engineering-dapr-cli
// (the `dapr run` process the sidecar runs in) is left out: it is a detail of
// the dashboard, which the page text explains.
import { APP, C } from '../_engine/engine.mjs';
import { arrow, box, group, hexHalfWidth, label, region } from '../_engine/shapes.mjs';
import { icon } from '../_engine/icons.mjs';
import { appSidecar, sidecarAt } from '../_engine/app.mjs';

const TEXT = 13;
const W = 490;
const M = 12;
const PAD = 14; // region border to its contents
const CAPTION_H = 26;
const G = 2; // arrows stop this far from a shape's edge

// Left region: the calls in apphost.cs.
const CODE_W = 170;
const CODE_H = 34;
const CODE2_H = 52; // two lines
const L_L = M;
const L_R = L_L + PAD + CODE_W + PAD;
const CODE_X = (L_L + L_R) / 2;
const L_CAPTION_W = 88; // "apphost.cs" at 13 (measured 68) plus half an em each side, and a little

// Right region: the resources.
const R_R = W - M;
const R_L = 268;
const RES_X = (R_L + R_R) / 2 - 12;
const R_CAPTION_W = 138; // "Aspire dashboard" at 13 (measured 112) plus half an em each side

const TOP = M + CAPTION_H / 2;

// Row 1: AddDaprComponent -> statestore.
const DOC = 30;
const ROW1 = TOP + CAPTION_H / 2 + PAD + DOC / 2 + 4;
const NAME_DY = 16;

// Row 2: AddDotnetProject + WithDaprSidecar -> engineering and engineering-dapr.
const APP_R = 54;
const APP_X = RES_X - 14;
const APP_Y = ROW1 + DOC / 2 + 14 + APP_R;
const SIDE = sidecarAt({ x: APP_X, y: APP_Y, r: APP_R, size: TEXT });
const SIDE_NAME_Y = SIDE.y + SIDE.r + 12;

// Row 3: AddExecutable -> dev-dashboard.
const DD_W = 130;
const DD_H = 34;
const ROW3 = SIDE_NAME_Y + 14 + DD_H / 2;

const BOTTOM = ROW3 + DD_H / 2 + PAD;
const H = Math.ceil(BOTTOM + M);

const codeBox = (y, h, text) => group([
  box({ x: CODE_X, y, w: CODE_W, h, stroke: C.navy, fill: C.navyFill }),
  label({ x: CODE_X, y, text, size: TEXT, weight: 500, mono: true }),
]);

if (W / H < 1.33) throw new Error(`workflow-aspire-3-apphost: ${W} x ${H} is narrower than 1.33`);

export default {
  width: W,
  height: H,
  title: 'Each call in apphost.cs adds a resource to the Aspire dashboard',
  desc:
    'Left, a region captioned apphost.cs holds three calls in code font: AddDaprComponent, '
    + 'AddDotnetProject with .WithDaprSidecar on a second line, and AddExecutable. Right, a region '
    + 'captioned Aspire dashboard holds the resources they add. An arrow runs from AddDaprComponent '
    + 'to a document mark named statestore, from AddDotnetProject and .WithDaprSidecar to a green '
    + 'hexagon named engineering with a Dapr sidecar named engineering-dapr, and from AddExecutable '
    + 'to a box named dev-dashboard.',

  build() {
    const appLeft = APP_X - hexHalfWidth(APP_R);
    return [
      region({
        x: L_L, y: TOP, w: L_R - L_L, h: BOTTOM - TOP,
        caption: 'apphost.cs', captionSize: TEXT, captionW: L_CAPTION_W,
      }),
      region({
        x: R_L, y: TOP, w: R_R - R_L, h: BOTTOM - TOP,
        caption: 'Aspire dashboard', captionSize: TEXT, captionW: R_CAPTION_W,
      }),

      codeBox(ROW1, CODE_H, 'AddDaprComponent'),
      codeBox(APP_Y, CODE2_H, 'AddDotnetProject\n.WithDaprSidecar'),
      codeBox(ROW3, CODE_H, 'AddExecutable'),

      arrow({ from: [CODE_X + CODE_W / 2 + G, ROW1], to: [RES_X - DOC * 0.4 - G - 2, ROW1] }),
      arrow({ from: [CODE_X + CODE_W / 2 + G, APP_Y], to: [appLeft - G, APP_Y] }),
      arrow({ from: [CODE_X + CODE_W / 2 + G, ROW3], to: [RES_X - DD_W / 2 - G, ROW3] }),

      group([
        icon({ name: 'fluent-document', x: RES_X, y: ROW1, size: DOC, color: C.navy, fit: 'ink' }),
        label({ x: RES_X + DOC * 0.4 + 8, y: ROW1, text: 'statestore', size: TEXT, anchor: 'start' }),
      ]),

      appSidecar({ x: APP_X, y: APP_Y, r: APP_R, label: 'engineering', size: TEXT, ...APP[0] }),
      label({ x: SIDE.x, y: SIDE_NAME_Y, text: 'engineering-dapr', size: TEXT }),

      box({ x: RES_X, y: ROW3, w: DD_W, h: DD_H, label: 'dev-dashboard', size: TEXT }),
    ];
  },
};
