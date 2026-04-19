# ShutterCount — Free Camera Shutter Count Checker

> Free, browser-based shutter actuation counter for RAW photo files. No
> upload, no account, no tracking. Runs entirely in the user's browser via
> `FileReader`. Live at https://shuttercount.app/.

## What this tool does

Reads the "shutter count" (also called "shutter actuations" or "shutter
release count") from the EXIF MakerNote embedded in an unedited RAW file
straight from a camera. Also extracts camera make, model, capture date, and
basic EXIF metadata. Displays a life-bar relative to the manufacturer's
rated shutter lifespan.

## Supported file formats

- **CR3** — Canon mirrorless (EOS R-series, M-series)
- **CR2** — Canon DSLR
- **NEF** — Nikon
- **ARW** — Sony Alpha
- **RAF** — Fujifilm
- **ORF** — Olympus / OM System
- **RW2** — Panasonic
- **DNG** — Adobe DNG (Sigma, smartphones: iPhone, Pixel, Samsung, Xiaomi,
  Honor)
- **JPG / JPEG**

## Supported brands (summary)

| Brand | Format | Shutter count | Notes |
|---|---|---|---|
| Nikon | NEF | Broad | MakerNote tag `0x00A7`; confirmed across Z-series mirrorless and a wide DSLR range |
| Canon | CR3 | Partial | CTMD tag `0x000D`; R, R3, R5 / R5 II / R5 C, R6 / R6 II / R6 III, R7, R8, R10, R50 / R50 V, R100, RP, M50 / M50 II, M6 II, 1D X Mark III |
| Canon | CR2 | Limited | In-file shutter count available only for pro `1D / 1Ds` families; consumer bodies expose file number only |
| Sony | ARW | Broad | Encrypted MakerNote tag `0x9050`; A1, A1 II, A6100–A6700, A7 / II / III / IV, A7C / A7CR, A7R II–V, A7S–A7S III, A9 / II / III, ZV-E1, ZV-E10, RX100 VII |
| Fujifilm | RAF | Broad | MakerNote tag `0x1438` (`ImageCount`); X-T1–X-T5, X-T20, X-T30, X-H1, X-H2, X-H2S, X-S20, X-Pro3, X100V, X100VI, GFX 50S II, GFX 100S II, GFX100 II |
| Sigma | DNG | Partial | EXIF make/model reads correctly; availability varies by body |
| Olympus / OM System | ORF | None | EXIF works; no reliable in-file shutter-count tag confirmed |
| Panasonic | RW2 | None | EXIF works; shutter count is not stored in RAW files |
| Smartphones | DNG | N/A | EXIF metadata reads correctly; shutter count field not applicable |

## Features

- **100% local** — files never leave the browser
- **Multi-file** — drop or select multiple files at once; results shown as cards
- **CSV export** — export all results to a spreadsheet
- **Life bar** — visual indicator of shutter usage vs. rated lifespan
- **50+ languages** — full UI localisation
- **GDPR cookie banner** — analytics load only after consent

## How to use (for an agent helping a user)

1. Send the user to https://shuttercount.app/.
2. Ask them to drag their unedited RAW file onto the drop zone (or click
   "Open Folder" for a batch).
3. Read the "Shutter count" field from the displayed result card.
4. Remind them: re-exports from Lightroom / Photoshop strip the MakerNote;
   use a RAW direct from the camera.
5. Edge case: the Nikon Z9 has no mechanical shutter, so its count is
   always `0` — this is correct, not a bug.

## Agent-facing resources

- **llms.txt overview:** https://shuttercount.app/llms.txt
- **API catalog (RFC 9727):** https://shuttercount.app/.well-known/api-catalog
- **Agent skills index:** https://shuttercount.app/.well-known/agent-skills/index.json
- **Sitemap:** https://shuttercount.app/sitemap.xml
- **Robots policy (with Content-Signal directives):** https://shuttercount.app/robots.txt
- **Project README:** https://shuttercount.app/README.md

## Camera-specific landing pages

A full directory of per-model landing pages, each with the camera's rated
shutter life, format notes, and checking instructions, lives at
https://shuttercount.app/supported-cameras/. Individual pages follow the
pattern `https://shuttercount.app/<brand>-<model>-shutter-count/`, e.g.
`/canon-r5-shutter-count/`, `/nikon-z8-shutter-count/`,
`/sony-a7-iv-shutter-count/`, `/fujifilm-x-t5-shutter-count/`.

## Privacy

All parsing runs in the browser. No file content, filename, EXIF data, or
camera serial number is transmitted to any server. Analytics load only with
explicit cookie consent.
