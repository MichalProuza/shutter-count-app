# ShutterCount

ShutterCount is a static browser app for reading shutter count and basic EXIF metadata from local RAW files. Live at **[shuttercount.app](https://shuttercount.app)**.

Everything runs client-side in `index.html`. Files are opened with `FileReader` and are not uploaded anywhere.

## Supported formats

- `CR3` — Canon mirrorless (EOS R-series, M-series)
- `CR2` — Canon DSLR
- `NEF` — Nikon
- `ARW` — Sony Alpha
- `RAF` — Fujifilm
- `ORF` — Olympus / OM System
- `RW2` — Panasonic
- `DNG` — Adobe DNG (Sigma, smartphones: iPhone, Pixel, Samsung, Xiaomi, Honor)
- `JPG` / `JPEG`

## Current support summary

| Brand | Format | Shutter count | Notes |
|---|---|---|---|
| **Nikon** | NEF | Broad | MakerNote tag `0x00A7`; confirmed across Z-series mirrorless and a wide DSLR range |
| **Canon** | CR3 | Partial | CTMD tag `0x000D`; confirmed offsets for R, R3, R5, R5 Mark II, R5 C, R6, R6 Mark II, R6 Mark III, R7, R8, R10, R50, R50 V, R100, RP, M50, M50 Mark II, M6 Mark II, 1D X Mark III, 90D, 850D, 250D |
| **Canon** | CR2 | Limited | In-file shutter count available only for pro `1D / 1Ds` families; consumer bodies expose file number only |
| **Sony** | ARW | Broad | Encrypted MakerNote tag `0x9050`; confirmed for A1, A1 II, A5000, A5100, A6000, A6100, A6300, A6400, A6500, A6600, A6700, A7, A7 II, A7 III, A7 IV, A7C, A7C II, A7CR, A7R, A7R II, A7R III, A7R IV, A7R V, A7S, A7S II, A7S III, A7V, A9, A9 II, A9 III, A77 II, FX3, FX30, ZV-E1, ZV-E10, ZV-E10 II, RX100 VII |
| **Fujifilm** | RAF | Broad | MakerNote tag `0x1438` (`ImageCount`); confirmed for X-T1–X-T5, X-T10, X-T20, X-T30, X-T30 II, X-T50, X-T200, X-E2–X-E4, X-H1, X-H2, X-H2S, X-S10, X-S20, X-A7, X-M5, X-Pro1–X-Pro3, X100F, X100V, X100VI, GFX 50S, GFX 50S II, GFX 100, GFX100S, GFX 100S II, GFX100 II |
| **Sigma** | DNG | Partial | EXIF make/model reads correctly; shutter count availability varies by body |
| **Olympus / OM System** | ORF | None | EXIF parsing works; no reliable in-file shutter-count tag confirmed |
| **Panasonic** | RW2 | None | EXIF parsing works; shutter count is not stored in RAW files |
| **Smartphones** | DNG | N/A | EXIF metadata reads correctly; shutter count field not applicable |

## Features

- **100% local** — files never leave the browser
- **Multi-file** — drop or select multiple files at once; results shown as cards
- **CSV export** — export all results to a spreadsheet
- **Life bar** — visual indicator of shutter usage vs. rated lifespan
- **50+ languages** — full UI localisation with a language switcher
- **GDPR cookie banner** — analytics loaded only after consent
- **Camera subpages** — dedicated SEO pages for 210+ camera models

## Repository layout

| Path | Description |
|---|---|
| `index.html` | UI and parser implementation (single-file app) |
| `validate.mjs` | Node.js validator — extracts parser code from `index.html` and runs it against sample files |
| `validate_raws.ps1` | PowerShell validator for bundled and downloaded RAW corpora |
| `Raws_small_truncated/` | Bundled 32 KB sample snippets (~110 files across all supported brands) |
| `vercel.json` | Vercel deployment config |
| `<lang>/` | Localised index pages (e.g. `de/`, `fr/`, `ja/`) |
| `<model>-shutter-count/` | Camera-specific SEO landing pages |

## Validation

Run against bundled samples:

```bash
node validate.mjs
```

Recursive validation over a full corpus:

```powershell
powershell -ExecutionPolicy Bypass -NoProfile -File .\validate_raws.ps1 -Path .\releases_full -Recurse
```

Notes:

- `validate.mjs` prefers `Raws_small_truncated/` and falls back to `Samples/` if present
- `releases_full/` is intentionally ignored by Git because it can contain large downloaded RAW corpora
- `Raws_small_truncated/` contains 32 KB snippets, so some files validate make/model but still miss shutter-count blocks

## Verified release corpus

Support claims were checked against full GitHub release batches `Zoner_D` through `Zoner_D5`.

Highlights:

- Canon EOS R5 Mark II shutter count confirmed at CTMD tag `0x000D` offset `0x069C` (uint32), from Zoner_D5
- Canon R6 Mark III shutter count confirmed via Zoner corpus samples
- Nikon shutter count confirmed across modern Z-series bodies and a wide DSLR range (D3–D850, Z5–Z9)
- Sony shutter count confirmed for A1/A1 II, A5000, A5100, A6000, A6100/A6300/A6400/A6500/A6600, A6700, A7/II/III/IV/V, A7C/A7C II/A7CR, A7R/II/III/IV/V, A7S/II/III, A9/II/III, A77 II, FX3, FX30, ZV-E1, ZV-E10/II, RX100 VII
- Fujifilm shutter count confirmed for X100F/V/VI, X-H1/H2/H2S, X-S10/S20, X-A7, X-M5, X-E2/E3/E4, X-T1–T5, X-T10, X-T20, X-T30/T30 II, X-T50, X-T200, X-Pro1/Pro2/Pro3, GFX 50S/50S II, GFX 100, GFX100S, GFX 100S II, GFX100 II
- Nikon 1 J1/V1: confirmed via Zoner corpus
- Olympus / OM System `ORF` did not yield a confirmed reliable in-file shutter counter in the tested release corpus

## Limitations

- Some formats still depend on model-specific offsets, especially Canon `CR3` and Sony `ARW`
- Unsupported does not always mean impossible; it can also mean no reliable offset has been validated yet
- The app is intentionally a single-file page, so parser logic, tested-camera notes and UI messaging need to stay in sync carefully
- `Raws_small_truncated` samples are truncated to 32 KB — enough to read make/model and most EXIF tags, but some shutter-count blocks appear later in the file
