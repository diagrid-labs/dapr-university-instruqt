// dapr-101 page 4 (the Service Invocation API), section 3 "Inspect the
// `checkout` application", at the end: checkout calls its own sidecar with the
// app ID order-processor, the sidecar finds order-processor's sidecar by that
// app ID, and that sidecar passes POST /orders to the app.
//
// Elements, with each name as it appears in the demo (university-labs
// dapr-101/<lang>/<demo> at 18d67c0, read in dotnet/ServiceInvocation,
// python/service-invocation, java/service-invocation and
// javascript/service-invocation) and the assignment:
// - checkout: `appID: checkout` in every dapr.yaml (no `-sdk` suffix here; that
//   is page 5), no appPort: a console app. Green hexagon (APP[0]), house R 56.
// - order-processor: `appID: order-processor` in every dapr.yaml. Its appPort
//   differs per language (7001 .NET, 8001 Python, 9001 Java, 5001 JavaScript),
//   so no port is drawn. The second app, so the light blue hexagon (APP[1]),
//   larger than checkout because its 15-letter app ID needs it (R 76, as
//   subspace-beacon in bindings-4-subspace-beacon).
// - Dapr sidecar (two): markHex with the Dapr logo at the house sidecar size,
//   each apart from its app and named "Dapr sidecar" above it, as in
//   bindings-4-subspace-beacon. No sidecar ports: dapr.yaml sets no
//   daprHTTPPort, so the Dapr CLI picks them (section 2).
//
// Connections (the checkout code: Python app.py and JavaScript index.js post to
// `localhost:<DAPR_HTTP_PORT>/orders` with the header
// `dapr-app-id: order-processor`, Java CheckoutServiceApplication.java the same
// with HttpClient; .NET Program.cs `DaprClient.CreateInvokeHttpClient(appId:
// "order-processor")` then `PostAsJsonAsync("/orders", order)`):
// - checkout -> its own sidecar, labelled `POST /orders` and
//   `dapr-app-id: order-processor` (the header as the page's section 3 names it).
// - checkout's sidecar -> order-processor's sidecar, labelled
//   "name resolution (mDNS)": the sidecar finds the target by app ID; the page
//   names mDNS as the self-hosted default. A label on the arrow, not a box in
//   the path: the request does not pass through the resolver.
// - order-processor's sidecar -> order-processor, labelled `POST /orders`
//   (`app.MapPost("/orders")` in .NET Program.cs, `@app.route('/orders',
//   methods=['POST'])` in Python app.py).
// No reply arrow: the picture is the call going out, as in
// bindings-4-subspace-beacon.
//
// Layout: canvas 490 wide for the 424 px lab column, two rows of two. Top: the
// two sidecars (the call between Dapr). Bottom: each app under its own
// sidecar. checkout's labels sit right of its vertical arrow, in the open space
// between the columns; order-processor's route sits right of its arrow, as
// GET /ping in bindings-4. No step discs: the page does not number the steps.
import { APP, C } from '../_engine/engine.mjs';
import { arrow, group, hex, hexHalfWidth, label } from '../_engine/shapes.mjs';
import { markHex } from '../_engine/icons.mjs';

const TEXT = 13; // every label, as in 101-2, 101-3 and the secrets, pubsub and bindings scenes

const W = 490;
const M = 12; // canvas margin, as in the secrets and 101 scenes
const GLYPH = 0.37 * TEXT; // half a label's cap height
const LINE = 16; // line pitch of a two-line label

const APP_R = 56; // checkout, the house app radius
const OP_R = 76; // order-processor: its 15-letter name needs it, as subspace-beacon in bindings-4
const SIDE_R = 0.75 * APP_R; // the house sidecar size, both sidecars
const APP_HW = hexHalfWidth(APP_R);
const SIDE_HW = hexHalfWidth(SIDE_R);

const LABEL_GAP = 12; // an arrow's label this far from its arrow (about one character clear)

// Measured with measure-labels at 13 (weight 600, mono).
const ROUTE_W = 94; // "POST /orders"
const HEADER_W = 219; // "dapr-app-id: order-processor"

// Columns: checkout's labels run from its arrow to the right, and must end
// clear of order-processor's arrow; order-processor's route runs right of its
// arrow. The group is centred in the canvas.
const PITCH = LABEL_GAP + HEADER_W + 60; // column to column
const GROUP_L = APP_HW;
const GROUP_R = LABEL_GAP + ROUTE_W;
const X1 = (W - (GROUP_L + PITCH + GROUP_R)) / 2 + GROUP_L;
const X2 = X1 + PITCH;

// Rows.
const SIDE_NAME_DY = SIDE_R + 14; // "Dapr sidecar" above each sidecar, as in bindings-4
const Y1 = M + SIDE_NAME_DY + GLYPH; // sidecars
const ROW_GAP = 160; // sidecar row to app row, as in bindings-4
const Y2 = Y1 + ROW_GAP; // apps
const H = Math.ceil(Y2 + OP_R + M);

export default {
  width: W,
  height: H,
  title: 'checkout invokes order-processor through Dapr',
  desc:
    'Top row: two Dapr sidecars. Bottom row: a green hexagon labelled checkout under the left sidecar '
    + 'and a blue hexagon labelled order-processor under the right one. An arrow runs from checkout up '
    + 'to its sidecar, labelled POST /orders and dapr-app-id: order-processor. An arrow labelled name '
    + 'resolution (mDNS) runs from that sidecar to the sidecar of order-processor, and an arrow labelled '
    + 'POST /orders runs from there down to order-processor.',

  build() {
    const side1 = { x: X1, y: Y1, r: SIDE_R, hex: true };
    const side2 = { x: X2, y: Y1, r: SIDE_R, hex: true };
    const checkout = { x: X1, y: Y2, r: APP_R, hex: true };
    const op = { x: X2, y: Y2, r: OP_R, hex: true };

    const mid1 = (Y1 + SIDE_R + Y2 - APP_R) / 2; // checkout's vertical run
    const mid2 = (Y1 + SIDE_R + Y2 - OP_R) / 2; // order-processor's vertical run

    return [group([
      // checkout calls its own sidecar with the app ID.
      arrow({ from: checkout, to: side1 }),
      label({ x: X1 + LABEL_GAP, y: mid1 - LINE / 2, text: 'POST /orders', size: TEXT, anchor: 'start', mono: true }),
      label({ x: X1 + LABEL_GAP, y: mid1 + LINE / 2, text: 'dapr-app-id: order-processor', size: TEXT, anchor: 'start', mono: true }),

      // The sidecar finds order-processor's sidecar by app ID.
      arrow({ from: side1, to: side2 }),
      label({ x: (X1 + SIDE_HW + X2 - SIDE_HW) / 2, y: Y1 - LABEL_GAP, text: 'name resolution (mDNS)', size: TEXT }),

      // order-processor's sidecar passes the request to the app.
      arrow({ from: side2, to: op }),
      label({ x: X2 + LABEL_GAP, y: mid2, text: 'POST /orders', size: TEXT, anchor: 'start', mono: true }),

      markHex({ x: X1, y: Y1, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      label({ x: X1, y: Y1 - SIDE_NAME_DY, text: 'Dapr sidecar', size: TEXT }),
      markHex({ x: X2, y: Y1, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      label({ x: X2, y: Y1 - SIDE_NAME_DY, text: 'Dapr sidecar', size: TEXT }),
      hex({ x: X1, y: Y2, r: APP_R, label: 'checkout', size: TEXT, ...APP[0] }),
      hex({ x: X2, y: Y2, r: OP_R, label: 'order-processor', size: TEXT, ...APP[1] }),
    ])];
  },
};
