// dapr-pubsub page 1 (subscription types), section 2 "Two subscribers, two
// subscription types": the demo's three apps and how each subscriber's sidecar
// learns its subscription.
//
// Elements, with each name as it appears in the demo (university-labs at
// 37fccac, pubsub/<lang>/demo1-subscriptions, read in dotnet, python and java):
// - order-api: the publisher, the green hexagon (APP[0]) with its Dapr sidecar
//   docked, as Cart in pubsub-1-components (dapr.yaml appID `order-api`).
// - pubsub: the pub/sub component (resources/pubsub.yaml, `name: pubsub`,
//   `type: pubsub.redis`), drawn as the Redis mark with the component name
//   under it.
// - orders: the topic (`PublishEventAsync(PubSub, Topic, ...)` with
//   Topic = "orders"), the label of the publish arrow.
// - shipping: the light blue hexagon (APP[1]) with its sidecar drawn apart.
// - subscription-shipping.yaml: the declarative subscription in the demo's
//   resources folder (route `default: /orders`, `scopes: [shipping]`), the
//   Fluent document mark with the file name beside it.
// - invoicing: the gold hexagon (APP[2]) with its sidecar drawn apart.
//
// Connections:
// - order-api's sidecar -> pubsub, labelled orders (the publish).
// - pubsub -> the shipping sidecar and -> the invoicing sidecar (delivery).
// - subscription-shipping.yaml -> the shipping sidecar: the sidecar reads the
//   file (dapr.yaml resourcesPaths includes ./resources).
// - shipping sidecar -> shipping app on /orders (the YAML route; the app has
//   only a POST /orders route and no Dapr code).
// - invoicing sidecar -> invoicing app on /dapr/subscribe (MapSubscribeHandler,
//   DaprApp, the Java SDK's @Topic: the endpoint Dapr calls at startup).
// - invoicing sidecar -> invoicing app on /orders (WithTopic on MapPost
//   "/orders"; route="/orders"; @PostMapping("/orders")).
//
// Layout and departures from the skill, on purpose:
// - The column allows at most three shapes in a row. The difference between
//   the two subscription types is what the sidecar does, so the subscribers'
//   sidecars stand apart from their apps (the PR 2 convention): sidecars in
//   the middle column, apps in the right column, one row each. The broker sits
//   in the left column between the two rows, order-api above it. The YAML file
//   sits above the shipping sidecar, in the top row, where the right column is
//   empty and holds its name.
// - order-api's sidecar is docked (its app<->sidecar call is not the point
//   here), as in pubsub-1-components; the broker is centred under it.
// - The invoicing row has two arrows between sidecar and app, the startup call
//   above and the delivery below, each labelled on its outer side.
// - Canvas 490 wide for the 424 px lab column (not 16:9 at 1100+ units).
import { APP, C } from '../_engine/engine.mjs';
import { arrow, group, hex, hexHalfWidth, label } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13; // every label in the scene, as in pubsub-1-pattern and pubsub-1-components

const W = 490;
const M = 12; // canvas margin
const EDGE = 2; // an app hexagon's outer point stays this far inside the margin

const APP_R = 56; // the house app radius, as in pubsub-1-components
const SIDE_R = 0.75 * APP_R; // the house sidecar size
const APP_HW = hexHalfWidth(APP_R);
const SIDE_HW = hexHalfWidth(SIDE_R);

// order-api's docked sidecar, copied from pubsub-1-components (Cart).
const DOCK_DX = 0.75 * APP_R;
const DOCK_DY = 0.9 * APP_R; // and below it, low enough that the app name sits centred in the hexagon

// Columns: order-api against the left margin, the subscriber apps against the
// right margin, their sidecars far enough left that the arrow between sidecar
// and app holds "/dapr/subscribe" (measured at 13, weight 600, about 100) above it.
const PUB_X = M + EDGE + APP_HW;
const PUB_SIDE_X = PUB_X + DOCK_DX;
const BROKER_X = PUB_SIDE_X; // the broker centred under order-api's sidecar
const SUB_X = W - M - EDGE - APP_HW;
const SIDE_X = 230;

// Rows: order-api on top; the two subscriber rows below, the broker between
// them so both delivery arrows leave it at the same angle.
const PUB_Y = M + APP_R;
const SHIP_Y = 170;
const INV_Y = 296;
const BROKER_Y = (SHIP_Y + INV_Y) / 2;
const H = INV_Y + APP_R + M;

const MARK = 36; // the Redis mark, fitted by its ink
const BROKER_NAME_DY = MARK / 2 + 14; // "pubsub" under the mark

// The YAML file above the shipping sidecar: an arrow from the document to the
// sidecar's top point, and the file name to the document's right.
const DOC = 22; // the document mark's height, as in pubsub-1-components
const DOC_RUN = 30; // the arrow from the document to the sidecar
const DOC_Y = SHIP_Y - SIDE_R - DOC_RUN - DOC / 2;
const DOC_NAME_DX = 14; // the file name starts this far right of the document's centre

const LABEL_GAP = 12; // an arrow's label centre this far from its arrow (about one character clear)
const PAIR_DY = 14; // invoicing's two arrows, above and below the row's centre line

export default {
  width: W,
  height: H,
  title: 'The demo\'s two subscription types',
  desc:
    'A green hexagon labelled order-api with a Dapr sidecar publishes to the topic orders on a Redis '
    + 'mark labelled pubsub. From pubsub one arrow runs to the Dapr sidecar of a blue hexagon labelled '
    + 'shipping and one to the Dapr sidecar of a gold hexagon labelled invoicing. The shipping sidecar '
    + 'reads a document labelled subscription-shipping.yaml and delivers to the shipping app on /orders. '
    + 'The invoicing sidecar calls the invoicing app on /dapr/subscribe and delivers to it on /orders.',

  build() {
    const pubSide = { x: PUB_SIDE_X, y: PUB_Y + DOCK_DY, r: SIDE_R, hex: true };
    const broker = { x: BROKER_X, y: BROKER_Y, w: MARK, h: MARK };
    const shipSide = { x: SIDE_X, y: SHIP_Y, r: SIDE_R, hex: true };
    const invSide = { x: SIDE_X, y: INV_Y, r: SIDE_R, hex: true };
    const pubArrowTop = pubSide.y + SIDE_R + 2;
    const pubArrowBottom = BROKER_Y - MARK / 2 - 2;
    const runL = SIDE_X + SIDE_HW + 2; // sidecar -> app arrows: the sidecar's right side
    const runR = SUB_X - APP_HW - 2; // to the app's left side
    const runX = (runL + runR) / 2;

    return [group([
      // order-api publishes to the topic orders on pubsub.
      arrow({ from: [BROKER_X, pubArrowTop], to: [BROKER_X, pubArrowBottom] }),
      label({ x: BROKER_X - LABEL_GAP, y: (pubArrowTop + pubArrowBottom) / 2, text: 'orders', size: TEXT, anchor: 'end' }),

      // pubsub delivers to both subscribers' sidecars.
      arrow({ from: broker, to: shipSide }),
      arrow({ from: broker, to: invSide }),

      // shipping: the sidecar reads the YAML file, then delivers on /orders.
      arrow({ from: [SIDE_X, DOC_Y + DOC / 2 + 2], to: [SIDE_X, SHIP_Y - SIDE_R - 2] }),
      arrow({ from: [runL, SHIP_Y], to: [runR, SHIP_Y] }),
      label({ x: runX, y: SHIP_Y - LABEL_GAP, text: '/orders', size: TEXT }),

      // invoicing: the sidecar asks the app on /dapr/subscribe, then delivers on /orders.
      arrow({ from: [runL, INV_Y - PAIR_DY], to: [runR, INV_Y - PAIR_DY] }),
      label({ x: runX, y: INV_Y - PAIR_DY - LABEL_GAP, text: '/dapr/subscribe', size: TEXT }),
      arrow({ from: [runL, INV_Y + PAIR_DY], to: [runR, INV_Y + PAIR_DY] }),
      label({ x: runX, y: INV_Y + PAIR_DY + LABEL_GAP, text: '/orders', size: TEXT }),

      hex({ x: PUB_X, y: PUB_Y, r: APP_R, label: 'order-api', size: TEXT, ...APP[0] }),
      markHex({ x: PUB_SIDE_X, y: pubSide.y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),

      icon({ name: 'redis', x: BROKER_X, y: BROKER_Y, size: MARK, fit: 'ink', color: C.redisBrand }),
      label({ x: BROKER_X, y: BROKER_Y + BROKER_NAME_DY, text: 'pubsub', size: TEXT }),

      icon({ name: 'fluent-document', x: SIDE_X, y: DOC_Y, size: DOC, color: C.navy, fit: 'ink' }),
      label({ x: SIDE_X + DOC_NAME_DX, y: DOC_Y, text: 'subscription-shipping.yaml', size: TEXT, anchor: 'start' }),

      markHex({ x: SIDE_X, y: SHIP_Y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      hex({ x: SUB_X, y: SHIP_Y, r: APP_R, label: 'shipping', size: TEXT, ...APP[1] }),
      markHex({ x: SIDE_X, y: INV_Y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      hex({ x: SUB_X, y: INV_Y, r: APP_R, label: 'invoicing', size: TEXT, ...APP[2] }),
    ])];
  },
};
