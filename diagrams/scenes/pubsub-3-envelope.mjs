// dapr-pubsub page 3 (CloudEvents and raw payloads), section 1 "Two subscriptions on
// one subscriber": what a subscriber receives. A data-shape diagram, not an app/sidecar
// picture: the CloudEvent envelope next to the raw payload.
//
// Elements, with each name as it appears in the assignment's expected output (step 3
// and step 4 logs) and the demo (university-labs at 37fccac,
// pubsub/<lang>/demo3-cloud-events, order-api read in dotnet and python):
// - CloudEvent: the envelope card. Its keys in the order the step 3 log prints them:
//   `data` (with its nested box), then `id`, `pubsubname`, `source`, `specversion`,
//   `topic`, `traceparent`, `type`, and a "…" line for the ones left out
//   (`datacontenttype`, `time`, `traceid`, `tracestate`). The shown keys cover all three
//   groups the assignment explains (identity, trace context, where it travelled).
// - data: the nested box holding the order, `orderId: o-3001` (the step 3 order) and
//   "…" for item, quantity and priority (Order record: orderId, item, quantity, priority).
// - raw payload: the same box drawn alone, `orderId: o-3002` (the step 4 order, published
//   with the metadata rawPayload "true"): the subscriber gets the order and nothing else.
//
// Connections: none. The two boxes of the order are the same size and style and sit on
// one row, so the raw payload reads as the data box without its envelope.
//
// Layout: canvas 490 wide for the 424 px lab column. Keys and payload lines are mono at
// TEXT, set from the left like code.
import { C } from '../_engine/engine.mjs';
import { box, codeCard, group, label } from '../_engine/shapes.mjs';

const TEXT = 13;

const W = 490;
const M = 12;
const EDGE = 2;

// Caption above each card, bold like codeCard's title.
const TITLE_DY = 16;

// The order box (data, and the raw payload): two mono lines, about 15 characters wide
// (7.8 units a character at 13), with padding.
const BOX_W = 150;
const BOX_H = 52;
const BOX_PAD = 12;

// The envelope card: the box inset by INSET on each side, keys lined up with the box.
const INSET = 20;
const CARD_W = BOX_W + 2 * INSET;
const CARD_X = M + EDGE + CARD_W / 2;
const CARD_L = CARD_X - CARD_W / 2;
const CARD_TOP = M + 32; // room for the caption above

const LINE = 20; // key line pitch
const DATA_Y = CARD_TOP + 22; // the `data` key
const BOX_TOP = DATA_Y + 12;
const BOX_Y = BOX_TOP + BOX_H / 2;
const KEYS = ['id', 'pubsubname', 'source', 'specversion', 'topic', 'traceparent', 'type', '…'];
const KEY0_Y = BOX_TOP + BOX_H + 22;
const CARD_BOTTOM = KEY0_Y + (KEYS.length - 1) * LINE + 20;
const CARD_H = CARD_BOTTOM - CARD_TOP;
const H = CARD_BOTTOM + M + EDGE;

// The raw payload: same box, same row as the data box, centred in the space on the right.
const RAW_X = (CARD_L + CARD_W + W) / 2;

const orderBox = (cx, id) => [
  box({ x: cx, y: BOX_Y, w: BOX_W, h: BOX_H, stroke: C.blue, fill: C.blueFill }),
  label({
    x: cx - BOX_W / 2 + BOX_PAD, y: BOX_Y, text: `orderId: ${id}\n…`,
    size: TEXT, weight: 400, mono: true, anchor: 'start',
  }),
];

export default {
  width: W,
  height: H,
  title: 'A CloudEvent and a raw payload',
  desc:
    'Left, a card captioned CloudEvent lists the keys data, id, pubsubname, source, specversion, '
    + 'topic, traceparent, type and more; under data a blue box holds the order, orderId o-3001. '
    + 'Right, captioned raw payload, the same blue box stands alone with orderId o-3002: the order '
    + 'without the envelope.',

  build() {
    const keyX = CARD_L + INSET;
    return [group([
      codeCard({ x: CARD_X, y: CARD_TOP + CARD_H / 2, w: CARD_W, h: CARD_H, title: 'CloudEvent', titleSize: TEXT, titleDy: TITLE_DY }),
      label({ x: keyX, y: DATA_Y, text: 'data', size: TEXT, weight: 400, mono: true, anchor: 'start' }),
      ...orderBox(CARD_X, 'o-3001'),
      ...KEYS.map((k, i) => label({
        x: keyX, y: KEY0_Y + i * LINE, text: k, size: TEXT, weight: 400, mono: true, anchor: 'start',
      })),

      label({ x: RAW_X, y: BOX_TOP - TITLE_DY, text: 'raw payload', size: TEXT, weight: 700 }),
      ...orderBox(RAW_X, 'o-3002'),
    ])];
  },
};
