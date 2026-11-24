// dapr-101 page 2 (the Dapr CLI), section 2 "What `dapr init` did", after the
// list of what Dapr initialization included: the one CLI command installs the
// sidecar binaries, creates the default components folder and starts four
// containers.
//
// There is no demo code for this page (university-labs dapr-101/ at 18d67c0
// holds the state, service invocation and pub/sub apps only), so every name
// comes from the assignment: section 2 for what `dapr init` does, section 4
// for the container names (`docker ps` lists them).
//
// Elements, with each name as the page gives it:
// - dapr init: the CLI command, in mono in a code card, as the route card in
//   secrets-1-cloud-stores. It is a command, not an app, so no hexagon
//   (the PR 4 rule: a caller that is not an app is a label or terminal mark).
// - sidecar binaries: "Fetched and installed the Dapr sidecar binaries
//   locally". A Dapr hexagon (markHex with the logo), smaller than the house
//   sidecar (0.75 x 56 = 42) because nothing on this page runs a sidecar: the
//   name says these are the binaries. The bare logo was tried first and is
//   navy on the dark ground, too faint to read.
// - components folder: "Creating a default components folder". The
//   `fluent-document-multiple` mark (several component files), the document
//   vocabulary of the PR 3 scenes. The page names no path, so none is drawn.
// - Containers: a captioned region with the four containers as a list (mark
//   left, mono name right, as the brokers in pubsub-1-components), in the
//   page's section 4 order:
//   - dapr_placement and dapr_scheduler: Dapr services, so a small markHex
//     with the Dapr logo (the control plane look of services.mjs, sized down
//     to sit in a list; serviceHex() would set its own name under it).
//   - dapr_redis: the Redis mark, tinted C.redisBrand as in the other scenes.
//   - dapr_zipkin: the Zipkin mark (full colour).
//
// Connections: dapr init -> sidecar binaries, -> components folder, ->
// Containers. Nothing else: the page does not say which component file points
// at which container, so no line joins the folder to Redis or Zipkin.
//
// Layout: canvas 480 wide for the 424 px lab column. Three columns: the card,
// the binaries above the components folder, the containers region. At most
// three shapes in any row. The straight arrow to the region runs between the
// two middle items; the other two leave the card's top and bottom and turn
// into the items from the left (diagonals ran into the items' names).
import { C } from '../_engine/engine.mjs';
import { arrow, captionPad, captionReach, codeCard, elbowArrow, group, hexHalfWidth, label, region } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13; // every label, as in the secrets, pubsub and bindings scenes

const W = 480;
const M = 12; // canvas margin, as in the secrets scenes
const EDGE = 2; // the card's left edge stays this far inside the margin
const CLEAR = 2; // an arrow's end this far off the shape it meets (the engine's own gap)

// The containers region, against the right margin. Each entry is a mark with
// its mono name to its right. NAME_W is the widest name, "dapr_placement"
// (14 characters at 7.8 units each in mono at 13), rounded up.
const MARK = 26; // every mark in the list
const HEX_R = 15; // the Dapr service hexagons, about as tall as the other marks
const MARK_GAP = 10;
const PAD = 14;
const NAME_W = 110;
const REG_W = PAD + MARK + MARK_GAP + NAME_W + PAD;
const REG_R = W - M;
const REG_L = REG_R - REG_W;
const REG_X = (REG_L + REG_R) / 2;
const MARK_X = REG_L + PAD + MARK / 2;
const NAME_X = REG_L + PAD + MARK + MARK_GAP;
const CAPTION_W = Math.ceil(72 + 2 * captionPad(TEXT)); // "Containers" measured at 13 (weight 600): 71, rounded up

const REACH = captionReach();
const PITCH = 42; // entry pitch: a 30-unit hexagon and 12 clear
const CONTAINERS = [
  { name: 'dapr_placement', hex: true },
  { name: 'dapr_scheduler', hex: true },
  { name: 'dapr_redis', mark: 'redis', color: C.redisBrand },
  { name: 'dapr_zipkin', mark: 'zipkin' },
];
const REG_T = M + REACH; // the caption pill keeps the margin
const LIST_TOP = REG_T + REACH + 10 + MARK / 2; // first entry's centre: its top 10 under the pill
const REG_B = LIST_TOP + (CONTAINERS.length - 1) * PITCH + MARK / 2 + 14;
const ROW_Y = (REG_T + REACH + REG_B) / 2; // the region's middle, below the pill

// The command card, against the left margin, on the region's middle line.
// "dapr init" is 9 characters in mono at 13 (about 70), plus 15 each side.
const CARD_W = 100;
const CARD_H = 36;
const CARD_X = M + EDGE + CARD_W / 2;

// The middle column: centred between the card and the region, the binaries
// above the arrow to the region and the components folder below it.
const MID_X = (CARD_X + CARD_W / 2 + REG_L) / 2;
const BIN_R = 22; // the binaries hexagon: between the list hexagons (15) and the house sidecar (42)
const DOCS = 26; // the document mark, as tall as the list marks
const DOCS_HW = 0.3 * DOCS; // the document's ink is 12 wide by 18 tall (ink.json), fitted to 26 tall
const NAME_GAP = 14; // a name's centre this far below its mark (about one line)
const BIN_Y = ROW_Y - 58; // the binaries' name clears the straight arrow by about one line
const COMP_Y = ROW_Y + 44; // far enough below the card for the elbow to turn

const H = Math.ceil(REG_B + M);

export default {
  width: W,
  height: H,
  title: 'What dapr init sets up',
  desc:
    'On the left a card with the command dapr init. Three arrows leave it: one to a Dapr hexagon labelled '
    + 'sidecar binaries, one to a stack of documents labelled components folder, and one to a region '
    + 'labelled Containers that lists dapr_placement and dapr_scheduler, each with a Dapr hexagon, '
    + 'dapr_redis with the Redis logo and dapr_zipkin with the Zipkin logo.',

  build() {
    const card = { x: CARD_X, y: ROW_Y, w: CARD_W, h: CARD_H };
    const entries = CONTAINERS.map((c, i) => {
      const cy = LIST_TOP + i * PITCH;
      return group([
        c.hex
          ? markHex({ x: MARK_X, y: cy, r: HEX_R, mark: 'logo-blue', stroke: C.blue })
          : icon({ name: c.mark, x: MARK_X, y: cy, size: MARK, fit: 'ink', ...(c.color ? { color: c.color } : {}) }),
        label({ x: NAME_X, y: cy, text: c.name, size: TEXT, anchor: 'start', mono: true }),
      ]);
    });

    return [group([
      region({ x: REG_L, y: REG_T, w: REG_W, h: REG_B - REG_T, caption: 'Containers', captionSize: TEXT, captionW: CAPTION_W, captionX: REG_X }),
      ...entries,

      elbowArrow({ points: [[CARD_X, ROW_Y - CARD_H / 2 - CLEAR], [CARD_X, BIN_Y], [MID_X - hexHalfWidth(BIN_R) - CLEAR, BIN_Y]] }),
      elbowArrow({ points: [[CARD_X, ROW_Y + CARD_H / 2 + CLEAR], [CARD_X, COMP_Y], [MID_X - DOCS_HW - CLEAR - 2, COMP_Y]] }),
      arrow({ from: [CARD_X + CARD_W / 2 + CLEAR, ROW_Y], to: [REG_L - CLEAR, ROW_Y] }),

      codeCard({ x: CARD_X, y: ROW_Y, w: CARD_W, h: CARD_H }),
      label({ x: CARD_X, y: ROW_Y, text: 'dapr init', size: TEXT, mono: true }),

      markHex({ x: MID_X, y: BIN_Y, r: BIN_R, mark: 'logo-blue', stroke: C.blue }),
      label({ x: MID_X, y: BIN_Y + BIN_R + NAME_GAP, text: 'sidecar binaries', size: TEXT }),
      icon({ name: 'fluent-document-multiple', x: MID_X, y: COMP_Y, size: DOCS, color: C.navy, fit: 'ink' }),
      label({ x: MID_X, y: COMP_Y + DOCS / 2 + NAME_GAP, text: 'components folder', size: TEXT }),
    ])];
  },
};
