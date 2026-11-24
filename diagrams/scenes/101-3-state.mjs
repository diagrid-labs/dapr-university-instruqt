// dapr-101 page 3 (the State Management API), after the goal paragraph at the
// top: the learner calls the sidecar's State Management API with curl on port
// 3500, with no application, and the sidecar keeps the state in Redis through
// the statestore component.
//
// Elements, with each name as it appears in the demo (university-labs
// dapr-101/state-management at 18d67c0: only dapr.yaml, `appID: myapp`,
// `daprHTTPPort: 3500`, no `command`, no `resourcesPaths`) and the assignment:
// - curl: the caller, in mono in a code card, as `dapr init` in
//   101-2-dapr-init. The page calls the sidecar directly, so no app hexagon
//   (the PR 4 rule: a caller that is not an app is a label or terminal mark).
// - Dapr sidecar: markHex with the Dapr logo at the house sidecar size, as in
//   secrets-2-secret-ref (sidecar called directly, no app). Its port `:3500`
//   (daprHTTPPort) is a mono label under the arrow's head, against the
//   sidecar: the spot right of its bottom point (secrets-3-scoping) would run
//   into the "Dapr sidecar" name under it.
// - statestore: the default component that `dapr init` placed in
//   ~/.dapr/components (`metadata.name: statestore`, `type: state.redis`; the
//   sidecar logs `Component loaded: statestore (state.redis/v1)`), drawn as the
//   Redis mark with the component name under it, as in secrets-2-secret-ref.
//
// Connections:
// - curl -> Dapr sidecar, labelled with the three methods the page sends to
//   /v1.0/state/statestore, stacked in mono in the page's order: POST (section
//   2, save), GET (section 3, get), DELETE (section 5, delete).
// - Dapr sidecar -> statestore, labelled `myapp||name`: the key as Redis holds
//   it, with the app ID as prefix (section 4's note). The arrow points the way
//   the call goes; the value read back travels along the same line.
//
// Layout: canvas 490 wide for the 424 px lab column, three shapes in the one
// row. No step discs: the page's sections already number the calls.
import { C } from '../_engine/engine.mjs';
import { arrow, codeCard, group, hexHalfWidth, label } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13; // every label, as in the secrets, pubsub, bindings and 101-2 scenes

const W = 490;
const M = 12; // canvas margin, as in the secrets scenes
const EDGE = 2; // the card's left edge stays this far inside the margin
const CLEAR = 2; // an arrow's end this far off the shape it meets (the engine's own gap)
const GLYPH = 0.37 * TEXT; // half a label's cap height

const APP_R = 56; // the house app radius (no app drawn; the sidecar keeps its size relation)
const SIDE_R = 0.75 * APP_R; // the house sidecar size, as in secrets-2-secret-ref
const SIDE_HW = hexHalfWidth(SIDE_R);
const NAME_DY = SIDE_R + 16; // "Dapr sidecar" under its hexagon, as in secrets-2-secret-ref
const PORT_DX = 4; // the port's end this far left of the arrow's head

const MARK = 36; // the Redis mark, as in the secrets and pubsub scenes
const NAME_GAP = 14; // a name's centre this far below a store (about one line)
const LABEL_GAP = 12; // an arrow's nearest label centre this far from the arrow (about one character clear)
const LINE = 16; // the stacked methods' line pitch

// "curl" is 4 characters in mono at 13 (about 31), plus 16 each side.
const CARD_W = 64;
const CARD_H = 36;
const CARD_X = M + EDGE + CARD_W / 2;

// Measured with measure-labels at 13 (weight 600).
const STATESTORE_W = 68; // "statestore"
const REDIS_X = W - M - STATESTORE_W / 2 - 4; // the name, wider than the mark, sets the inset

// The sidecar sits so that the right gap holds "myapp||name" (11 characters in
// mono, about 86) with room either side, and the left gap the methods.
const SIDE_X = 262;

const METHODS = ['POST', 'GET', 'DELETE'];
const ROW_Y = M + (METHODS.length - 1) * LINE + LABEL_GAP + GLYPH + 30; // the top method clears the margin
const H = Math.ceil(ROW_Y + NAME_DY + GLYPH + M);

export default {
  width: W,
  height: H,
  title: 'curl calls the State Management API',
  desc:
    'On the left a card with the command curl. An arrow labelled POST, GET and DELETE runs to a Dapr '
    + 'sidecar on port 3500 in the middle. From the sidecar an arrow labelled myapp||name runs right to '
    + 'a Redis mark labelled statestore. No application is drawn.',

  build() {
    const cardR = CARD_X + CARD_W / 2 + CLEAR;
    const sideL = SIDE_X - SIDE_HW - CLEAR;
    const sideR = SIDE_X + SIDE_HW + CLEAR;
    const redisL = REDIS_X - MARK / 2 - CLEAR;
    const leftMid = (cardR + sideL) / 2;

    return [group([
      // curl calls the sidecar's State Management API: save, get, delete.
      arrow({ from: [cardR, ROW_Y], to: [sideL, ROW_Y] }),
      ...METHODS.map((m, i) => label({
        x: leftMid,
        y: ROW_Y - LABEL_GAP - (METHODS.length - 1 - i) * LINE,
        text: m,
        size: TEXT,
        mono: true,
      })),
      // The sidecar keeps the key in Redis with the app ID as prefix.
      arrow({ from: [sideR, ROW_Y], to: [redisL, ROW_Y] }),
      label({ x: (sideR + redisL) / 2, y: ROW_Y - LABEL_GAP, text: 'myapp||name', size: TEXT, mono: true }),

      codeCard({ x: CARD_X, y: ROW_Y, w: CARD_W, h: CARD_H }),
      label({ x: CARD_X, y: ROW_Y, text: 'curl', size: TEXT, mono: true }),

      markHex({ x: SIDE_X, y: ROW_Y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      label({ x: SIDE_X, y: ROW_Y + NAME_DY, text: 'Dapr sidecar', size: TEXT }),
      label({ x: sideL - PORT_DX, y: ROW_Y + LABEL_GAP, text: ':3500', size: TEXT, anchor: 'end', mono: true }),

      icon({ name: 'redis', x: REDIS_X, y: ROW_Y, size: MARK, fit: 'ink', color: C.redisBrand }),
      label({ x: REDIS_X, y: ROW_Y + MARK / 2 + NAME_GAP, text: 'statestore', size: TEXT }),
    ])];
  },
};
