// dapr-bindings page 1 (cron input binding), section 1 "What is a binding?":
// the two directions of a binding, side by side as two stacked rows.
//
// This is the concept, not the cron demo: page 1 introduces bindings before
// the warp-core-scan component appears, so the outside system is generic.
//
// Elements, with each name as it appears in the assignment
// (dapr-bindings/1-cron-input-binding/assignment.md, section 1):
// - "Input binding" and "Output binding": the two directions, from the bullets
//   "An **input binding** lets the outside system call your app" and "An
//   **output binding** lets your app call the outside system". Each is a row
//   captioned on its border.
// - external system: the outside system ("a schedule, a database, a queue, a
//   mail server"). A generic Fluent server mark in the house blue with its name
//   under it, because an external system is a blue mark, never a filled shape
//   (REFERENCE.md, Colors). The Bindings API tile is not used for it: that
//   tile is Dapr's API, which lives in the sidecar, not the outside system.
// - Dapr sidecar: "connects an app to such a system through its Dapr sidecar".
//   A markHex with the Dapr logo, as in workflow-101-1-architecture.
// - app: the app, a solid green hexagon (APP[0]) with "app" on it. No app ID:
//   the page's app (engineering) belongs to the demo in section 2.
//
// Connections:
// - Input binding: external system -> Dapr sidecar -> app ("the sidecar sends
//   an HTTP request to your app").
// - Output binding: app -> Dapr sidecar -> external system ("The app sends a
//   request to its sidecar ... and the sidecar passes it on").
//
// The two rows are drawn from one function with the same positions, so the
// arrow direction is the only thing that differs between them.
//
// Departures from the skill, on purpose:
// - The sidecar stands apart from the app instead of overlapping it
//   (appSidecar()), because the point of the picture is the hop between the
//   app and its sidecar, which needs a visible arrow. The sidecar keeps the
//   house size relation to the app (0.75 of the radius).
// - Canvas 480 wide for the 424 px lab column (not 16:9 at 1100+ units).
import { APP, C } from '../_engine/engine.mjs';
import { arrow, captionPad, captionReach, group, hex, hexHalfWidth, label, region } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13; // every label and caption in the scene, as in the PR 1 scenes

const W = 480;
const M = 12; // canvas margin

// Shapes in a row, sized against the app.
const APP_R = 44; // the house app radius (42.5 to 60), a little up for "app" at 13
const SIDE_R = 0.75 * APP_R; // the house sidecar size relation (SIDECAR_R)
const MARK = 44; // the external system's mark, fitted by its ink (its height)
const MARK_W = MARK * 12 / 20; // the server glyph's ink is 12 x 20 (_engine/icons/ink.json), so arrows stop at its drawn side
const NAME_DY = SIDE_R + 16; // a name under its shape; the mark's name copies the sidecar's so both sit on one line
const GLYPH = 0.37 * TEXT; // a label's glyph top above (and descent below) its y
const RUN = 84; // arrow length between shape edges (30 to 110)

// Centres along a row, from the left: the mark, the sidecar, the app. The
// widest thing on the left is the mark's name, so the group's left edge is
// half of that.
const EXT_NAME_W = 101; // "external system", measured at 13 (weight 600)
const EXT_TO_SIDE = MARK_W / 2 + RUN + hexHalfWidth(SIDE_R);
const SIDE_TO_APP = hexHalfWidth(SIDE_R) + RUN + hexHalfWidth(APP_R);
const GROUP_L = EXT_NAME_W / 2;
const GROUP_R = EXT_TO_SIDE + SIDE_TO_APP + hexHalfWidth(APP_R);
const EXT_X = W / 2 - (GROUP_L + GROUP_R) / 2 + GROUP_L; // the group centred on the canvas
const SIDE_X = EXT_X + EXT_TO_SIDE;
const APP_X = SIDE_X + SIDE_TO_APP;

// A row: a dashed region captioned on its top border, the three shapes centred
// in what the pill leaves. The group runs from the app's top point to the
// bottom of the names.
const REACH = captionReach();
const GROUP_T = APP_R;
const GROUP_B = NAME_DY + GLYPH;
const PAD_Y = 14; // between the group and the pill's lower edge, and the region's bottom
const ROW_H = REACH + PAD_Y + GROUP_T + GROUP_B + PAD_Y;
const ROW_GAP = 16 + REACH; // clear space between the rows, plus the lower pill's reach
const ROW_X = M;
const ROW_W = W - 2 * M;

// Measured with measure-labels (weight 600 at 13), plus captionPad at each end.
const pillW = (textW) => Math.ceil(textW + 2 * captionPad(TEXT));
const INPUT_W = pillW(83);
const OUTPUT_W = pillW(94);

const TOP_Y = M + REACH; // the upper pill keeps the margin too
const ROW1 = { x: ROW_X, y: TOP_Y, w: ROW_W, h: ROW_H };
const ROW2 = { x: ROW_X, y: TOP_Y + ROW_H + ROW_GAP, w: ROW_W, h: ROW_H };
const H = ROW2.y + ROW2.h + M;

// The row's centre line: the group centred between the pill's lower edge and
// the region's bottom, shifted by the group's own asymmetry.
const centreY = (row) => (row.y + REACH + row.y + row.h) / 2 - (GROUP_B - GROUP_T) / 2;

function row({ box, caption, captionW, inward }) {
  const y = centreY(box);
  const ext = { x: EXT_X, y, w: MARK_W, h: MARK };
  const side = { x: SIDE_X, y, r: SIDE_R, hex: true };
  const app = { x: APP_X, y, r: APP_R, hex: true };
  // inward: the external system calls the app; otherwise the app calls out.
  const hops = inward ? [[ext, side], [side, app]] : [[app, side], [side, ext]];
  return group([
    region({ ...box, caption, captionW, captionSize: TEXT }),
    hops.map(([from, to]) => arrow({ from, to })),
    icon({ name: 'fluent-server', x: EXT_X, y, size: MARK, color: C.blue, fit: 'ink' }),
    label({ x: EXT_X, y: y + NAME_DY, text: 'external system', size: TEXT }),
    markHex({ x: SIDE_X, y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
    label({ x: SIDE_X, y: y + NAME_DY, text: 'Dapr sidecar', size: TEXT }),
    hex({ x: APP_X, y, r: APP_R, label: 'app', size: TEXT, ...APP[0] }),
  ]);
}

export default {
  width: W,
  height: H,
  title: 'The two directions of a Dapr binding',
  desc:
    'Two rows with the same three parts in the same places: an external system on the left, '
    + 'a Dapr sidecar in the middle and a green hexagon labelled app on the right. In the row '
    + 'captioned Input binding, the arrows run from the external system to the sidecar and from '
    + 'the sidecar to the app. In the row captioned Output binding, they run the other way, from '
    + 'the app to the sidecar and from the sidecar to the external system.',

  build() {
    return [
      row({ box: ROW1, caption: 'Input binding', captionW: INPUT_W, inward: true }),
      row({ box: ROW2, caption: 'Output binding', captionW: OUTPUT_W, inward: false }),
    ];
  },
};
