// dapr-101 page 5 (the Pub/Sub API), section 3 "Inspect the content of the
// `pubsub.yaml` file", at the end: checkout-sdk publishes to the topic orders
// on the orderpubsub component (Redis) through its sidecar, and
// order-processor-sdk's sidecar delivers each message to its /orders route.
// The sibling of 101-4-invocation: the same two apps in the same places, the
// broker between the sidecars where page 4 had the direct sidecar-to-sidecar
// call.
//
// Elements, with each name as it appears in the demo (university-labs
// dapr-101/<lang>/<demo> at 18d67c0, read in dotnet/PubSub, python/pub-sub,
// java/pub-sub and javascript/pub-sub) and the assignment:
// - checkout-sdk: `appID: checkout-sdk` in every dapr.yaml, no appPort: a
//   console app. Green hexagon (APP[0]), house R 56, as checkout in 101-4.
// - order-processor-sdk: `appID: order-processor-sdk` in every dapr.yaml. Its
//   appPort differs per language (7006 .NET, 6002 Python, 8080 Java, 5002
//   JavaScript), so no port is drawn. The second app, so the light blue
//   hexagon (APP[1]); its 19-letter app ID needs R 92 (101-4's
//   order-processor, 15 letters, had R 76).
// - Dapr sidecar (two): markHex with the Dapr logo at the house sidecar size,
//   each apart from its app and named "Dapr sidecar" above it, as in 101-4.
//   No sidecar ports: dapr.yaml sets no daprHTTPPort.
// - orderpubsub: resources/pubsub.yaml in every language, `name: orderpubsub`,
//   `type: pubsub.redis`, drawn as the Redis mark with the component name
//   under it (as pubsub in pubsub-1-demo).
// - orders: the topic, the label of the arrow into the broker, as in
//   pubsub-1-demo (`PublishEventAsync("orderpubsub", "orders", order)` in .NET
//   checkout/Program.cs, `publish_event(pubsub_name='orderpubsub',
//   topic_name='orders', ...)` in Python checkout/app.py).
//
// Connections:
// - checkout-sdk -> its own sidecar, labelled "publish" (the SDK's
//   PublishEvent / publish_event call, section 4 of the page).
// - checkout-sdk's sidecar -> orderpubsub, labelled orders (the topic).
// - orderpubsub -> order-processor-sdk's sidecar (delivery to the subscriber).
// - order-processor-sdk's sidecar -> order-processor-sdk, labelled
//   `POST /orders`: `app.MapPost("/orders", [Topic("orderpubsub", "orders")]
//   ...)` in .NET order-processor/Program.cs, `'route': 'orders'` plus
//   `@app.route('/orders', methods=['POST'])` in Python order-processor/app.py,
//   `@Topic(name = "orders", pubsubName = "orderpubsub")` on
//   `@PostMapping(path = "/orders")` in Java. (JavaScript's
//   `server.pubsub.subscribe(pubSubName, pubSubTopic, cb)` names no route; the
//   page's section 5 says all four have an /orders endpoint.)
// No reply arrow, no step discs: as in 101-4.
//
// Layout: canvas 490 wide for the 424 px lab column, the columns of 101-4.
// Top row: sidecar, Redis, sidecar (three shapes). Bottom row: each app under
// its own sidecar. checkout-sdk's label sits right of its vertical arrow, the
// route right of order-processor-sdk's arrow, as in 101-4.
import { APP, C } from '../_engine/engine.mjs';
import { arrow, group, hex, hexHalfWidth, label } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13; // every label, as in 101-2, 101-3, 101-4 and the secrets, pubsub and bindings scenes

const W = 490;
const M = 12; // canvas margin, as in the secrets and 101 scenes
const GLYPH = 0.37 * TEXT; // half a label's cap height
const CLEAR = 2; // an arrow's end this far off the shape it meets (the engine's own gap)

const APP_R = 56; // checkout-sdk, the house app radius
const OP_R = 92; // order-processor-sdk: its 19-letter name needs it
const SIDE_R = 0.75 * APP_R; // the house sidecar size, both sidecars
const APP_HW = hexHalfWidth(APP_R);
const SIDE_HW = hexHalfWidth(SIDE_R);

const MARK = 36; // the Redis mark, as in the secrets, pubsub and 101-3 scenes
const BROKER_NAME_DY = MARK / 2 + 14; // "orderpubsub" under the mark, as in pubsub-1-demo

const LABEL_GAP = 12; // an arrow's label this far from its arrow (about one character clear)

// Columns copied from 101-4 so the two pages line up: there the pitch held
// "dapr-app-id: order-processor" (219) between the columns, and the right
// column's route "POST /orders" (94) set the group's right edge.
const PITCH = LABEL_GAP + 219 + 60; // column to column
const ROUTE_W = 94; // "POST /orders", measured with measure-labels at 13 (weight 600, mono)
const GROUP_L = APP_HW;
const GROUP_R = LABEL_GAP + ROUTE_W;
const X1 = (W - (GROUP_L + PITCH + GROUP_R)) / 2 + GROUP_L;
const X2 = X1 + PITCH;
const XB = (X1 + X2) / 2; // the broker, midway between the sidecars

// Rows.
const SIDE_NAME_DY = SIDE_R + 14; // "Dapr sidecar" above each sidecar, as in 101-4
const Y1 = M + SIDE_NAME_DY + GLYPH; // sidecars and broker
const ROW_GAP = 180; // sidecar row to app row: 101-4's 160 plus room for the larger order-processor-sdk hexagon
const Y2 = Y1 + ROW_GAP; // apps
const H = Math.ceil(Y2 + OP_R + M);

export default {
  width: W,
  height: H,
  title: 'checkout-sdk publishes to order-processor-sdk through Redis',
  desc:
    'Top row: a Dapr sidecar, a Redis mark labelled orderpubsub and a second Dapr sidecar. Bottom row: '
    + 'a green hexagon labelled checkout-sdk under the left sidecar and a blue hexagon labelled '
    + 'order-processor-sdk under the right one. An arrow labelled publish runs from checkout-sdk up to '
    + 'its sidecar, an arrow labelled orders runs from that sidecar to orderpubsub, an arrow runs from '
    + 'orderpubsub to the right sidecar, and an arrow labelled POST /orders runs from there down to '
    + 'order-processor-sdk.',

  build() {
    const side1 = { x: X1, y: Y1, r: SIDE_R, hex: true };
    const side2 = { x: X2, y: Y1, r: SIDE_R, hex: true };
    const checkout = { x: X1, y: Y2, r: APP_R, hex: true };
    const op = { x: X2, y: Y2, r: OP_R, hex: true };

    const mid1 = (Y1 + SIDE_R + Y2 - APP_R) / 2; // checkout-sdk's vertical run
    const mid2 = (Y1 + SIDE_R + Y2 - OP_R) / 2; // order-processor-sdk's vertical run
    const brokerL = XB - MARK / 2 - CLEAR;
    const brokerR = XB + MARK / 2 + CLEAR;
    const side1R = X1 + SIDE_HW + CLEAR;

    return [group([
      // checkout-sdk publishes through its own sidecar.
      arrow({ from: checkout, to: side1 }),
      label({ x: X1 + LABEL_GAP, y: mid1, text: 'publish', size: TEXT, anchor: 'start' }),

      // The sidecar publishes to the topic orders on orderpubsub.
      arrow({ from: [side1R, Y1], to: [brokerL, Y1] }),
      label({ x: (side1R + brokerL) / 2, y: Y1 - LABEL_GAP, text: 'orders', size: TEXT }),

      // orderpubsub delivers to order-processor-sdk's sidecar.
      arrow({ from: [brokerR, Y1], to: [X2 - SIDE_HW - CLEAR, Y1] }),

      // order-processor-sdk's sidecar passes the message to the app's route.
      arrow({ from: side2, to: op }),
      label({ x: X2 + LABEL_GAP, y: mid2, text: 'POST /orders', size: TEXT, anchor: 'start', mono: true }),

      markHex({ x: X1, y: Y1, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      label({ x: X1, y: Y1 - SIDE_NAME_DY, text: 'Dapr sidecar', size: TEXT }),
      icon({ name: 'redis', x: XB, y: Y1, size: MARK, fit: 'ink', color: C.redisBrand }),
      label({ x: XB, y: Y1 + BROKER_NAME_DY, text: 'orderpubsub', size: TEXT }),
      markHex({ x: X2, y: Y1, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      label({ x: X2, y: Y1 - SIDE_NAME_DY, text: 'Dapr sidecar', size: TEXT }),
      hex({ x: X1, y: Y2, r: APP_R, label: 'checkout-sdk', size: TEXT, ...APP[0] }),
      hex({ x: X2, y: Y2, r: OP_R, label: 'order-processor-sdk', size: TEXT, ...APP[1] }),
    ])];
  },
};
