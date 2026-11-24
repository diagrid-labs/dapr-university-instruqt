// dapr-secrets page 2 (the component and its parameters), section 4 "A component
// that gets its password from the secret store", after the explanation of
// `secretKeyRef` and `auth.secretStore`: the sidecar loads both component files,
// looks up the state store's password in the secret store, and then connects to
// Redis with it.
//
// Elements, with each name as it appears in the demo (university-labs secrets/
// at 37fccac, <lang>/resources, read in dotnet, python and java: the three are
// the same) and the assignment:
// - secretstore-local.yaml and statestore-with-secretref.yaml: the two component
//   files in the resources folder (dapr.yaml `resourcesPath: ../resources`), each
//   the `fluent-document` mark with its file name above it, joined to the sidecar
//   that loads it by a plain line (the PR 3 convention).
// - Dapr sidecar: markHex with the Dapr logo, as in secrets-1-cloud-stores. It is
//   order-api's sidecar (dapr.yaml appID `order-api`), but the app itself is left
//   out: section 4 calls the sidecar directly on port 3500, and the resolution
//   happens in the sidecar, not in the app.
// - secretstore: the secret store component (`metadata.name: secretstore`,
//   `type: secretstores.local.file`), the skill's secret store shape (lockBox)
//   with the component name under it, drawn as its own 13-unit label (lockBox's
//   built-in label is below the floor) on the same line as "statestore".
// - statestore: the state store component (`metadata.name: statestore`,
//   `type: state.redis`), the Redis mark with the component name under it, as the
//   Redis components are drawn in the pubsub scenes.
//
// Connections:
// - Both files -> Dapr sidecar (plain lines): the sidecar loads them at startup.
// - Dapr sidecar -> secretstore, labelled orderdb-password with `secretKeyRef`
//   in mono above it (the field that names the secret): the component's
//   `redisPassword` has `secretKeyRef: { name: orderdb-password, key:
//   orderdb-password }` and `auth.secretStore: secretstore`, so the sidecar reads
//   the secret orderdb-password from secretstore.
// - Dapr sidecar -> statestore, labelled redisPassword: the sidecar connects to
//   Redis with the value it got as the component's redisPassword.
// The two arrows leave the sidecar in opposite directions; the lookup is on the
// secret store side, the connection on the Redis side, matching the alt text's
// "reads it from secretstore before it connects".
//
// Layout: canvas 490 wide for the 424 px lab column, three shapes in the one row,
// house sidecar size. No step discs: the section's sentences don't name the
// lookup and the connection as two steps, so numbering them would need new text.
import { C } from '../_engine/engine.mjs';
import { arrow, group, hexEdgeAt, hexHalfWidth, label, lockBox } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13; // every label, as in the other secrets, pubsub and bindings scenes

const W = 490;
const M = 12; // canvas margin, as in secrets-1-cloud-stores
const CLEAR = 2; // an arrow's end this far off the shape it meets (the engine's own gap)
const GLYPH = 0.37 * TEXT; // half a label's cap height

const APP_R = 56; // the house app radius (no app drawn; the sidecar keeps its size relation)
const SIDE_R = 0.75 * APP_R; // the house sidecar size, as in secrets-1-cloud-stores
const SIDE_HW = hexHalfWidth(SIDE_R);
const NAME_DY = SIDE_R + 16; // "Dapr sidecar" under its hexagon, as in secrets-1-cloud-stores

const LOCK = 44; // lockBox default size
const MARK = 36; // the Redis mark, as in the pubsub scenes
const NAME_GAP = 14; // a name's centre this far below a store (about one line)
const LABEL_GAP = 12; // an arrow's label centre this far from its arrow (about one character clear)
const REF_LIFT = 16; // the mono field name one line above the secret's name, as the rule over its route in pubsub-5-routing

// Measured with measure-labels at 13 (weight 600).
const SECRETSTORE_W = 76; // "secretstore"
const STATESTORE_W = 68; // "statestore"

// Columns: the stores against the margins (their names are wider than the
// shapes, so the names set the inset), the sidecar centred between them.
const LOCK_X = M + SECRETSTORE_W / 2 + 4;
const REDIS_X = W - M - STATESTORE_W / 2 - 4;
const SIDE_X = (LOCK_X + REDIS_X) / 2;

// The files: names on the top line, the document marks under them, a line from
// each document to the sidecar's upper edge on its side.
const DOC = 22; // the document mark's height, as in pubsub-1-demo
const FILE_NAME_Y = M + 8;
const DOC_Y = FILE_NAME_Y + 8 + 6 + DOC / 2; // the mark's top 6 under the name's ink
const FILE_L_X = 128; // "secretstore-local.yaml" centred over the left gap
const FILE_R_X = 362; // "statestore-with-secretref.yaml" centred over the right gap
const EDGE_DX = SIDE_HW / 2; // the lines meet the sidecar's two upper edges at their middle

const ROW_Y = 132;
const H = Math.ceil(ROW_Y + NAME_DY + GLYPH + M);

export default {
  width: W,
  height: H,
  title: 'A component that gets its password from the secret store',
  desc:
    'Two documents at the top, secretstore-local.yaml and statestore-with-secretref.yaml, are joined '
    + 'to a Dapr sidecar in the middle. From the sidecar one arrow, labelled secretKeyRef orderdb-password, runs left '
    + 'to a secret store labelled secretstore, and another, labelled redisPassword, runs right to a Redis '
    + 'mark labelled statestore.',

  build() {
    const sideL = SIDE_X - SIDE_HW - CLEAR;
    const sideR = SIDE_X + SIDE_HW + CLEAR;
    const lockR = LOCK_X + LOCK / 2 + CLEAR;
    const redisL = REDIS_X - MARK / 2 - CLEAR;
    const edgeY = ROW_Y - hexEdgeAt(SIDE_R, EDGE_DX) - CLEAR;
    const docBottom = DOC_Y + DOC / 2 + CLEAR;

    return [group([
      // The sidecar loads both component files.
      arrow({ from: [FILE_L_X, docBottom], to: [SIDE_X - EDGE_DX, edgeY], head: false }),
      arrow({ from: [FILE_R_X, docBottom], to: [SIDE_X + EDGE_DX, edgeY], head: false }),
      label({ x: FILE_L_X, y: FILE_NAME_Y, text: 'secretstore-local.yaml', size: TEXT }),
      icon({ name: 'fluent-document', x: FILE_L_X, y: DOC_Y, size: DOC, color: C.navy, fit: 'ink' }),
      label({ x: FILE_R_X, y: FILE_NAME_Y, text: 'statestore-with-secretref.yaml', size: TEXT }),
      icon({ name: 'fluent-document', x: FILE_R_X, y: DOC_Y, size: DOC, color: C.navy, fit: 'ink' }),

      // The secretKeyRef: the sidecar reads orderdb-password from secretstore...
      arrow({ from: [sideL, ROW_Y], to: [lockR, ROW_Y] }),
      label({ x: (sideL + lockR) / 2, y: ROW_Y - LABEL_GAP, text: 'orderdb-password', size: TEXT }),
      label({ x: (sideL + lockR) / 2, y: ROW_Y - LABEL_GAP - REF_LIFT, text: 'secretKeyRef', size: TEXT, mono: true }),
      // ...and connects to Redis with it as redisPassword.
      arrow({ from: [sideR, ROW_Y], to: [redisL, ROW_Y] }),
      label({ x: (sideR + redisL) / 2, y: ROW_Y - LABEL_GAP, text: 'redisPassword', size: TEXT }),

      lockBox({ x: LOCK_X, y: ROW_Y, size: LOCK }),
      label({ x: LOCK_X, y: ROW_Y + MARK / 2 + NAME_GAP, text: 'secretstore', size: TEXT }), // on the statestore name's line
      markHex({ x: SIDE_X, y: ROW_Y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      label({ x: SIDE_X, y: ROW_Y + NAME_DY, text: 'Dapr sidecar', size: TEXT }),
      icon({ name: 'redis', x: REDIS_X, y: ROW_Y, size: MARK, fit: 'ink', color: C.redisBrand }),
      label({ x: REDIS_X, y: ROW_Y + MARK / 2 + NAME_GAP, text: 'statestore', size: TEXT }),
    ])];
  },
};
