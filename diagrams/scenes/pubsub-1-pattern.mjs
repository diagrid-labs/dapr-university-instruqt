// dapr-pubsub page 1 (subscription types), section 1 "Why pub/sub?": the
// publish and subscribe pattern in general. A redraw of the opaque white
// pubsub-pattern.png that was on the page, for the narrow dark column.
//
// This is the generic pattern, not the demo, so the labels are the generic
// ones of the original image and of the page's alt text.
//
// Elements, with each name as the original image shows it:
// - Publisher: an app, the green hexagon (APP[0]), as in the original.
// - Input channel: a pill, as in the original.
// - Message broker: a broker lying on its side, pipe(), house green (two or
//   more apps, REFERENCE.md Colors). The original drew it as a green tube too.
// - Output channel: a pill.
// - Subscriber (three): light blue hexagons (APP[1]).
//
// Connections, as in the original: Publisher -> Input channel -> Message
// broker -> Output channel, and the output channel fans out to every
// subscriber (one copy each).
//
// Departures from the original and the skill, on purpose:
// - The original is one row of five shapes with the three subscribers in a
//   column at its end. The column allows at most three shapes in a row, so the
//   chain snakes over three rows of a three-column grid: Publisher, Input
//   channel and Message broker on top; the broker turns down and back to the
//   Output channel in the middle column; the fan drops to the three
//   subscribers on the bottom row, one per column. The order of the chain and
//   the fan to every subscriber are unchanged.
// - The three subscribers share one colour and one name. In this generic
//   picture a hexagon is a role, not a named app, so they are coloured by role
//   (as the original did), rather than taking three APP fills.
// - The broker's name is on two lines: "Message broker" on one line needs a
//   longer pipe than the top row has room for.
// - Canvas 480 wide for the 424 px lab column (not 16:9 at 1100+ units).
import { APP } from '../_engine/engine.mjs';
import { arrow, elbowArrow, group, hex, pill, pipe, slots } from '../_engine/shapes.mjs';

const TEXT = 13; // every label in the scene, as in the PR 1 and PR 2 scenes

const W = 480;
const M = 12; // canvas margin

const APP_R = 56; // the house app radius, as in the dapr-bindings scenes
const PILL_H = 26;
// Measured with measure-labels at 13 (weight 600), plus half an em each end.
const IN_W = Math.ceil(86 + TEXT); // "Input channel"
const OUT_W = Math.ceil(97 + TEXT); // "Output channel"

// The broker: 48 across, its body twice that long (pipe() allows 2 to 3).
const PIPE_RY = 24;
const PIPE_RX = 10;
const PIPE_LEN = 4 * PIPE_RY;
const PIPE_W = PIPE_LEN + 2 * PIPE_RX; // its bounding rect, caps included

// Three columns, one subscriber per column, centred on the canvas. The pitch
// leaves a clear gap between two subscribers and keeps the top row's arrows
// 30 or longer.
const PITCH = 150;
const [X1, X2, X3] = slots(W / 2 - 1.5 * PITCH, W / 2 + 1.5 * PITCH, 3);

// Rows: the top row's centre, the output channel, the subscribers.
const Y1 = M + APP_R;
const Y2 = Y1 + 64; // below the pipe's bottom (Y1 + 24) by 40, room for the elbow to turn
const Y3 = Y2 + PILL_H / 2 + 64 + APP_R; // 64 from the pill to the subscribers' top points: the fan's trunk, turn and drop
const BUS_Y = Y2 + PILL_H / 2 + 26; // where the fan splits, nearer the pill so the drops are longer than the heads
const H = Y3 + APP_R + M;

export default {
  width: W,
  height: H,
  title: 'The publish and subscribe pattern',
  desc:
    'A green hexagon labelled Publisher sends a message through a pill labelled Input channel to a '
    + 'green tube labelled Message broker. From the broker an arrow turns down to a pill labelled '
    + 'Output channel, and from there the line splits into three arrows, one to each of three blue '
    + 'hexagons labelled Subscriber, so every subscriber gets a copy.',

  build() {
    const publisher = { x: X1, y: Y1, r: APP_R, hex: true };
    const input = { x: X2, y: Y1, w: IN_W, h: PILL_H };
    const broker = { x: X3, y: Y1, w: PIPE_W, h: 2 * PIPE_RY };
    const output = { x: X2, y: Y2, w: OUT_W, h: PILL_H };
    const top = Y2 + PILL_H / 2 + 2; // the fan leaves the pill's bottom edge
    const hexTop = Y3 - APP_R - 2; // and stops at each subscriber's top point

    return [group([
      arrow({ from: publisher, to: input }),
      arrow({ from: input, to: broker }),
      elbowArrow({ points: [[X3, Y1 + PIPE_RY + 2], [X3, Y2], [X2 + OUT_W / 2 + 2, Y2]] }),
      arrow({ from: [X2, top], to: [X2, hexTop] }),
      elbowArrow({ points: [[X2, top], [X2, BUS_Y], [X1, BUS_Y], [X1, hexTop]] }),
      elbowArrow({ points: [[X2, top], [X2, BUS_Y], [X3, BUS_Y], [X3, hexTop]] }),

      hex({ x: X1, y: Y1, r: APP_R, label: 'Publisher', size: TEXT, ...APP[0] }),
      pill({ ...input, text: 'Input channel', size: TEXT }),
      pipe({ x1: X3 - PIPE_LEN / 2, x2: X3 + PIPE_LEN / 2, y: Y1, ry: PIPE_RY, rx: PIPE_RX, label: 'Message\nbroker', size: TEXT }),
      pill({ ...output, text: 'Output channel', size: TEXT }),
      [X1, X2, X3].map((x) => hex({ x, y: Y3, r: APP_R, label: 'Subscriber', size: TEXT, ...APP[1] })),
    ])];
  },
};
