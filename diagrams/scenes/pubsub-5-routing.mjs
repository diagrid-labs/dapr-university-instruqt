// dapr-pubsub page 5 (routing and dead letters), section 2 "Retries", at the end: where
// shipping's sidecar sends each order from the topic orders, and how the poison order ends
// up on orders-dead.
//
// Elements, with each name as it appears in the demo (university-labs at 37fccac,
// pubsub/<lang>/demo5-routing-dead-letter, read in dotnet, python and java) and the
// assignment:
// - pubsub: the pub/sub component (../resources/pubsub.yaml, `type: pubsub.redis`), the
//   Redis mark with the component name under it, as in pubsub-1-demo, -2 and -4. Both
//   topics live on it: subscription-orders.yaml and subscription-dead-letter.yaml both say
//   `pubsubname: pubsub`.
// - shipping: the light blue hexagon (APP[1]), appID `shipping`, appPort 5102, with its
//   sidecar drawn apart from it: the routing happens in the sidecar, so the calls between
//   them are the point. order-api is left out: this page is about the subscriber side,
//   and the column has no room for a fourth shape.
//
// Connections:
// - pubsub -> shipping sidecar, labelled orders: the subscription to the topic orders
//   (subscription-orders.yaml).
// - shipping sidecar <-> pubsub, labelled orders-dead, one line with a head at each end:
//   the sidecar republishes a message whose retries are used up to its deadLetterTopic
//   orders-dead, and receives it back from there because shipping also subscribes to
//   orders-dead (subscription-dead-letter.yaml).
// - shipping sidecar -> app on /orders/express, with the rule above it,
//   `priority == "express"` (the rule's match is 'event.data.priority == "express"'; the
//   label leaves out the `event.data.` prefix to fit the column, as the brief names it).
// - shipping sidecar -> app on /orders/standard (routes.default). The poison order has
//   priority "standard", so it lands here; the app answers 500 with RETRY for item
//   "poison" on either route. "3 retries, 1 s" sits under this arrow: resiliency.yaml,
//   orderRetries, policy constant, duration 1s, maxRetries 3, on the inbound side of the
//   component pubsub (one delivery plus three retries).
// - shipping sidecar -> app on /orders/dead (subscription-dead-letter.yaml routes.default).
//
// Layout: canvas 490 wide for the 424 px lab column, three shapes in the one row. The app
// and its sidecar are larger than the house 56 / 42 so that three route arrows, each with
// its label, fit between them; the sidecar stays 0.75 of the app.
import { APP, C } from '../_engine/engine.mjs';
import { arrow, elbowArrow, group, hex, hexHalfWidth, hexHalfWidthAt, label } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13; // every label, as in the other pubsub scenes

const W = 490;
const M = 12;
const EDGE = 2;

const APP_R = 64;
const SIDE_R = 0.75 * APP_R;
const APP_HW = hexHalfWidth(APP_R);
const SIDE_HW = hexHalfWidth(SIDE_R);

const MARK = 36;
const BROKER_NAME_DY = MARK / 2 + 14;

const BROKER_X = M + 28; // "pubsub" under the mark clears the margin
const SUB_X = W - M - EDGE - APP_HW;
const SIDE_X = 210; // leaves the sidecar -> app runs room for "/orders/standard"

const LABEL_GAP = 12; // an arrow's label centre this far from its arrow
const RULE_LIFT = 16; // the rule sits this far above its route's label
const ROUTE_DY = 40; // express and dead, above and below the row's centre line
const PAIR_DY = 12; // pubsub <-> sidecar: orders above, orders-dead below

const ROW_Y = M + ROUTE_DY + LABEL_GAP + RULE_LIFT + 8;
const H = ROW_Y + APP_R + M;

export default {
  width: W,
  height: H,
  title: 'Routing and dead letters',
  desc:
    'A Redis mark labelled pubsub delivers the topic orders to the Dapr sidecar of a blue hexagon '
    + 'labelled shipping. A line labelled orders-dead with a head at each end joins the sidecar and '
    + 'pubsub. The sidecar calls the shipping app on /orders/express under the rule priority == '
    + '"express", on /orders/standard, labelled 3 retries, 1 s, and on /orders/dead.',

  build() {
    const brokerR = BROKER_X + MARK / 2 + 2;
    const sideL = SIDE_X - SIDE_HW - 2;
    const pairX = (brokerR + sideL) / 2;

    // A route run from the sidecar's right edge to the app's left edge at height dy.
    const run = (dy) => [
      [SIDE_X + hexHalfWidthAt(SIDE_R, dy) + 2, ROW_Y + dy],
      [SUB_X - hexHalfWidthAt(APP_R, dy) - 2, ROW_Y + dy],
    ];
    const runX = (SIDE_X + SIDE_HW + SUB_X - APP_HW) / 2;
    const route = (dy) => {
      const [from, to] = run(dy);
      return arrow({ from, to });
    };

    return [group([
      // pubsub delivers orders; the sidecar republishes to orders-dead and gets it back.
      arrow({ from: [brokerR, ROW_Y - PAIR_DY], to: [sideL, ROW_Y - PAIR_DY] }),
      label({ x: pairX, y: ROW_Y - PAIR_DY - LABEL_GAP, text: 'orders', size: TEXT }),
      elbowArrow({ points: [[sideL, ROW_Y + PAIR_DY], [brokerR, ROW_Y + PAIR_DY]], heads: 'both' }),
      label({ x: pairX, y: ROW_Y + PAIR_DY + LABEL_GAP, text: 'orders-dead', size: TEXT }),

      // The routes: the rule, the default, and the dead-letter subscription's route.
      route(-ROUTE_DY),
      label({ x: runX, y: ROW_Y - ROUTE_DY - LABEL_GAP, text: '/orders/express', size: TEXT }),
      label({ x: runX, y: ROW_Y - ROUTE_DY - LABEL_GAP - RULE_LIFT, text: 'priority == "express"', size: TEXT, mono: true }),
      route(0),
      label({ x: runX, y: ROW_Y - LABEL_GAP, text: '/orders/standard', size: TEXT }),
      label({ x: runX, y: ROW_Y + LABEL_GAP, text: '3 retries, 1 s', size: TEXT }),
      route(ROUTE_DY),
      label({ x: runX, y: ROW_Y + ROUTE_DY + LABEL_GAP, text: '/orders/dead', size: TEXT }),

      icon({ name: 'redis', x: BROKER_X, y: ROW_Y, size: MARK, fit: 'ink', color: C.redisBrand }),
      label({ x: BROKER_X, y: ROW_Y + BROKER_NAME_DY, text: 'pubsub', size: TEXT }),

      markHex({ x: SIDE_X, y: ROW_Y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      hex({ x: SUB_X, y: ROW_Y, r: APP_R, label: 'shipping', size: TEXT, ...APP[1] }),
    ])];
  },
};
