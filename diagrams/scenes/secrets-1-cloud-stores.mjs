// dapr-secrets page 1 (what is the Secrets API), section 1 "Why a secret
// store?": the application asks its Dapr sidecar for a secret by name, and
// the sidecar reads it from whichever secret store the component points at.
// A redraw of the opaque white secrets-cloud-stores.png that was on the page,
// for the narrow dark column.
//
// Elements, with each name as it appears in the demo (university-labs
// secrets/ at 37fccac) or, for the stores, in the original image and the
// page's alt text:
// - order-api: the app, the green hexagon (APP[0]). The original said "App";
//   the page names the app order-api and the demo's dapr.yaml files use
//   `appID: order-api`, so the hexagon carries the app ID.
// - Dapr sidecar: markHex with the Dapr logo, drawn apart from the app with an
//   arrow between them, because "the application only asks the Dapr sidecar
//   for a secret" is the point of the section (bindings-1-directions).
// - Secret stores: a captioned region holding a list of the four stores the
//   original shows and the alt text names, each with its shipped mark:
//   AWS Secrets Manager (`aws-secrets-manager`), Azure Key Vault
//   (`azure-key-vault`), Google Key Management (`google-key-management`),
//   HashiCorp Vault (`vault`, single-colour, tinted with the body ink).
// - The Secrets API call: a code card under the app and the sidecar with
//   `GET /v1.0/secrets/secretstore/orderdb-password`, the sidecar's HTTP API
//   as the page calls it with curl in section 4 (component `secretstore`,
//   secret `orderdb-password`, from secretstore-local.yaml and
//   secrets.example.json). `secrets` is picked out in orange, as in the
//   original.
//
// Connections: order-api -> Dapr sidecar (asks for the secret); Dapr sidecar
// -> Secret stores (reads it).
//
// Departures from the original and the skill, on purpose:
// - The original drew the stores as a 2 x 2 grid. With the app and the sidecar
//   in the same row that is four shapes side by side; the column allows three,
//   so the stores are a one-column list (mark left, name right) in the region,
//   as the brokers are in pubsub-1-components. Every name is on two lines to
//   keep the region narrow.
// - The original's arrows had a head at both ends. The house arrow points the
//   way the call goes (the app asks, the sidecar reads), as in
//   bindings-1-directions; the answer travels back along the same line.
// - The caption is "Secret stores", not "Cloud secret stores": HashiCorp Vault
//   is not only a cloud service (the lab runs it locally on page 5), and the
//   alt text says "a secret store such as".
// - The route is the demo's (secretstore / orderdb-password) instead of the
//   original's generic /v1.0/secrets/vault/mysecret, and it sits on one line
//   in a card under the whole row, because at 13 units in mono it is wider
//   than the room left of the region.
// - The marks are not plated, as in pubsub-1-components: a plate per mark
//   would put four light blocks in a narrow dark column.
// - Canvas 490 wide for the 424 px lab column (not 16:9 at 1100+ units).
import { APP, C } from '../_engine/engine.mjs';
import { arrow, captionPad, captionReach, codeCard, group, hex, hexHalfWidth, label, region, richLabel } from '../_engine/shapes.mjs';
import { icon, markHex } from '../_engine/icons.mjs';

const TEXT = 13; // every label in the scene, as in the PR 1 to 3 scenes

const W = 490;
const M = 12; // canvas margin
const EDGE = 2; // the app hexagon's outer point stays this far inside the margin

const APP_R = 56; // the house app radius
const SIDE_R = 0.75 * APP_R; // the house sidecar size
const APP_HW = hexHalfWidth(APP_R);
const SIDE_HW = hexHalfWidth(SIDE_R);
const NAME_DY = SIDE_R + 16; // "Dapr sidecar" under its hexagon, as in bindings-1-directions

// The stores region, against the right margin. Each entry is a mark with its
// two-line name to its right. NAME_W is the widest line ("Google Key",
// measured at 13, weight 600: 82.6), rounded up.
const MARK = 24;
const MARK_GAP = 8;
const PAD = 14;
const NAME_W = 84;
const REG_W = PAD + MARK + MARK_GAP + NAME_W + PAD;
const REG_R = W - M;
const REG_L = REG_R - REG_W;
const REG_X = (REG_L + REG_R) / 2;
const MARK_X = REG_L + PAD + MARK / 2;
const NAME_X = REG_L + PAD + MARK + MARK_GAP;
const CAPTION_W = Math.ceil(85 + 2 * captionPad(TEXT)); // "Secret stores" measured at 13 (weight 600): 83.3, rounded up

const REACH = captionReach();
const LINE = TEXT * 1.2;
const PITCH = 50; // entry pitch: a two-line name (31) and 19 clear
const STORES = [
  { name: 'aws-secrets-manager', text: 'AWS Secrets\nManager' },
  { name: 'azure-key-vault', text: 'Azure\nKey Vault' },
  { name: 'google-key-management', text: 'Google Key\nManagement' },
  { name: 'vault', text: 'HashiCorp\nVault', color: C.body },
];
const REG_T = M + REACH; // the caption pill keeps the margin
const LIST_TOP = REG_T + REACH + 8 + LINE; // first entry's centre: its top line 8 under the pill
const REG_B = LIST_TOP + (STORES.length - 1) * PITCH + LINE + 14;

// The row: app and sidecar on the region's middle line, the sidecar centred in
// the space between the app and the region so both arrows are the same length.
const ROW_Y = (REG_T + REACH + REG_B) / 2;
const APP_X = M + EDGE + APP_HW;
const SIDE_X = (APP_X + APP_HW + REG_L) / 2;
const RUN = SIDE_X - SIDE_HW - (APP_X + APP_HW); // arrow length between the shapes
if (RUN < 30 || RUN > 110) throw new Error(`secrets-1-cloud-stores: arrow run ${RUN} outside 30 to 110`);

// The route card: one mono line (46 characters at 7.8 units each, about 359),
// under the whole row, from the left margin.
const CARD_W = 390;
const CARD_H = 40;
const CARD_PAD = 14;
const CARD_L = M + EDGE;
const CARD_T = REG_B + 16;
const CARD_Y = CARD_T + CARD_H / 2;
if (ROW_Y + NAME_DY + 0.37 * TEXT + 12 > CARD_T) throw new Error('secrets-1-cloud-stores: the sidecar name runs into the route card');

const H = Math.ceil(CARD_T + CARD_H + M);

export default {
  width: W,
  height: H,
  title: 'An app reads a secret through its Dapr sidecar',
  desc:
    'On the left a green hexagon labelled order-api. An arrow runs from it to a Dapr sidecar, and '
    + 'another from the sidecar to a region labelled Secret stores that lists AWS Secrets Manager, '
    + 'Azure Key Vault, Google Key Management and HashiCorp Vault, each with its logo. Under them a '
    + 'card shows the call GET /v1.0/secrets/secretstore/orderdb-password.',

  build() {
    const entries = STORES.map((s, i) => {
      const cy = LIST_TOP + i * PITCH;
      return group([
        icon({ name: s.name, x: MARK_X, y: cy, size: MARK, fit: 'ink', ...(s.color ? { color: s.color } : {}) }),
        label({ x: NAME_X, y: cy, text: s.text, size: TEXT, anchor: 'start' }),
      ]);
    });

    const app = { x: APP_X, y: ROW_Y, r: APP_R, hex: true };
    const side = { x: SIDE_X, y: ROW_Y, r: SIDE_R, hex: true };

    return [group([
      region({ x: REG_L, y: REG_T, w: REG_W, h: REG_B - REG_T, caption: 'Secret stores', captionSize: TEXT, captionW: CAPTION_W, captionX: REG_X }),
      ...entries,

      arrow({ from: app, to: side }),
      arrow({ from: side, to: [REG_L - 2, ROW_Y] }),

      hex({ x: APP_X, y: ROW_Y, r: APP_R, label: 'order-api', size: TEXT, ...APP[0] }),
      markHex({ x: SIDE_X, y: ROW_Y, r: SIDE_R, mark: 'logo-blue', stroke: C.blue }),
      label({ x: SIDE_X, y: ROW_Y + NAME_DY, text: 'Dapr sidecar', size: TEXT }),

      codeCard({ x: CARD_L + CARD_W / 2, y: CARD_Y, w: CARD_W, h: CARD_H }),
      richLabel({
        x: CARD_L + CARD_PAD,
        y: CARD_Y,
        size: TEXT,
        mono: true,
        parts: [
          { text: 'GET ', color: C.blue, weight: 700 },
          { text: '/v1.0/' },
          { text: 'secrets', color: C.orange, weight: 700 },
          { text: '/secretstore/orderdb-password' },
        ],
      }),
    ])];
  },
};
