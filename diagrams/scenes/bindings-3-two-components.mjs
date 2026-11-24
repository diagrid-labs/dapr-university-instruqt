// dapr-bindings page 3 (State API vs binding), section 1 "Two components, one
// database": the engineering app's sidecar loads two components that both reach
// the same PostgreSQL database. Built from bindings-2-output (same app,
// sidecar and database parts and sizes).
//
// Elements, with each name as it appears in the demo
// (git -C ~/dev/diagrid-labs/university-labs show ec9104c:bindings/...):
// - engineering: `appID: engineering` in Demo3-StateVsBinding/dapr.yaml (and the
//   python and java equivalents), appPort 5201. Green hexagon, as in bindings-2.
// - Dapr sidecar: markHex with the Dapr logo, apart from the app.
// - statestore: `metadata.name: statestore` in <lang>/resources/statestore.yaml,
//   `type: state.postgresql`. The app passes the name to the State API
//   (Program.cs `StateStore = "statestore"` -> SaveStateAsync, app.py
//   STATE_STORE, ReadingController STATE_STORE). Label on the upper arrow, with
//   `state.postgresql` as the second line (the component type, as in the YAML).
// - ship-db: the shared component of ../resources, `bindings.postgresql`; the
//   handler inserts through its `exec` operation. Label on the lower arrow with
//   `exec` as the second line.
// - PostgreSQL: one gold cylinder with the elephant mark, as in bindings-2.
// - state: the table Dapr creates for the state store (assignment section 4:
//   `\d state`, "Table public.state"; the statestore.yaml comment says "it
//   creates a `state` table"). Above the cylinder, next to the upper arrow.
// - warp_core_readings: the app's own table, written by the exec INSERT. Below
//   the cylinder, next to the lower arrow.
//
// Connections: engineering -> Dapr sidecar; the sidecar fans out to the one
// database through statestore (upper arrow) and ship-db (lower arrow). The
// handler calls the State API first and the binding second, but the picture is
// the two paths, so the arrows carry no order.
//
// Departures from the skill, on purpose: canvas 480 wide for the 424 px lab
// column; the sidecar stands apart from the app (as in bindings-2-output); the
// two arrows leave the sidecar from one point and land on the cylinder's upper
// and lower left; table names sit above and below the cylinder and the shape
// carries no "PostgreSQL" name line (the mark is the name, as in the alt text),
// to keep the row at three shapes within the column.
import { APP, C } from '../_engine/engine.mjs';
import { arrow, cylinder, group, hex, hexHalfWidth, label, STORE_RATIO } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13;

const W = 480;
const M = 12;

const APP_R = 56; // as in bindings-2-output
const SIDE_R = 0.75 * APP_R;
const DB_W = 84;
const DB_H = DB_W / STORE_RATIO;
const MARK = 40;
const RUN1 = 46; // app -> sidecar, no label
const RUN2 = 124; // sidecar -> database, holds "state.postgresql" (about 104 wide)
const LINE = 17; // line to line in a two-line label
const GLYPH = 0.37 * TEXT;
const FAN = 22; // each arrow lands this far above or below the cylinder's centre
const ARROW_GAP = 3;

const APP_TO_SIDE = hexHalfWidth(APP_R) + RUN1 + hexHalfWidth(SIDE_R);
const SIDE_TO_DB = hexHalfWidth(SIDE_R) + RUN2 + DB_W / 2;
const GROUP_L = hexHalfWidth(APP_R);
const GROUP_R = DB_W / 2 + 6;
const APP_X = W / 2 - (GROUP_L + APP_TO_SIDE + SIDE_TO_DB + GROUP_R) / 2 + GROUP_L;
const SIDE_X = APP_X + APP_TO_SIDE;
const DB_X = SIDE_X + SIDE_TO_DB;

// Vertical: the row sits at Y; the upper label block (two lines) sits above the
// upper arrow, the lower block below the lower arrow.
const TABLE_DY = DB_H / 2 + 14; // a table name above or below the cylinder
const TOP = Math.max(APP_R, TABLE_DY + GLYPH, FAN + 2 * LINE + 4);
const BOTTOM = Math.max(APP_R + 16 + GLYPH, TABLE_DY + GLYPH, FAN + 2 * LINE + 4);
const Y = M + TOP;
const H = Y + BOTTOM + M;

const DB_LEFT = DB_X - DB_W / 2 - ARROW_GAP;
const RUN2_X = (SIDE_X + hexHalfWidth(SIDE_R) + DB_LEFT) / 2;
const MID_X = RUN2_X - 6; // fan labels, nudged to the sidecar side where the arrows are apart

export default {
  width: W,
  height: H,
  title: 'The engineering app saves a reading through statestore and ship-db',
  desc:
    'From left to right: a green hexagon labelled engineering, an arrow to a Dapr sidecar, '
    + 'and two arrows from the sidecar to one gold data store with the PostgreSQL mark: the upper '
    + 'arrow labelled statestore, state.postgresql, with the table state above the store, and the '
    + 'lower arrow labelled ship-db, exec, with the table warp_core_readings below it.',

  build() {
    const app = { x: APP_X, y: Y, r: APP_R, hex: true };
    const side = { x: SIDE_X, y: Y, r: SIDE_R, hex: true };
    return [group([
      arrow({ from: app, to: side }),
      arrow({ from: side, to: [DB_LEFT, Y - FAN] }),
      arrow({ from: side, to: [DB_LEFT, Y + FAN] }),
      hex({ x: APP_X, y: Y, r: APP_R, label: 'engineering', size: TEXT, ...APP[0] }),
      markHex({ x: SIDE_X, y: Y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      label({ x: SIDE_X, y: Y + SIDE_R + 16, text: 'Dapr sidecar', size: TEXT }),
      label({ x: MID_X, y: Y - FAN - 2 * LINE + 8, text: 'statestore', size: TEXT }),
      label({ x: MID_X, y: Y - FAN - LINE + 8, text: 'state.postgresql', size: TEXT }),
      label({ x: MID_X, y: Y + FAN + LINE + 2, text: 'ship-db', size: TEXT }),
      label({ x: MID_X, y: Y + FAN + 2 * LINE + 2, text: 'exec', size: TEXT }),
      cylinder({ x: DB_X, y: Y, w: DB_W }),
      icon({ name: 'postgresql', x: DB_X, y: Y, size: MARK, fit: 'ink' }),
      label({ x: DB_X, y: Y - TABLE_DY, text: 'state', size: TEXT }),
      label({ x: DB_X, y: Y + TABLE_DY, text: 'warp_core_readings', size: TEXT }),
    ])];
  },
};
