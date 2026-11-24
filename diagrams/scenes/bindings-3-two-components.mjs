// dapr-bindings page 3 (State API vs binding), section 1 "Two components, one
// database": the engineering app's sidecar loads two components that both reach
// the same PostgreSQL database, and each writes its own table there. Built from
// bindings-2-output (same app, sidecar and database parts).
//
// Elements, with each name as it appears in the demo
// (git -C ~/dev/diagrid-labs/university-labs show ec9104c:bindings/...):
// - engineering: `appID: engineering` in Demo3-StateVsBinding/dapr.yaml (and the
//   python and java equivalents), appPort 5201. Green hexagon, as in bindings-2.
// - Dapr sidecar: markHex with the Dapr logo, apart from the app.
// - statestore: `metadata.name: statestore` in <lang>/resources/statestore.yaml,
//   `type: state.postgresql`. The app passes the name to the State API
//   (Program.cs `StateStore = "statestore"` -> SaveStateAsync, app.py
//   STATE_STORE, ReadingController STATE_STORE). Label above the upper arrow,
//   with `state.postgresql` as the second line (the component type, as in the
//   YAML).
// - ship-db: the shared component of ../resources, `bindings.postgresql`; the
//   handler inserts through its `exec` operation. Label above the lower arrow,
//   with `exec` as the second line.
// - PostgreSQL: one gold cylinder, named "PostgreSQL" under it as in
//   bindings-2, with the elephant mark on its lid (moved there from the body to
//   leave the body for the two tables).
// - state: the table Dapr creates for the state store (assignment section 4:
//   `\d state`, "Table public.state"; the statestore.yaml comment says "it
//   creates a `state` table"). A table pill inside the cylinder, where the
//   statestore arrow lands.
// - warp_core_readings: the app's own table, written by the exec INSERT. A
//   table pill inside the cylinder, where the ship-db arrow lands.
//
// Connections: engineering -> Dapr sidecar; the sidecar -> state through
// statestore (upper arrow) and -> warp_core_readings through ship-db (lower
// arrow). Each arrow runs level from the sidecar and ends on its own table, so
// the picture reads as one database, two components, two tables. The handler
// calls the State API first and the binding second, but the picture is the two
// paths, so the arrows carry no order.
//
// Label placement: each two-line block sits ABOVE its own arrow, 7.5 units
// clear of it, and the ship-db block is 18.5 units clear of the statestore
// arrow above it, so each block is plainly nearest its own arrow and no two
// blocks share a row. "Dapr sidecar" and "PostgreSQL" sit below everything.
//
// Departures from the skill, on purpose: canvas 500 wide for the 424 px lab
// column; the sidecar stands apart from the app (as in bindings-2-output); the
// cylinder is given by top/bottom rather than STORE_RATIO, deeper than usual,
// so that its front holds both table pills; the app -> sidecar run is shorter
// than in bindings-2 (30, not 46) to give the wide cylinder its room.
import { APP, C } from '../_engine/engine.mjs';
import { arrow, cylinder, group, hex, hexHalfWidth, hexHalfWidthAt, label, pill } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13;

const W = 500;

const APP_R = 56; // as in bindings-2-output
const SIDE_R = 0.75 * APP_R;
const GLYPH = 0.37 * TEXT; // half a line's glyph box, about
const LINE = 17; // line to line in a two-line label
const LABEL_GAP = 14; // a block's lower line centre above its arrow
const CLEAR = 13; // two characters of clearance to a shape

// "warp_core_readings" at 13 (weight 600), measured in bindings-2-output; a pill
// is its text plus half an em at each end.
const TABLE_W = 128 + TEXT;
const TABLE_H = 22;
// "state.postgresql" at 13, the widest arrow label.
const WIDE_LABEL = 104;

const DB_RX = 79; // the cylinder's half width: a table pill plus 8.5 each side
const DB_RY = 16; // rim depth
const FAN = 28; // each arrow runs this far above or below the row
const TOP_DY = 62; // lid centre above the row: the lid's front edge clears the upper pill by 7
const BOTTOM_DY = 58; // base centre below the row: the hidden back rim of the base (BOTTOM_DY - DB_RY) passes 3 under the lower pill, not through it

const RUN1 = 30; // app -> sidecar, no label
// sidecar -> cylinder: the statestore block, cleared from the sidecar's widest
// point and from the cylinder wall.
const RUN2 = CLEAR + WIDE_LABEL + CLEAR - 12; // its lower line sits where the sidecar has narrowed by 12

const APP_TO_SIDE = hexHalfWidth(APP_R) + RUN1 + hexHalfWidth(SIDE_R);
const SIDE_TO_DB = hexHalfWidth(SIDE_R) + RUN2 + DB_RX;
const GROUP_W = hexHalfWidth(APP_R) + APP_TO_SIDE + SIDE_TO_DB + DB_RX;
const APP_X = (W - GROUP_W) / 2 + hexHalfWidth(APP_R);
const SIDE_X = APP_X + APP_TO_SIDE;
const DB_X = SIDE_X + SIDE_TO_DB;
const DB_LEFT = DB_X - DB_RX;
const TABLE_LEFT = DB_X - TABLE_W / 2;

// Arrow labels: centred between the cylinder wall (less clearance) and the
// widest label's half width, so both blocks line up on one x.
const LABEL_X = DB_LEFT - CLEAR - WIDE_LABEL / 2;

const M = 12;
const TOP = TOP_DY + DB_RY; // the lid's top is the highest point
const NAME_DY = BOTTOM_DY + DB_RY + 16; // "PostgreSQL" under the base, as in bindings-2
const BOTTOM = NAME_DY + GLYPH;
const Y = M + TOP;
const H = Math.ceil(Y + BOTTOM + M);

const MARK = 24; // the elephant, fitted by its ink inside the lid (32 deep)

export default {
  width: W,
  height: H,
  title: 'The engineering app saves a reading through statestore and ship-db',
  desc:
    'From left to right: a green hexagon labelled engineering, an arrow to a Dapr sidecar, '
    + 'and two arrows from the sidecar into one gold data store named PostgreSQL, with the '
    + 'PostgreSQL mark on its lid and two tables inside it. The upper arrow, labelled statestore, '
    + 'state.postgresql, ends on the table state; the lower arrow, labelled ship-db, exec, ends on '
    + 'the table warp_core_readings.',

  build() {
    const app = { x: APP_X, y: Y, r: APP_R, hex: true };
    const side = { x: SIDE_X, y: Y, r: SIDE_R, hex: true };
    const sideEdge = (dy) => SIDE_X + hexHalfWidthAt(SIDE_R, dy) + 2;
    return [group([
      arrow({ from: app, to: side }),
      hex({ x: APP_X, y: Y, r: APP_R, label: 'engineering', size: TEXT, ...APP[0] }),
      markHex({ x: SIDE_X, y: Y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      label({ x: SIDE_X, y: Y + SIDE_R + 16, text: 'Dapr sidecar', size: TEXT }),
      cylinder({ x: DB_X, top: Y - TOP_DY, bottom: Y + BOTTOM_DY, rx: DB_RX, ry: DB_RY }),
      icon({ name: 'postgresql', x: DB_X, y: Y - TOP_DY, size: MARK, fit: 'ink' }),
      label({ x: DB_X, y: Y + NAME_DY, text: 'PostgreSQL', size: TEXT }),
      pill({ x: DB_X, y: Y - FAN, w: TABLE_W, h: TABLE_H, text: 'state', size: TEXT }),
      pill({ x: DB_X, y: Y + FAN, w: TABLE_W, h: TABLE_H, text: 'warp_core_readings', size: TEXT }),
      arrow({ from: [sideEdge(FAN), Y - FAN], to: [TABLE_LEFT - 2, Y - FAN] }),
      arrow({ from: [sideEdge(FAN), Y + FAN], to: [TABLE_LEFT - 2, Y + FAN] }),
      label({ x: LABEL_X, y: Y - FAN - LABEL_GAP - LINE, text: 'statestore', size: TEXT }),
      label({ x: LABEL_X, y: Y - FAN - LABEL_GAP, text: 'state.postgresql', size: TEXT }),
      label({ x: LABEL_X, y: Y + FAN - LABEL_GAP - LINE, text: 'ship-db', size: TEXT }),
      label({ x: LABEL_X, y: Y + FAN - LABEL_GAP, text: 'exec', size: TEXT }),
    ])];
  },
};
