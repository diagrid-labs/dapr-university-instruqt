// dapr-pubsub page 4 (bulk messages), section 1 "Bulk publish and bulk subscribe":
// one bulk publish of 25 orders, delivered to shipping in batches of at most 10, and
// answered with one status per entry.
//
// Elements, with each name as it appears in the demo (university-labs at 37fccac,
// pubsub/<lang>/demo4-bulk, read in dotnet, python and java) and the assignment:
// - order-api: the publisher, the green hexagon (APP[0]) with its Dapr sidecar docked,
//   as in pubsub-1-demo and pubsub-2-streaming (dapr.yaml appID `order-api`, appPort 5101).
//   Its /orders/bulk endpoint publishes all orders in one call (BulkPublishEventAsync,
//   publish_events, publishEvents); the assignment's curl asks for count=25.
// - pubsub: the pub/sub component (../resources/pubsub.yaml, `type: pubsub.redis`),
//   the Redis mark with the component name under it.
// - shipping: the light blue hexagon (APP[1]), appID `shipping`, appPort 5102, with its
//   sidecar drawn apart from it: the delivery request and its reply are the point.
//
// Connections:
// - order-api's sidecar -> pubsub, labelled "bulk publish" / "25 orders" (one call).
// - pubsub -> shipping's sidecar (unlabelled): the broker hands the orders over; the
//   sidecar collects them, because bulkSubscribe is a setting of shipping's subscription.
//   "≤ 10 or 1000 ms" sits under that sidecar (subscription-bulk.yaml: maxMessagesCount
//   10, maxAwaitDurationMs 1000, identical in all three languages).
// - shipping sidecar -> shipping app on /orders/bulk (routes.default; the app's only
//   route). The batches are these requests, so the three pills 10, 10 and 5 sit above this
//   arrow's label (the batches the assignment's step 4 log shows with Redis; pill width
//   follows the count).
// - shipping app -> sidecar, labelled "statuses": the response body of that request,
//   {"statuses": [{"entryId", "status"}, ...]}, one per entry. The code returns SUCCESS
//   or DROP; the label names the field rather than one value, so it stays true for both.
//
// Layout: canvas 490 wide for the 424 px lab column, the same radii and rows as
// pubsub-2-streaming; shipping's sidecar moved left (240) so the run to the app holds
// "/orders/bulk" with the pills above it. The publish label sits right of its arrow,
// where the canvas is empty, because "bulk publish" does not fit left of it.
import { APP, C } from '../_engine/engine.mjs';
import { arrow, group, hex, hexHalfWidth, label, pill } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13; // every label, as in the other pubsub scenes

const W = 490;
const M = 12;
const EDGE = 2;

const APP_R = 56;
const SIDE_R = 0.75 * APP_R;
const APP_HW = hexHalfWidth(APP_R);
const SIDE_HW = hexHalfWidth(SIDE_R);

// order-api's docked sidecar, copied from pubsub-2-streaming.
const DOCK_DX = 0.75 * APP_R;
const DOCK_DY = 0.7 * APP_R;
const NAME_DY = -12;
const NAME_DX = 6;

const PUB_X = M + EDGE + APP_HW;
const PUB_SIDE_X = PUB_X + DOCK_DX;
const BROKER_X = PUB_SIDE_X;
const SUB_X = W - M - EDGE - APP_HW;
const SIDE_X = 240; // leaves the sidecar -> app run room for "/orders/bulk" and the batches above it

const PUB_Y = M + APP_R;
const ROW_Y = 220; // broker, shipping sidecar and app share one row
const BROKER_Y = ROW_Y;
const RULE_DY = SIDE_R + 14; // "≤ 10 or 1000 ms" under shipping's sidecar
const H = ROW_Y + RULE_DY + 8 + M;

const MARK = 36;
const BROKER_NAME_DY = MARK / 2 + 14;

const LABEL_GAP = 12;
const PAIR_DY = 14; // request and reply, above and below the row's centre line

// The batches: one pill per request to /orders/bulk, width by message count, stacked
// above that request's label (clear of both hexagons' upper edges at that height).
const BATCH_H = 20;
const BATCH_DY = 50; // the pills' centre above the row's centre line
const BATCH_GAP = 4;
const BATCH_W = { 10: 30, 5: 20 };
const BATCHES = [10, 10, 5];

export default {
  width: W,
  height: H,
  title: 'Bulk publish and bulk subscribe',
  desc:
    'A green hexagon labelled order-api with a Dapr sidecar sends one bulk publish of 25 orders to '
    + 'a Redis mark labelled pubsub. From pubsub an arrow runs to the Dapr sidecar of a blue hexagon '
    + 'labelled shipping, with three pills above it labelled 10, 10 and 5 and the label at most 10 '
    + 'or 1000 ms below it. The sidecar calls the shipping app on /orders/bulk, and an arrow labelled '
    + 'statuses runs back from the app to the sidecar.',

  build() {
    const pubSide = { x: PUB_SIDE_X, y: PUB_Y + DOCK_DY, r: SIDE_R, hex: true };
    const pubArrowTop = pubSide.y + SIDE_R + 2;
    const pubArrowBottom = BROKER_Y - MARK / 2 - 2;
    const pubMid = (pubArrowTop + pubArrowBottom) / 2;

    const runL = SIDE_X + SIDE_HW + 2;
    const runR = SUB_X - APP_HW - 2;
    const runX = (runL + runR) / 2;

    const widths = BATCHES.map((b) => BATCH_W[b]);
    const total = widths.reduce((s, w) => s + w, 0) + BATCH_GAP * (BATCHES.length - 1);
    const batchY = ROW_Y - BATCH_DY;
    let bx = runX - total / 2;
    const batches = BATCHES.map((b, i) => {
      const w = widths[i];
      const p = pill({ x: bx + w / 2, y: batchY, w, h: BATCH_H, text: String(b), size: TEXT, color: C.navy });
      bx += w + BATCH_GAP;
      return p;
    });

    return [group([
      // One bulk publish of 25 orders.
      arrow({ from: [BROKER_X, pubArrowTop], to: [BROKER_X, pubArrowBottom] }),
      label({ x: BROKER_X + LABEL_GAP, y: pubMid, text: 'bulk publish\n25 orders', size: TEXT, anchor: 'start' }),

      // The broker hands the orders to shipping's sidecar, which collects them into batches.
      arrow({ from: [BROKER_X + MARK / 2 + 2, ROW_Y], to: [SIDE_X - SIDE_HW - 2, ROW_Y] }),
      label({ x: SIDE_X, y: ROW_Y + RULE_DY, text: '≤ 10 or 1000 ms', size: TEXT }),

      // One request per batch, answered with one status per entry.
      ...batches,
      arrow({ from: [runL, ROW_Y - PAIR_DY], to: [runR, ROW_Y - PAIR_DY] }),
      label({ x: runX, y: ROW_Y - PAIR_DY - LABEL_GAP, text: '/orders/bulk', size: TEXT }),
      arrow({ from: [runR, ROW_Y + PAIR_DY], to: [runL, ROW_Y + PAIR_DY] }),
      label({ x: runX, y: ROW_Y + PAIR_DY + LABEL_GAP, text: 'statuses', size: TEXT }),

      hex({ x: PUB_X, y: PUB_Y, r: APP_R, label: 'order-api', size: TEXT, labelDy: NAME_DY, labelDx: -NAME_DX, ...APP[0] }),
      markHex({ x: PUB_SIDE_X, y: pubSide.y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),

      icon({ name: 'redis', x: BROKER_X, y: BROKER_Y, size: MARK, fit: 'ink', color: C.redisBrand }),
      label({ x: BROKER_X, y: BROKER_Y + BROKER_NAME_DY, text: 'pubsub', size: TEXT }),

      markHex({ x: SIDE_X, y: ROW_Y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      hex({ x: SUB_X, y: ROW_Y, r: APP_R, label: 'shipping', size: TEXT, ...APP[1] }),
    ])];
  },
};
