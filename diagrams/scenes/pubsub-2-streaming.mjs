// dapr-pubsub page 2 (streaming subscriptions), section 1 "A subscriber without a
// port": the warehouse app has no port, so it opens the stream to its own sidecar.
//
// Elements, with each name as it appears in the demo (university-labs at
// 37fccac, pubsub/<lang>/demo2-streaming, read in dotnet, python and java):
// - order-api: the publisher, the green hexagon (APP[0]) with its Dapr sidecar
//   docked, as in pubsub-1-demo (dapr.yaml appID `order-api`, appPort 5101).
// - pubsub: the pub/sub component (../resources/pubsub.yaml, `type: pubsub.redis`),
//   the Redis mark with the component name under it.
// - orders: the topic, the label of the publish arrow.
// - warehouse: the light blue hexagon (APP[1]), appID `warehouse`, with NO appPort in
//   dapr.yaml; its sidecar is drawn apart from it, as the subscribers in pubsub-1-demo.
//
// Connections:
// - order-api's sidecar -> pubsub, labelled orders (the publish).
// - pubsub -> the warehouse sidecar (delivery).
// - warehouse app -> its sidecar, labelled subscribe: the app opens the stream
//   (SubscribeAsync, subscribe_with_handler, subscribeToTopic: one call, three names).
// - warehouse sidecar -> app, labelled messages: each order is pushed down that same
//   stream and the app handles it; the app never gets an HTTP call.
//
// Layout: canvas 490 wide for the 424 px lab column. The arrow between app and sidecar
// points app -> sidecar, the reverse of pubsub-1-demo; the two arrows are the one stream.
import { APP, C } from '../_engine/engine.mjs';
import { arrow, group, hex, hexHalfWidth, label } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13;

const W = 490;
const M = 12;
const EDGE = 2;

const APP_R = 56;
const SIDE_R = 0.75 * APP_R;
const APP_HW = hexHalfWidth(APP_R);
const SIDE_HW = hexHalfWidth(SIDE_R);

const DOCK_DX = 0.75 * APP_R;
const DOCK_DY = 0.9 * APP_R; // and below it, low enough that the app name sits centred in the hexagon

const PUB_X = M + EDGE + APP_HW;
const PUB_SIDE_X = PUB_X + DOCK_DX;
const BROKER_X = PUB_SIDE_X;
const SUB_X = W - M - EDGE - APP_HW;
const SIDE_X = 250;

const PUB_Y = M + APP_R;
const ROW_Y = 220; // broker, warehouse sidecar and app share one row
const BROKER_Y = ROW_Y;
const NOPORT_DY = APP_R + 16; // "no port" under the warehouse hexagon
const H = ROW_Y + NOPORT_DY + 12;

const MARK = 36;
const BROKER_NAME_DY = MARK / 2 + 14;

const LABEL_GAP = 12;
const PAIR_DY = 14; // the stream's two arrows, above and below the row's centre line

export default {
  width: W,
  height: H,
  title: 'A streaming subscription',
  desc:
    'A green hexagon labelled order-api with a Dapr sidecar publishes to the topic orders on a Redis '
    + 'mark labelled pubsub. From pubsub an arrow runs to the Dapr sidecar of a blue hexagon labelled '
    + 'warehouse, marked no port. An arrow labelled subscribe runs from the warehouse app to its '
    + 'sidecar, and an arrow labelled messages runs back from the sidecar to the app.',

  build() {
    const pubSide = { x: PUB_SIDE_X, y: PUB_Y + DOCK_DY, r: SIDE_R, hex: true };
    const broker = { x: BROKER_X, y: BROKER_Y, w: MARK, h: MARK };
    const whSide = { x: SIDE_X, y: ROW_Y, r: SIDE_R, hex: true };
    const pubArrowTop = pubSide.y + SIDE_R + 2;
    const pubArrowBottom = BROKER_Y - MARK / 2 - 2;
    const runL = SIDE_X + SIDE_HW + 2;
    const runR = SUB_X - APP_HW - 2;
    const runX = (runL + runR) / 2;

    return [group([
      arrow({ from: [BROKER_X, pubArrowTop], to: [BROKER_X, pubArrowBottom] }),
      label({ x: BROKER_X - LABEL_GAP, y: (pubArrowTop + pubArrowBottom) / 2, text: 'orders', size: TEXT, anchor: 'end' }),

      arrow({ from: broker, to: whSide }),

      // The stream: the app opens it (app -> sidecar), the messages come back over it.
      arrow({ from: [runR, ROW_Y - PAIR_DY], to: [runL, ROW_Y - PAIR_DY] }),
      label({ x: runX, y: ROW_Y - PAIR_DY - LABEL_GAP, text: 'subscribe', size: TEXT }),
      arrow({ from: [runL, ROW_Y + PAIR_DY], to: [runR, ROW_Y + PAIR_DY] }),
      label({ x: runX, y: ROW_Y + PAIR_DY + LABEL_GAP, text: 'messages', size: TEXT }),

      hex({ x: PUB_X, y: PUB_Y, r: APP_R, label: 'order-api', size: TEXT, ...APP[0] }),
      markHex({ x: PUB_SIDE_X, y: pubSide.y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),

      icon({ name: 'redis', x: BROKER_X, y: BROKER_Y, size: MARK, fit: 'ink', color: C.redisBrand }),
      label({ x: BROKER_X, y: BROKER_Y + BROKER_NAME_DY, text: 'pubsub', size: TEXT }),

      markHex({ x: SIDE_X, y: ROW_Y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      hex({ x: SUB_X, y: ROW_Y, r: APP_R, label: 'warehouse', size: TEXT, ...APP[1] }),
      label({ x: SUB_X, y: ROW_Y + NOPORT_DY, text: 'no port', size: TEXT }),
    ])];
  },
};
