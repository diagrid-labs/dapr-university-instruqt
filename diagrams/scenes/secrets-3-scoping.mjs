// dapr-secrets page 3 (secret scoping), section 4 "Tell App B no", after the
// `configFilePath` step: two apps with the same code ask for the same secret,
// but App B's sidecar loads config-app-b.yaml, which denies orderdb-password, so
// App B's sidecar refuses the request and only App A's sidecar reads it from
// secretstore.
//
// Elements, with each name as it appears in the demo (university-labs secrets/
// at 37fccac, <lang>/demo2-scoping, read in dotnet, python and java: dapr.yaml,
// resources/ and the apps are the same in all three) and the assignment:
// - app-a: the green hexagon (APP[0]), dapr.yaml `appID: app-a`, appPort 5002.
//   The page calls it App A; the hexagon carries the app ID, as the Dev
//   Dashboard and the "Started Dapr with app id" lines do.
// - app-b: the light blue hexagon (APP[1], the second app), `appID: app-b`,
//   appPort 5003.
// - Two Dapr sidecars (markHex with the Dapr logo, as in secrets-1 and -2), on
//   daprHTTPPort 3501 (app-a) and 3502 (app-b). Each is drawn apart from its
//   app with an arrow between them, because the point of the page is that the
//   app does not decide; the sidecar does (section 5 asks App B's sidecar
//   directly and gets the same refusal).
// - secretstore: the secret store component (resources/secretstore-local.yaml,
//   `metadata.name: secretstore`, `type: secretstores.local.file`), the lockBox
//   shape with its name drawn as a separate 13-unit label, as in secrets-2.
// - config-app-b.yaml: the Configuration resource (resources/config-app-b.yaml,
//   `kind: Configuration`), the `fluent-document` mark with its file name beside
//   it, under app-b's sidecar and joined to it by a short plain line, as the
//   component files hang under the sidecars in pubsub-1-components: only
//   app-b has `configFilePath: ../resources/config-app-b.yaml` in dapr.yaml.
//   Its policy is the caption under it: `defaultAccess: deny` and
//   `allowedSecrets: ["payments-api-key", "legacy-api-key"]` (the scope's
//   `storeName: secretstore` is left out to keep the caption short).
//
// Connections:
// - app-a -> its sidecar, labelled orderdb-password (both apps call
//   GET /secret/{name}, which asks `secretstore` for that name through the SDK).
// - app-a's sidecar -> secretstore (unlabelled: the same request, passed on).
//   App A has no configuration, so the store answers.
// - app-b -> its sidecar, labelled orderdb-password, with the refusal under the
//   arrow as the demo returns it: "403 PERMISSION_DENIED" (the app's response
//   in section 5: status 403, `"error": "PERMISSION_DENIED"`, the gRPC status
//   the sidecar answered the SDK with). Plain house arrow, not red: red means a
//   crash only.
// - No arrow from app-b's sidecar to secretstore: the sidecar refuses the
//   request by policy ("access denied by policy", section 5) without asking the
//   store.
//
// Layout: canvas 490 wide for the 424 px lab column. Two rows, app-a above
// app-b, each at most three shapes (store, sidecar, app); the apps against the
// right margin, the sidecars in the middle column, the store on app-a's row
// against the left margin, and the configuration file under app-b's sidecar with
// its policy under it.
// House sizes: app R 56, sidecar 0.75 of it. No step discs: the page does not
// name these as numbered steps.
import { APP, C } from '../_engine/engine.mjs';
import { arrow, group, hex, hexHalfWidth, label, lockBox } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13; // every label, as in the other secrets, pubsub and bindings scenes

const W = 490;
const M = 12; // canvas margin, as in secrets-1 and -2
const EDGE = 2; // an app hexagon's outer point stays this far inside the margin
const CLEAR = 2; // an arrow's end this far off the shape it meets (the engine's own gap)
const GLYPH = 0.37 * TEXT; // half a label's cap height
const LINE = 16; // caption line pitch (one line at 13)

const APP_R = 56; // the house app radius
const SIDE_R = 0.75 * APP_R; // the house sidecar size
const APP_HW = hexHalfWidth(APP_R);
const SIDE_HW = hexHalfWidth(SIDE_R);

const LOCK = 44; // lockBox default size, as in secrets-2
const NAME_GAP = 14; // a name's centre this far below a shape (about one line)
const LABEL_GAP = 12; // an arrow's label centre this far from its arrow (about one character clear)

const DOC = 22; // the document mark's height, as in secrets-2 and pubsub-1-demo
const DOC_GAP = 10; // the line from the sidecar's bottom point to the document, as in pubsub-1-components
const DOC_DY = SIDE_R + DOC_GAP + DOC / 2; // document centre below its sidecar's centre
const DOC_NAME_DX = 8 + 8; // the file name's end this far left of the document's centre (its ink is 16 wide, plus one character)

// Measured with measure-labels at 13 (weight 600).
const SECRETSTORE_W = 76; // "secretstore"
const REFUSAL_W = 164.1; // "403 PERMISSION_DENIED"

// Columns: the apps against the right margin; the sidecar far enough left that
// the refusal fits under app-b's arrow; the store against the left margin.
const APP_X = W - M - EDGE - APP_HW;
const SIDE_X = APP_X - APP_HW - CLEAR - REFUSAL_W - 2 * 6 - CLEAR - SIDE_HW; // ~6 clear either side of the refusal
const LOCK_X = M + SECRETSTORE_W / 2 + 4;

// Rows.
const Y1 = M + APP_R; // app-a
const PITCH = 136; // the two app hexagons' points 24 apart, so the rows read as two pictures of the same request
const Y2 = Y1 + PITCH; // app-b
const CAPTION = ['defaultAccess: deny', 'allowedSecrets:', 'payments-api-key', 'legacy-api-key'];
const DOC_Y = Y2 + DOC_DY;
const CAP_Y = DOC_Y + DOC / 2 + NAME_GAP; // the first caption line under the document
const H = Math.ceil(Math.max(Y2 + APP_R, CAP_Y + (CAPTION.length - 1) * LINE + GLYPH) + M);

export default {
  width: W,
  height: H,
  title: 'Secret scoping with a sidecar configuration',
  desc:
    'Two rows. On top, a green hexagon labelled app-a sends orderdb-password to its Dapr sidecar, '
    + 'which passes the request on to a secret store labelled secretstore on the left. Below, a blue '
    + 'hexagon labelled app-b sends orderdb-password to its own Dapr sidecar and gets 403 '
    + 'PERMISSION_DENIED back; that sidecar has no arrow to the store. A plain line joins it to a '
    + 'document under it labelled config-app-b.yaml, with the caption defaultAccess: deny, allowedSecrets: '
    + 'payments-api-key, legacy-api-key.',

  build() {
    const appL = APP_X - APP_HW - CLEAR;
    const sideL = SIDE_X - SIDE_HW - CLEAR;
    const sideR = SIDE_X + SIDE_HW + CLEAR;
    const lockR = LOCK_X + LOCK / 2 + CLEAR;

    return [group([
      // App A: the request reaches the store.
      arrow({ from: [appL, Y1], to: [sideR, Y1] }),
      label({ x: (appL + sideR) / 2, y: Y1 - LABEL_GAP, text: 'orderdb-password', size: TEXT }),
      arrow({ from: [sideL, Y1], to: [lockR, Y1] }),

      // App B: the sidecar refuses it.
      arrow({ from: [appL, Y2], to: [sideR, Y2] }),
      label({ x: (appL + sideR) / 2, y: Y2 - LABEL_GAP, text: 'orderdb-password', size: TEXT }),
      label({ x: (appL + sideR) / 2, y: Y2 + LABEL_GAP, text: '403 PERMISSION_DENIED', size: TEXT }),

      // App B's sidecar loads config-app-b.yaml.
      arrow({ from: [SIDE_X, Y2 + SIDE_R + 1], to: [SIDE_X, DOC_Y - DOC / 2 - 1], head: false, gap: 0 }),
      icon({ name: 'fluent-document', x: SIDE_X, y: DOC_Y, size: DOC, color: C.navy, fit: 'ink' }),
      label({ x: SIDE_X - DOC_NAME_DX, y: DOC_Y, text: 'config-app-b.yaml', size: TEXT, anchor: 'end' }),
      ...CAPTION.map((text, i) => label({ x: SIDE_X, y: CAP_Y + i * LINE, text, size: TEXT, mono: true })),

      lockBox({ x: LOCK_X, y: Y1, size: LOCK }),
      label({ x: LOCK_X, y: Y1 + LOCK / 2 + NAME_GAP, text: 'secretstore', size: TEXT }),

      markHex({ x: SIDE_X, y: Y1, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      markHex({ x: SIDE_X, y: Y2, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      hex({ x: APP_X, y: Y1, r: APP_R, label: 'app-a', size: TEXT, ...APP[0] }),
      hex({ x: APP_X, y: Y2, r: APP_R, label: 'app-b', size: TEXT, ...APP[1] }),
    ])];
  },
};
