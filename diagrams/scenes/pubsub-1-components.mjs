// dapr-pubsub page 1 (subscription types), section 1 "Why pub/sub?": with Dapr
// no app talks to the broker; each app's Dapr sidecar does, and a component
// YAML file says which broker that is. A redraw of the opaque white
// pubsub-components.png that was on the page, for the narrow dark column.
//
// This is a generic picture, not the demo, so the labels are the ones of the
// original image and of the page's alt text (Cart, Shipping, Email).
//
// Elements, with each name as the original image shows it:
// - Cart: the publisher, the green hexagon (APP[0]), as in pubsub-1-pattern.
// - Dapr sidecar (three): markHex with the Dapr logo, one per app.
// - component YAML (three): the Fluent document mark under each sidecar, as
//   the original drew a document under each one. Named once, under the Cart
//   sidecar's document (REFERENCE.md: say a repeated element once).
// - Pub/Sub brokers: a captioned region holding a short list of the four
//   brokers the original shows, each with its shipped mark and its name:
//   Redis (`redis`, tinted C.redisBrand), NATS (`nats`), Azure Service Bus
//   (`azure-service-bus`), RabbitMQ (`rabbitmq`), then "+11 more".
// - Shipping: the light blue hexagon (APP[1]), the subscriber colour of
//   pubsub-1-pattern and the blue of the original.
// - Email: the gold hexagon (APP[2]), gold as in the original.
//
// Connections, as in the original: Cart's sidecar -> the brokers; the brokers
// -> the Shipping sidecar and -> the Email sidecar. Each sidecar uses its
// component YAML (a short plain line down to the document).
//
// Departures from the original and the skill, on purpose:
// - The original is three dashed lanes side by side, seven shapes wide. The
//   column allows at most three shapes in a row, so each app's sidecar is
//   docked on the app (as in workflow-101-1-architecture) rather than drawn
//   apart with an arrow: Cart on the left, the brokers in the middle, Shipping
//   above Email on the right. The sidecar still sits between every app and
//   the brokers, on the side that faces them.
// - The Publish and Subscribe lanes are dropped: the arrows carry the
//   direction. The broker lane stays, as the region "Pub/Sub brokers".
// - The four broker marks are a list (mark left, name right) rather than a
//   column of marks with names under them, to keep the region narrow.
//   "Azure Service Bus" is on two lines for the same reason.
// - The marks are not plated: Redis is tinted and the other three are full
//   colour on the dark ground, which the preview shows legible; a plate per
//   mark would put four light blocks in a narrow column.
// - The docked sidecars are 0.75 of the app radius (the house relation) and
//   sit low enough (0.9 of the app radius below its centre) that each app's
//   name stays centred in its hexagon.
// - Canvas 490 wide for the 424 px lab column (not 16:9 at 1100+ units).
import { APP, C } from '../_engine/engine.mjs';
import { arrow, group, hex, hexHalfWidth, label, region } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13; // every label in the scene, as in pubsub-1-pattern

const W = 490;
const M = 12; // canvas margin
const EDGE = 2; // an app hexagon's outer point stays this far inside the margin

const APP_R = 56; // the house app radius, as in pubsub-1-pattern
const SIDE_R = 0.75 * APP_R; // the house sidecar size
const DOCK_DX = 0.75 * APP_R; // sidecar centre beside the app centre
const DOCK_DY = 0.9 * APP_R; // and below it, low enough that the app name sits centred in the hexagon

const APP_HW = hexHalfWidth(APP_R);
const SIDE_HW = hexHalfWidth(SIDE_R);

// Columns: Cart against the left margin with its sidecar on its right; the
// two subscribers against the right margin with their sidecars on their left.
const CART_X = M + EDGE + APP_HW;
const SUB_X = W - M - EDGE - APP_HW;
const CART_SIDE_X = CART_X + DOCK_DX;
const SUB_SIDE_X = SUB_X - DOCK_DX;

// Rows: Shipping on top, Email below it. PITCH keeps the Shipping sidecar's
// document clear of the Email hexagon's sloping top edge below it.
const PITCH = 162;
const Y1 = M + APP_R; // Shipping
const Y2 = Y1 + PITCH; // Email
const CART_Y = (Y1 + Y2) / 2; // Cart, centred between them

// The component YAML under each sidecar: a short line, then the document.
const DOC = 22; // the document mark's height (fit by ink, 16 x 20)
const DOC_GAP = 10; // the line from the sidecar's bottom point to the document
const DOC_DY = DOCK_DY + SIDE_R + DOC_GAP + DOC / 2; // document centre below its app centre
const DOC_NAME_DY = DOC / 2 + 12; // "component YAML" under the Cart document

// The brokers region: centred between the two columns. Each entry is a mark
// with its name to its right. LIST_W is the mark, the gap and the widest name
// ("Service Bus", measured at 13, weight 600, about 80), plus PAD each side.
const MARK = 22;
const MARK_GAP = 8;
const PAD = 14;
const NAME_W = 80;
const REG_W = PAD + MARK + MARK_GAP + NAME_W + PAD;
const REG_X = (CART_SIDE_X + SIDE_HW + SUB_SIDE_X - SIDE_HW) / 2;
const REG_L = REG_X - REG_W / 2;
const REG_R = REG_X + REG_W / 2;
const MARK_X = REG_L + PAD + MARK / 2;
const NAME_X = REG_L + PAD + MARK + MARK_GAP;

// The list, top to bottom. A two-line name takes a little more room.
const ROW = 47; // row pitch: tall enough that the region reaches below the Email arrow
const LINE = TEXT * 1.2;
const BROKERS = [
  { name: 'redis', text: 'Redis', color: C.redisBrand },
  { name: 'nats', text: 'NATS' },
  { name: 'azure-service-bus', text: 'Azure\nService Bus' },
  { name: 'rabbitmq', text: 'RabbitMQ' },
];
const LIST_H = ROW * BROKERS.length + LINE; // four rows (one of them two lines) and the "+11 more" line
const REG_T = 52; // the caption pill (26 tall) is centred on this edge; lowered with the docked sidecars so the list stays level with the arrows
const LIST_TOP = REG_T + 30; // the first entry's centre, under the caption pill
const REG_B = LIST_TOP + LIST_H + 14;
// Both subscriber arrows must leave the region's side, not run past its corner.
if (REG_B - (Y2 + DOCK_DY) < 14) throw new Error('pubsub-1-components: the Email arrow runs below the brokers region');

const H = Math.ceil(Y2 + DOC_DY + DOC / 2 + M);

export default {
  width: W,
  height: H,
  title: 'Pub/sub through Dapr sidecars and a component YAML file',
  desc:
    'On the left a green hexagon labelled Cart with a Dapr sidecar on its right side. An arrow runs '
    + 'from the sidecar to a region labelled Pub/Sub brokers that lists Redis, NATS, Azure Service Bus '
    + 'and RabbitMQ, each with its logo, and +11 more. From the region one arrow runs to the Dapr '
    + 'sidecar of a blue hexagon labelled Shipping and another to the Dapr sidecar of a gold hexagon '
    + 'labelled Email, on the right. Under each of the three sidecars is a document mark, the first '
    + 'one named component YAML.',

  build() {
    let y = LIST_TOP;
    const entries = BROKERS.map((b) => {
      const lines = b.text.split('\n').length;
      const cy = y + ((lines - 1) * LINE) / 2;
      y += ROW + (lines - 1) * LINE;
      return group([
        icon({ name: b.name, x: MARK_X, y: cy, size: MARK, fit: 'ink', ...(b.color ? { color: b.color } : {}) }),
        label({ x: NAME_X, y: cy, text: b.text, size: TEXT, anchor: 'start' }),
      ]);
    });
    const moreY = y - ROW / 2 + LINE / 2;

    const cartSide = { x: CART_SIDE_X, y: CART_Y + DOCK_DY };
    const subs = [
      { x: SUB_X, y: Y1, text: 'Shipping', fill: APP[1] },
      { x: SUB_X, y: Y2, text: 'Email', fill: APP[2] },
    ];

    // A sidecar's short line down to its document, and the document.
    const yaml = (sx, appY) => [
      arrow({ from: [sx, appY + DOCK_DY + SIDE_R + 1], to: [sx, appY + DOC_DY - DOC / 2 - 1], head: false, gap: 0 }),
      icon({ name: 'fluent-document', x: sx, y: appY + DOC_DY, size: DOC, color: C.navy, fit: 'ink' }),
    ];

    return [group([
      region({ x: REG_L, y: REG_T, w: REG_W, h: REG_B - REG_T, caption: 'Pub/Sub brokers', captionSize: TEXT, captionW: 120, captionX: REG_X }),
      ...entries,
      label({ x: REG_X, y: moreY, text: '+11 more', size: TEXT, color: C.caption }),

      arrow({ from: [CART_SIDE_X + SIDE_HW + 2, cartSide.y], to: [REG_L - 2, cartSide.y] }),
      ...subs.map((s) => arrow({ from: [REG_R + 2, s.y + DOCK_DY], to: [SUB_SIDE_X - SIDE_HW - 2, s.y + DOCK_DY] })),

      hex({ x: CART_X, y: CART_Y, r: APP_R, label: 'Cart', size: TEXT, ...APP[0] }),
      markHex({ x: CART_SIDE_X, y: cartSide.y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      ...yaml(CART_SIDE_X, CART_Y),
      label({ x: CART_SIDE_X, y: CART_Y + DOC_DY + DOC_NAME_DY, text: 'component YAML', size: TEXT }),

      ...subs.flatMap((s) => [
        hex({ x: s.x, y: s.y, r: APP_R, label: s.text, size: TEXT, ...s.fill }),
        markHex({ x: SUB_SIDE_X, y: s.y + DOCK_DY, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
        ...yaml(SUB_SIDE_X, s.y),
      ]),
    ])];
  },
};
