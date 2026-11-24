// dapr-bindings page 1 (cron input binding), section 2 "The component and the
// handler": the input-binding row of bindings-1-directions made concrete.
//
// Elements, with each name as it appears in the demo
// (git -C ~/dev/diagrid-labs/university-labs show ec9104c:bindings/...):
// - warp-core-scan: the component, `metadata.name: warp-core-scan` in
//   resources/warp-core-scan.yaml (all three languages), type bindings.cron,
//   `schedule: "@every 10s"`. Drawn as the Fluent clock mark in the house blue
//   (the source is a timer, an outside "system" like the server mark in
//   bindings-1-directions), named under it with the schedule on a second line.
// - Dapr sidecar: the sidecar of engineering. markHex with the Dapr logo, as in
//   bindings-1-directions, standing apart from the app.
// - engineering: `appID: engineering` in dapr.yaml of every language, appPort
//   5201. A solid green hexagon with the app ID inside in dark ink.
// - POST /warp-core-scan: the route on the sidecar -> app arrow. The handler is
//   `app.MapPost("/warp-core-scan")` (.NET Program.cs), `@app.post("/warp-core-scan")`
//   (Python app.py) and `@PostMapping("/warp-core-scan")` (Java ScanController).
//
// Connections: warp-core-scan -> Dapr sidecar (the component lives in the
// sidecar and fires on the schedule), Dapr sidecar -> engineering (POST route).
// No reply arrow: the app answers 200, but the picture is the tick going in.
//
// Departures from the skill, on purpose: canvas 480 wide for the 424 px lab
// column; the sidecar stands apart from the app (as in bindings-1-directions);
// the route label is two lines (POST / route) so the arrow stays short.
import { APP, C } from '../_engine/engine.mjs';
import { arrow, group, hex, hexHalfWidth, label } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13;

const W = 480;
const M = 12;

const APP_R = 56; // "engineering" at 13 is wider than the 44 of bindings-1-directions' "app" allows
const SIDE_R = 0.75 * APP_R; // house sidecar size relation
const MARK = 44; // clock mark, same size as the server mark in bindings-1-directions
const NAME_DY = SIDE_R + 16; // name under a shape, as in bindings-1-directions
const LINE = 17; // line to line in a two-line label
const GLYPH = 0.37 * TEXT;
const RUN1 = 70; // clock -> sidecar
const RUN2 = 118; // sidecar -> app, holds the route label

const SRC_NAME_W = 101; // "warp-core-scan" at 13 (weight 600), measured

const SRC_TO_SIDE = MARK / 2 + RUN1 + hexHalfWidth(SIDE_R);
const SIDE_TO_APP = hexHalfWidth(SIDE_R) + RUN2 + hexHalfWidth(APP_R);
const GROUP_L = Math.max(SRC_NAME_W / 2, MARK / 2);
const GROUP_R = SRC_TO_SIDE + SIDE_TO_APP + hexHalfWidth(APP_R);
const SRC_X = W / 2 - (GROUP_L + GROUP_R) / 2 + GROUP_L;
const SIDE_X = SRC_X + SRC_TO_SIDE;
const APP_X = SIDE_X + SIDE_TO_APP;

const GROUP_T = APP_R;
const GROUP_B = NAME_DY + LINE + GLYPH;
const Y = M + GROUP_T;
const H = Y + GROUP_B + M;

const ROUTE_X = (SIDE_X + hexHalfWidth(SIDE_R) + APP_X - hexHalfWidth(APP_R)) / 2;

export default {
  width: W,
  height: H,
  title: 'The cron binding calls the engineering app',
  desc:
    'From left to right: a clock mark named warp-core-scan with the schedule @every 10s, '
    + 'an arrow to a Dapr sidecar, and an arrow labelled POST /warp-core-scan from the sidecar '
    + 'to a green hexagon labelled engineering.',

  build() {
    const src = { x: SRC_X, y: Y, w: MARK, h: MARK };
    const side = { x: SIDE_X, y: Y, r: SIDE_R, hex: true };
    const app = { x: APP_X, y: Y, r: APP_R, hex: true };
    return [group([
      arrow({ from: src, to: side }),
      arrow({ from: side, to: app }),
      icon({ name: 'fluent-clock', x: SRC_X, y: Y, size: MARK, color: C.blue, fit: 'ink' }),
      label({ x: SRC_X, y: Y + NAME_DY, text: 'warp-core-scan', size: TEXT }),
      label({ x: SRC_X, y: Y + NAME_DY + LINE, text: '@every 10s', size: TEXT }),
      markHex({ x: SIDE_X, y: Y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      label({ x: SIDE_X, y: Y + NAME_DY, text: 'Dapr sidecar', size: TEXT }),
      label({ x: ROUTE_X, y: Y - 15 - LINE, text: 'POST', size: TEXT }),
      label({ x: ROUTE_X, y: Y - 15, text: '/warp-core-scan', size: TEXT }),
      hex({ x: APP_X, y: Y, r: APP_R, label: 'engineering', size: TEXT, ...APP[0] }),
    ])];
  },
};
