// dapr-bindings page 2 (PostgreSQL output binding), section 2 "The output
// binding component": the output-binding row of bindings-1-directions made
// concrete. It runs the other way from bindings-1-cron: the app calls out.
//
// Elements, with each name as it appears in the demo
// (git -C ~/dev/diagrid-labs/university-labs show ec9104c:bindings/...):
// - engineering: `appID: engineering` in dapr.yaml of every language, appPort
//   5201. A solid green hexagon with the app ID inside in dark ink, the same
//   size as in bindings-1-cron.
// - Dapr sidecar: markHex with the Dapr logo, standing apart from the app as in
//   bindings-1-cron.
// - ship-db: the component, `metadata.name: ship-db` in <lang>/resources/ship-db.yaml,
//   type bindings.postgresql, `direction: output`. The app only passes this name
//   (ShipDb.cs `Binding = "ship-db"`, ShipDb.java `BINDING = "ship-db"`, the
//   Python wrapper likewise). Drawn as a label on the sidecar -> database arrow,
//   see "ship-db placement" below.
// - exec, query: the two operations the app uses in this demo, from ShipDb.cs
//   (`InvokeAsync("exec", ...)`, `InvokeAsync("query", ...)`) and ShipDb.java
//   (`request("exec", ...)`, `request("query", ...)`). The purge is an exec too
//   (`PurgeReadings` runs through `ExecAsync`), so it adds no third operation.
// - PostgreSQL: the database the component reaches, `type: bindings.postgresql`
//   and the postgres:18.7 container of the assignment. A gold data store (the
//   house look for stores, as the Redis store in workflow-101-1-architecture)
//   with the PostgreSQL elephant (postgresql.svg, a shipped brand mark) inside.
//   Named "PostgreSQL" under it.
// - warp_core_readings: the table, `Sql.InsertReading`/`SelectReadings`/
//   `PurgeReadings` all use `warp_core_readings`. Second line under the name.
//
// Connections: engineering -> Dapr sidecar (the binding call) -> PostgreSQL via
// ship-db (the sidecar runs the SQL against the database). No reply arrows:
// the `query` rows come back, but the picture is the call going out, as in
// bindings-1-cron.
//
// ship-db placement: a label on the sidecar -> database arrow ("ship-db" above
// the line, "exec / query" below it), not a fourth shape. The row already holds
// three shapes (app, sidecar, database), the maximum, and a component shape
// between the sidecar and the database would make four. A binding component
// lives inside the sidecar, so the arrow it labels is the right place for its
// name, and the operations belong to the same call.
//
// Departures from the skill, on purpose: canvas 480 wide for the 424 px lab
// column; the sidecar stands apart from the app (as in bindings-1-directions).
import { APP, C } from '../_engine/engine.mjs';
import { arrow, cylinder, group, hex, hexHalfWidth, label, STORE_RATIO } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13;

const W = 480;
const M = 12;

const APP_R = 56; // as in bindings-1-cron
const SIDE_R = 0.75 * APP_R; // house sidecar size relation
const DB_W = 84; // the store, STORE_RATIO wide to tall
const DB_H = DB_W / STORE_RATIO;
const MARK = 40; // the elephant, fitted by its ink inside the cylinder body
const NAME_DY = DB_H / 2 + 16; // a name under the store
const LINE = 17; // line to line in a two-line label
const GLYPH = 0.37 * TEXT;
const RUN1 = 46; // app -> sidecar, no label
const RUN2 = 118; // sidecar -> database, holds "exec / query" (measured width below)
const LABEL_DY = 15; // a label's centre above or below its arrow

// "warp_core_readings" at 13 (weight 600), measured; the widest label on the right.
const TABLE_W = 128;
const APP_TO_SIDE = hexHalfWidth(APP_R) + RUN1 + hexHalfWidth(SIDE_R);
const SIDE_TO_DB = hexHalfWidth(SIDE_R) + RUN2 + DB_W / 2;
const GROUP_L = hexHalfWidth(APP_R);
const GROUP_R = SIDE_TO_DB + Math.max(DB_W / 2, TABLE_W / 2);
const APP_X = W / 2 - (GROUP_L + APP_TO_SIDE + GROUP_R) / 2 + GROUP_L;
const SIDE_X = APP_X + APP_TO_SIDE;
const DB_X = SIDE_X + SIDE_TO_DB;

const GROUP_T = APP_R;
const GROUP_B = NAME_DY + LINE + GLYPH;
const Y = M + GROUP_T;
const H = Y + GROUP_B + M;

const RUN2_X = (SIDE_X + hexHalfWidth(SIDE_R) + DB_X - DB_W / 2) / 2;

export default {
  width: W,
  height: H,
  title: 'The engineering app calls the ship-db output binding',
  desc:
    'From left to right: a green hexagon labelled engineering, an arrow to a Dapr sidecar, '
    + 'and an arrow labelled ship-db, exec / query from the sidecar to a gold data store with '
    + 'the PostgreSQL mark, named PostgreSQL with the table warp_core_readings under it.',

  build() {
    const app = { x: APP_X, y: Y, r: APP_R, hex: true };
    const side = { x: SIDE_X, y: Y, r: SIDE_R, hex: true };
    const db = { x: DB_X, y: Y, w: DB_W, h: DB_H };
    return [group([
      arrow({ from: app, to: side }),
      arrow({ from: side, to: db }),
      hex({ x: APP_X, y: Y, r: APP_R, label: 'engineering', size: TEXT, ...APP[0] }),
      markHex({ x: SIDE_X, y: Y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      label({ x: SIDE_X, y: Y + SIDE_R + 16, text: 'Dapr sidecar', size: TEXT }),
      label({ x: RUN2_X, y: Y - LABEL_DY, text: 'ship-db', size: TEXT }),
      label({ x: RUN2_X, y: Y + LABEL_DY, text: 'exec / query', size: TEXT }),
      cylinder({ x: DB_X, y: Y, w: DB_W }),
      icon({ name: 'postgresql', x: DB_X, y: Y, size: MARK, fit: 'ink' }),
      label({ x: DB_X, y: Y + NAME_DY, text: 'PostgreSQL', size: TEXT }),
      label({ x: DB_X, y: Y + NAME_DY + LINE, text: 'warp_core_readings', size: TEXT }),
    ])];
  },
};
