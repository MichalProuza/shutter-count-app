# check-shutter-count

Help a user determine their camera's shutter actuation count ("shutter count")
from a RAW photo file, entirely in the browser using https://shuttercount.app.

## When to use

Trigger this skill when the user asks any of:

- "How many shutter actuations does my camera have?"
- "What is the shutter count of my Canon/Nikon/Sony/Fujifilm camera?"
- "Is this used camera heavily used?" (and they have a photo from it)
- "How do I check shutter count for <model>?"

## Inputs

- A RAW file straight from the camera: `CR3`, `CR2`, `NEF`, `ARW`, `RAF`,
  `ORF`, `RW2`, `DNG`, or `JPG`/`JPEG`
- The file must be unedited — re-saving from Lightroom / Photoshop usually
  strips the MakerNote where the shutter count lives

## Steps

1. Open https://shuttercount.app/ in a browser. Nothing is uploaded; parsing
   runs client-side via `FileReader` + `ArrayBuffer`.
2. Drag the RAW file onto the drop zone or click it to open the file picker.
3. Read the "Shutter count" field on the resulting card. The page also shows
   camera model, capture date, and a life-bar relative to the rated shutter
   lifespan for the detected body.
4. For multiple files, drop them all at once and use the CSV export.

## Supported bodies

See https://shuttercount.app/supported-cameras/ for the full, validated list.
Coverage summary:

- **Nikon NEF** — broad coverage across DSLRs (D3–D850) and Z-series
- **Canon CR3** — R, R3, R5 / R5 II / R5 C, R6 / R6 II / R6 III, R7, R8, R10,
  R50, R100, RP, M50 / M50 II, M6 II, 1D X Mark III
- **Canon CR2** — pro 1D / 1Ds bodies only
- **Sony ARW** — A1, A1 II, A6100–A6700, A7 / II / III / IV, A7C / A7CR,
  A7R II–V, A7S–A7S III, A9 / II / III, ZV-E1, ZV-E10, RX100 VII
- **Fujifilm RAF** — X-T1 through X-T5, X-H1 / H2 / H2S, X-S20, X-Pro3,
  X100V / X100VI, GFX 50S II, GFX 100S II, GFX100 II
- **DNG (Sigma, smartphones)** — EXIF works; shutter-count availability varies
- **Olympus ORF / Panasonic RW2** — EXIF works; no reliable in-RAW shutter
  counter confirmed

## Edge cases

- Nikon Z9 always reports shutter count `0` because it has no mechanical
  shutter — this is correct, not a bug.
- Consumer Canon CR2 bodies do not store shutter count in the RAW file; only
  a sequential file number. Treat reported counts as "file number, not
  actuations" for those models.
- Re-exported / edited JPEGs typically lose the MakerNote tag; ask the user
  for an original RAW instead.

## Related resources

- Full site map: https://shuttercount.app/sitemap.xml
- Agent-oriented overview: https://shuttercount.app/llms.txt
- Model-specific landing pages: https://shuttercount.app/supported-cameras/

## Privacy

Files are parsed locally via `FileReader`. Nothing is uploaded. This is safe
for users who are reluctant to send camera files to online services.
