// dapr-bindings page 4 (bindings with service invocation), section 1 "Two
// apps, three building blocks": what happens on one tick of the cron, in three
// numbered steps. Built from the parts of bindings-1-cron (clock mark),
// bindings-2-output (app, sidecar) and bindings-3-two-components (PostgreSQL
// cylinder with the elephant on its lid and a table pill inside).
//
// Elements, with each name as it appears in the demo
// (git -C ~/dev/diagrid-labs/university-labs show ec9104c:bindings/...):
// - beacon-ping: the cron input binding, `metadata.name: beacon-ping` in
//   <lang>/<demo4>/resources/beacon-ping.yaml (all three languages), type
//   bindings.cron, `schedule: "@every 5s"`, `scopes: [engineering]`, so only
//   engineering's sidecar loads it. The Fluent clock mark in the house blue, as
//   in bindings-1-cron, with the name and the schedule ABOVE it (not under it as
//   in bindings-1-cron): below the clock is where step 3's labels go.
// - engineering: `appID: engineering` in <demo4>/dapr.yaml, appPort 5201. Green
//   hexagon (APP[0]), the same size as in bindings-1 to 3.
// - subspace-beacon: `appID: subspace-beacon` in <demo4>/dapr.yaml, appPort
//   5202, a plain HTTP app with no Dapr SDK. The second app, so the light blue
//   hexagon (APP[1]). Larger than engineering: its 15-letter app ID needs it.
// - Dapr sidecar (two): engineering's (daprHTTPPort 3520) and the beacon's
//   (3521). markHex with the Dapr logo, apart from their apps as in bindings-1
//   to 3, each named "Dapr sidecar" above it (the line below is taken by the
//   arrow to its app).
// - GET /ping: the beacon's route, `app.MapGet("/ping")` (.NET
//   SubspaceBeacon/Program.cs), `@app.get("/ping")` (Python), `@GetMapping("/ping")`
//   (Java BeaconController). Label on the beacon sidecar -> beacon arrow.
// - ship-db: the shared output binding, <lang>/resources/ship-db.yaml, type
//   bindings.postgresql. The handler inserts with its `exec` operation
//   (ShipDb.cs / ShipDb.java `BINDING = "ship-db"`, app.py ShipDb.BINDING).
//   Label on the sidecar -> PostgreSQL arrow.
// - PostgreSQL with comms_log: `INSERT INTO comms_log ...` (Sql.InsertPing in
//   ShipDb.cs, INSERT_PING in app.py and ShipDb.java). Gold cylinder, elephant on
//   the lid, the table as a pill inside, as in bindings-3.
//
// Connections, numbered by step of one tick (the /beacon-ping handler in
// Program.cs, app.py and PingController.java):
// 1 input binding: beacon-ping -> engineering's sidecar -> engineering
//   (`POST /beacon-ping`, the route is the component name).
// 2 service invocation: engineering -> its own sidecar -> the beacon's sidecar
//   -> subspace-beacon `GET /ping`. The app only names the app ID: .NET
//   `DaprClient.CreateInvokeHttpClient("subspace-beacon")`, Python
//   `invoke_method("subspace-beacon", "ping", http_verb="GET")`, Java a RestClient
//   on `localhost:<DAPR_HTTP_PORT>` with the `dapr-app-id: subspace-beacon`
//   header. So engineering's sidecar makes the call, not the app.
// 3 output binding: engineering's sidecar -> ship-db -> comms_log (the app calls
//   its sidecar with the binding name; the sidecar runs the INSERT).
// Every arrow of a step carries that step's number in a step mark. The app ->
// sidecar arrow carries steps 2 and 3: the app calls its own sidecar both for the
// invocation and for the ship-db insert (`shipDb.ExecAsync` via DaprClient in
// .NET, `invoke_binding("ship-db", "exec", ...)` in Python), so two discs, 2
// above 3, stand beside it.
// No reply arrows: the beacon's answer comes back on step 2's call, and the
// picture is the calls going out, as in bindings-1 to 3.
//
// Layout: two rows of three, no more. Top: clock, engineering's sidecar, the
// beacon's sidecar (the calls between Dapr). Bottom: PostgreSQL, engineering,
// subspace-beacon, each app under its own sidecar. Step 3 is the one diagonal,
// from the sidecar down to the store's rect (it ends on the lid, not on the
// comms_log pill: a line into the pill would cross the lid and the wall). Its
// step mark and ship-db sit on the upper-left side of the diagonal, clear of the
// two vertical arrows on the other side.
//
// Departures from the skill, on purpose: canvas 500 wide for the 424 px lab
// column; sidecars stand apart from their apps (as in bindings-1 to 3); the
// ports are left out for readability at 424 px (they are in the assignment
// text).
import { APP, C } from '../_engine/engine.mjs';
import { arrow, cylinder, group, hex, hexEdgeAt, hexHalfWidth, label, pill, stepMark } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13;

const W = 500;
const M = 12;

const APP_R = 56; // engineering, as in bindings-1 to 3
const BEACON_R = 76; // "subspace-beacon" at 13 (measured below) plus clearance to the sloping edges
const SIDE_R = 0.75 * APP_R; // house sidecar size relation, both sidecars
const MARK = 44; // clock mark, as in bindings-1-cron
const LINE = 17; // line to line in a two-line label
const GLYPH = 0.37 * TEXT;
const STEP = 11; // step mark radius: a 13-unit digit in a 22-unit disc
const STEP_GAP = 6; // step mark edge to its arrow

// Measured with measure-labels at 13 (weight 600).
const CRON_NAME_W = 80; // "beacon-ping"
const ROUTE_W = 62; // "GET /ping"
const TABLE_W = 72 + TEXT; // "comms_log" pill: text plus half an em at each end
const TABLE_H = 22;

// PostgreSQL, the cylinder form of bindings-3: a pill plus 9 each side.
const DB_RX = TABLE_W / 2 + 9;
const DB_RY = 16;
const DB_MARK = 24; // the elephant on the lid, as in bindings-3

// Columns.
const RUN_H1 = 110; // clock -> engineering's sidecar, holds a step mark above it
const RUN_H2 = 80; // sidecar -> sidecar, holds a step mark above it
const X1_TO_X2 = MARK / 2 + RUN_H1 + hexHalfWidth(SIDE_R);
const X2_TO_X3 = 2 * hexHalfWidth(SIDE_R) + RUN_H2;
const GROUP_L = Math.max(DB_RX, CRON_NAME_W / 2);
const ROUTE_DX = 12; // a label beside a vertical run, one character clear of it
const GROUP_R = Math.max(hexHalfWidth(BEACON_R), ROUTE_DX + ROUTE_W);
const GROUP_W = GROUP_L + X1_TO_X2 + X2_TO_X3 + GROUP_R;
const X1 = (W - GROUP_W) / 2 + GROUP_L;
const X2 = X1 + X1_TO_X2;
const X3 = X2 + X2_TO_X3;

// Rows.
const ROW_GAP = 160; // top row centre to bottom row centre
const SIDE_NAME_DY = SIDE_R + 14; // "Dapr sidecar" above each sidecar
const TOP = SIDE_NAME_DY + GLYPH;
const Y1 = M + TOP;
const Y2 = Y1 + ROW_GAP;
const H = Math.ceil(Y2 + BEACON_R + M);

// The clock's name block above it, its upper line level with "Dapr sidecar"
// (the lower line then sits 12 clear of the mark).
const CRON_NAME_DY = SIDE_NAME_DY - LINE;
const D3 = STEP + STEP_GAP + 2; // step 3's mark off the diagonal's centre line
const T3 = 0.62; // step 3's mark along the centre line: about the middle of the drawn run, which starts at the sidecar's edge
const V_DX = 12; // the two vertical arrows between engineering and its sidecar, either side of the centre line

export default {
  width: W,
  height: H,
  title: 'One tick of beacon-ping: input binding, service invocation, output binding',
  desc:
    'Top row from left to right: a clock mark named beacon-ping with the schedule @every 5s, '
    + 'the Dapr sidecar of engineering and the Dapr sidecar of subspace-beacon. Bottom row: a gold '
    + 'data store named PostgreSQL with the table comms_log inside, a green hexagon labelled '
    + 'engineering under its sidecar, and a blue hexagon labelled subspace-beacon under its sidecar. '
    + 'Step 1: an arrow from the clock to engineering\'s sidecar and from that sidecar down to '
    + 'engineering. Step 2: an arrow from engineering up to its sidecar, across to the beacon\'s '
    + 'sidecar, and down to subspace-beacon, labelled GET /ping. Step 3: engineering calls its own '
    + 'sidecar again (the same arrow carries steps 2 and 3), and an arrow labelled ship-db goes from '
    + 'that sidecar to the PostgreSQL store that holds the comms_log table.',

  build() {
    const clock = { x: X1, y: Y1, w: MARK, h: MARK };
    const side = { x: X2, y: Y1, r: SIDE_R, hex: true };
    const beaconSide = { x: X3, y: Y1, r: SIDE_R, hex: true };
    const beacon = { x: X3, y: Y2, r: BEACON_R, hex: true };
    const dbTop = Y2 - 30;
    const dbBottom = Y2 + 28;
    const tableY = Y2 + 8;
    const db = { x: X1, y: (dbTop + dbBottom) / 2, w: 2 * DB_RX, h: dbBottom - dbTop + 2 * DB_RY };

    // The two vertical arrows between engineering and its sidecar.
    const sideLow = (dx) => Y1 + hexEdgeAt(SIDE_R, dx) + 2;
    const appHigh = (dx) => Y2 - hexEdgeAt(APP_R, dx) - 2;
    const vMid = (sideLow(V_DX) + appHigh(V_DX)) / 2;
    // The beacon's vertical arrow.
    const bMid = (Y1 + SIDE_R + Y2 - BEACON_R) / 2;
    // Step 3's diagonal, from the sidecar to the top of the store's rect. Its
    // step mark and ship-db sit above it, on the side away from engineering
    // and its two vertical arrows, under the clock (whose name is above it).
    const dTop = db.y - db.h / 2;
    const ux = X1 - X2;
    const uy = dTop - Y1;
    const len = Math.hypot(ux, uy);
    const nx = -uy / len; // the unit normal pointing up and left
    const ny = ux / len;
    const p3 = { x: X2 + T3 * ux + D3 * nx, y: Y1 + T3 * uy + D3 * ny };

    return [group([
      // step 1
      arrow({ from: clock, to: side }),
      arrow({ from: [X2 - V_DX, sideLow(V_DX)], to: [X2 - V_DX, appHigh(V_DX)] }),
      stepMark({ x: (X1 + MARK / 2 + X2 - hexHalfWidth(SIDE_R)) / 2, y: Y1 - STEP - STEP_GAP, step: 1, r: STEP, size: TEXT }),
      stepMark({ x: X2 - V_DX - STEP_GAP - STEP, y: vMid, step: 1, r: STEP, size: TEXT }),
      // step 2
      arrow({ from: [X2 + V_DX, appHigh(V_DX)], to: [X2 + V_DX, sideLow(V_DX)] }),
      arrow({ from: side, to: beaconSide }),
      arrow({ from: beaconSide, to: beacon }),
      stepMark({ x: X2 + V_DX + STEP_GAP + STEP, y: vMid - STEP - 2, step: 2, r: STEP, size: TEXT }),
      stepMark({ x: X2 + V_DX + STEP_GAP + STEP, y: vMid + STEP + 2, step: 3, r: STEP, size: TEXT }),
      stepMark({ x: (X2 + X3) / 2, y: Y1 - STEP - STEP_GAP, step: 2, r: STEP, size: TEXT }),
      stepMark({ x: X3 - STEP_GAP - STEP, y: bMid, step: 2, r: STEP, size: TEXT }),
      label({ x: X3 + ROUTE_DX, y: bMid, text: 'GET /ping', size: TEXT, anchor: 'start' }),
      // step 3
      arrow({ from: side, to: db }),
      stepMark({ x: p3.x, y: p3.y, step: 3, r: STEP, size: TEXT }),
      label({ x: p3.x - STEP - 6, y: p3.y, text: 'ship-db', size: TEXT, anchor: 'end' }),

      // shapes
      icon({ name: 'fluent-clock', x: X1, y: Y1, size: MARK, color: C.blue, fit: 'ink' }),
      label({ x: X1, y: Y1 - CRON_NAME_DY - LINE, text: 'beacon-ping', size: TEXT }),
      label({ x: X1, y: Y1 - CRON_NAME_DY, text: '@every 5s', size: TEXT }),
      markHex({ x: X2, y: Y1, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      label({ x: X2, y: Y1 - SIDE_NAME_DY, text: 'Dapr sidecar', size: TEXT }),
      markHex({ x: X3, y: Y1, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      label({ x: X3, y: Y1 - SIDE_NAME_DY, text: 'Dapr sidecar', size: TEXT }),
      hex({ x: X2, y: Y2, r: APP_R, label: 'engineering', size: TEXT, ...APP[0] }),
      hex({ x: X3, y: Y2, r: BEACON_R, label: 'subspace-beacon', size: TEXT, ...APP[1] }),
      cylinder({ x: X1, top: dbTop, bottom: dbBottom, rx: DB_RX, ry: DB_RY }),
      icon({ name: 'postgresql', x: X1, y: dbTop, size: DB_MARK, fit: 'ink' }),
      pill({ x: X1, y: tableY, w: TABLE_W, h: TABLE_H, text: 'comms_log', size: TEXT }),
      label({ x: X1, y: dbBottom + DB_RY + 16, text: 'PostgreSQL', size: TEXT }),
    ])];
  },
};
