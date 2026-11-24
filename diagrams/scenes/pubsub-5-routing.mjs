// dapr-pubsub page 5 (routing and dead letters), section 2 "Retries", at the end: where
// shipping's sidecar sends each order from the topic orders, and how the poison order ends
// up on orders-dead, in three numbered steps.
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
// - "3 retries, 1 s apart" under the sidecar: resiliency.yaml, orderRetries, policy
//   constant, duration 1s, maxRetries 3, target components.pubsub.inbound. It applies to
//   every delivery the app rejects, on any route, so it belongs to the sidecar (as
//   "≤ 10 or 1000 ms" sits under the sidecar in pubsub-4-bulk), not to one route.
//
// Connections:
// - pubsub -> shipping sidecar, labelled orders: the subscription to the topic orders
//   (subscription-orders.yaml). No step number: every order takes it.
// - shipping sidecar -> app on /orders/express, with the rule above it,
//   `priority == "express"` (the rule's match is 'event.data.priority == "express"'; the
//   label leaves out the `event.data.` prefix to fit the column, as the brief names it).
// - shipping sidecar -> app on /orders/standard, with `default` above it in mono
//   (routes.default). Step 1: the poison order has priority "standard", so it lands here,
//   and the handler answers it with status 500 and body {"status": "RETRY"} (.NET
//   `TypedResults.Json(new { status = "RETRY" }, statusCode: 500)`, Python
//   `JSONResponse(status_code=500, content={"status": "RETRY"})`), hence
//   "poison: 500 RETRY" under the arrow.
// - Step 2: shipping sidecar -> pubsub, labelled orders-dead: after the last retry the
//   sidecar republishes the message to the subscription's deadLetterTopic orders-dead.
// - Step 3: pubsub -> shipping sidecar, labelled orders-dead, and sidecar -> app on
//   /orders/dead: shipping also subscribes to orders-dead (subscription-dead-letter.yaml,
//   routes.default /orders/dead).
// The two orders-dead arrows are one-way loops over the gap between pubsub and the
// sidecar, (2) inside (3), so each has room for its own label and step mark.
//
// Layout: canvas 500 wide for the 424 px lab column, three shapes in the one row, house
// sizes (app R 56, sidecar 0.75 of it). The express and dead routes leave the sidecar near
// its middle and bend out to their heights, so the sidecar can stay house size while the
// three routes are far enough apart for their labels.
import { APP, C } from '../_engine/engine.mjs';
import { arrow, elbowArrow, group, hex, hexEdgeAt, hexHalfWidth, hexHalfWidthAt, label, stepMark } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13; // every label, as in the other pubsub scenes

const W = 500;
const M = 12; // margin, as in the other pubsub scenes
const EDGE = 2; // a stroke's half width plus anti-aliasing, kept clear of the canvas edge

const APP_R = 56; // house app size
const SIDE_R = 0.75 * APP_R; // house sidecar size relation
const APP_HW = hexHalfWidth(APP_R);
const SIDE_HW = hexHalfWidth(SIDE_R);
const CLEAR = 2; // an arrow's end this far off the shape it meets (the engine's own gap)

const MARK = 36; // the Redis mark, as in pubsub-1-demo, -2 and -4
const GLYPH = 0.37 * TEXT; // half a label's cap height: its ink reaches this far from its centre
const NAME_GAP = 14; // a name under a shape: its centre this far below the shape (about one line)
const BROKER_NAME_DY = MARK / 2 + NAME_GAP;
const SIDE_NOTE_DY = SIDE_R + NAME_GAP; // "3 retries, 1 s apart" under the sidecar

const STEP = 11; // step mark radius: a 13-unit digit in a 22-unit disc (bindings-4)
const STEP_GAP = 6; // step mark edge to its arrow (bindings-4)
const STEP_DY = STEP + STEP_GAP; // a step mark's centre off its arrow; its label shares that line
const STEP_TO_TEXT = 6; // step mark edge to the label beside it

const LABEL_GAP = 12; // an unnumbered arrow's label centre this far from its arrow (about one character clear)
const RULE_LIFT = 16; // a mono condition this far above its route's label (one line)

// Measured with measure-labels at 13 (weight 600).
const POISON_W = 125; // "poison: 500 RETRY"
const DEAD_W = 78.4; // "orders-dead"
const ROUTE_DEAD_W = 82.2; // "/orders/dead"

// Columns.
const BROKER_X = M + 28; // "pubsub" (47 wide) under the mark clears the margin
const SUB_X = W - M - EDGE - APP_HW;
const SIDE_X = 168; // leaves the routes ~11 clear either side of disc (1) and "poison: 500 RETRY"
const BEND = 12; // the express and dead routes run this far right of the sidecar before they bend (one corner radius)
const DEAD_LABEL_DX = 24; // "/orders/dead" right of the run's centre, clear of the sidecar's note

// Rows, from the row's centre line.
const FAN_DY = 14; // the express and dead routes leave the sidecar this far above and below the centre
const EXPRESS_DY = 42; // "default" (two lines above standard) clears the express arrow by ~9
const DEAD_DY = 40; // the poison line (disc to 28 below) clears the dead arrow by ~12
const LOOP_IN = 60; // step 2's loop, over the "orders" label and its own label inside the loop
const LOOP_OUT = 86; // step 3's loop, its label and mark above it

// Where the loops meet the shapes (offsets from each centre).
const BROKER_IN_DX = 6; // step 2 ends on the mark's top, right of centre
const BROKER_OUT_DX = -8; // step 3 starts on the mark's top, left of centre
const SIDE_IN_DX = 4; // step 2 leaves the sidecar's top near its point; with BROKER_IN_DX its loop holds (2) orders-dead ~10 clear of both legs
const SIDE_OUT_DX = 20; // step 3 enters the sidecar's upper right edge, outside step 2

const TOP = LOOP_OUT + STEP_DY + STEP; // step 3's mark is the highest ink
const ROW_Y = M + TOP;
const BOTTOM = Math.max(DEAD_DY + STEP_DY + STEP, SIDE_NOTE_DY + GLYPH);
const H = Math.ceil(ROW_Y + BOTTOM + M);

export default {
  width: W,
  height: H,
  title: 'Routing and dead letters',
  desc:
    'A Redis mark labelled pubsub delivers the topic orders to the Dapr sidecar of a blue hexagon '
    + 'labelled shipping; under the sidecar it says 3 retries, 1 s apart. The sidecar calls the '
    + 'shipping app on /orders/express under the rule priority == "express", on /orders/standard, '
    + 'marked default, and on /orders/dead. Step 1: the poison order fails on /orders/standard with '
    + '500 RETRY. Step 2: the sidecar sends it to pubsub on orders-dead. Step 3: pubsub delivers '
    + 'orders-dead back to the sidecar, which calls /orders/dead.',

  build() {
    const brokerR = BROKER_X + MARK / 2 + CLEAR;
    const brokerTop = ROW_Y - MARK / 2 - CLEAR;
    const sideL = SIDE_X - SIDE_HW - CLEAR;
    const sideR = SIDE_X + SIDE_HW + CLEAR;
    const sideTop = (dx) => ROW_Y - hexEdgeAt(SIDE_R, dx) - CLEAR;
    const bendX = sideR + BEND;
    const appL = (dy) => SUB_X - hexHalfWidthAt(APP_R, dy) - CLEAR;
    const runX = (bendX + SUB_X - APP_HW) / 2;

    // A route that leaves the sidecar at fanDy and bends out to dy.
    const fan = (fanDy, dy) => elbowArrow({
      points: [[sideR, ROW_Y + fanDy], [bendX, ROW_Y + fanDy], [bendX, ROW_Y + dy], [appL(dy), ROW_Y + dy]],
    });
    // A step mark and its label, centred together on x at height y.
    const numbered = (x, y, step, text, w) => {
      const left = x - (2 * STEP + STEP_TO_TEXT + w) / 2;
      return [
        stepMark({ x: left + STEP, y, step, r: STEP, size: TEXT }),
        label({ x: left + 2 * STEP + STEP_TO_TEXT, y, text, size: TEXT, anchor: 'start' }),
      ];
    };

    // The loops' vertical legs.
    const inL = BROKER_X + BROKER_IN_DX;
    const inR = SIDE_X + SIDE_IN_DX;
    const outL = BROKER_X + BROKER_OUT_DX;
    const outR = SIDE_X + SIDE_OUT_DX;

    return [group([
      // Every order: pubsub delivers the topic orders.
      arrow({ from: [brokerR, ROW_Y], to: [sideL, ROW_Y] }),
      label({ x: (brokerR + sideL) / 2, y: ROW_Y - LABEL_GAP, text: 'orders', size: TEXT }),

      // The routes: the rule, the default, and the dead-letter subscription's route.
      fan(-FAN_DY, -EXPRESS_DY),
      label({ x: runX, y: ROW_Y - EXPRESS_DY - LABEL_GAP, text: '/orders/express', size: TEXT }),
      label({ x: runX, y: ROW_Y - EXPRESS_DY - LABEL_GAP - RULE_LIFT, text: 'priority == "express"', size: TEXT, mono: true }),
      arrow({ from: [sideR, ROW_Y], to: [appL(0), ROW_Y] }),
      label({ x: runX, y: ROW_Y - LABEL_GAP, text: '/orders/standard', size: TEXT }),
      label({ x: runX, y: ROW_Y - LABEL_GAP - RULE_LIFT, text: 'default', size: TEXT, mono: true }),
      fan(FAN_DY, DEAD_DY),

      // Step 1: the poison order fails on the default route.
      ...numbered(runX, ROW_Y + STEP_DY, 1, 'poison: 500 RETRY', POISON_W),
      // Step 2: after the retries, the sidecar republishes it to orders-dead.
      elbowArrow({ points: [[inR, sideTop(SIDE_IN_DX)], [inR, ROW_Y - LOOP_IN], [inL, ROW_Y - LOOP_IN], [inL, brokerTop]] }),
      ...numbered((inL + inR) / 2, ROW_Y - LOOP_IN + STEP_DY, 2, 'orders-dead', DEAD_W),
      // Step 3: orders-dead comes back to the sidecar, which calls /orders/dead.
      elbowArrow({ points: [[outL, brokerTop], [outL, ROW_Y - LOOP_OUT], [outR, ROW_Y - LOOP_OUT], [outR, sideTop(SIDE_OUT_DX)]] }),
      ...numbered((outL + outR) / 2, ROW_Y - LOOP_OUT - STEP_DY, 3, 'orders-dead', DEAD_W),
      ...numbered(runX + DEAD_LABEL_DX, ROW_Y + DEAD_DY + STEP_DY, 3, '/orders/dead', ROUTE_DEAD_W),

      icon({ name: 'redis', x: BROKER_X, y: ROW_Y, size: MARK, fit: 'ink', color: C.redisBrand }),
      label({ x: BROKER_X, y: ROW_Y + BROKER_NAME_DY, text: 'pubsub', size: TEXT }),

      markHex({ x: SIDE_X, y: ROW_Y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      label({ x: SIDE_X, y: ROW_Y + SIDE_NOTE_DY, text: '3 retries, 1 s apart', size: TEXT }),
      hex({ x: SUB_X, y: ROW_Y, r: APP_R, label: 'shipping', size: TEXT, ...APP[1] }),
    ])];
  },
};
