# ShutterCount

ShutterCount is a static browser app for reading shutter count and basic EXIF metadata from local RAW files.

Everything runs client-side in `index.html`. Files are opened with `FileReader` and are not uploaded anywhere.

## Supported formats

- `CR3`
- `CR2`
- `NEF`
- `ARW`
- `RAF`
- `ORF`
- `RW2`
- `DNG`
- `JPG` / `JPEG`

## Current support summary

- Nikon `NEF`: broad support via MakerNote tag `0x00A7`
- Canon `CR3`: confirmed support for known model-specific offsets on `R5`, `R5 Mark II`, `R6`, `R6 Mark II`, `R8`, `R50`, `R5 C`, `R6 Mark III`, `R50 V`, `R1`
- Canon `CR2`: in-file shutter count is generally available only for pro `1D / 1Ds` families
- Sony `ARW`: supported for many Alpha bodies via encrypted MakerNote tag `0x9050`
- Fujifilm `RAF`: supported on modern bodies exposing MakerNote tag `0x1438` (`ImageCount`)
- Olympus / OM System `ORF`: EXIF parsing works, but release validation has not confirmed a reliable in-file shutter-count tag
- Panasonic `RW2`: EXIF parsing works, shutter count is not stored in RAW files

## Repository layout

- `index.html`: UI and parser implementation
- `validate.mjs`: Node-based validator that extracts parser code from `index.html`
- `validate_raws.ps1`: PowerShell validator for bundled and downloaded RAW corpora
- `Raws_small_truncated`: bundled tiny sample set

## Validation

Bundled samples:

```powershell
node validate.mjs
```

Recursive validation over a corpus:

```powershell
powershell -ExecutionPolicy Bypass -NoProfile -File .\validate_raws.ps1 -Path .\releases_full -Recurse
```

Notes:

- `validate.mjs` prefers `Raws_small_truncated` and falls back to `Samples` if present
- `releases_full/` is intentionally ignored by Git because it can contain large downloaded RAW corpora
- `Raws_small_truncated` contains 32 KB snippets, so some files validate make/model but still miss shutter-count blocks

## Verified release corpus

Support claims were checked against full GitHub release batches `Zoner_D` through `Zoner_D5`.

Highlights:

- Canon EOS R5 Mark II shutter count confirmed at CTMD tag 0x000D offset 0x069C (uint32), from Zoner_D5
- Nikon shutter count confirmed across modern Z bodies and a wide DSLR range
- Sony shutter count confirmed for multiple Alpha bodies including `A1`, `A1 II`, `A7`, `A7 II`, `A7 III`, `A7 IV`, `A9`, `A9 II`, `A9 III`, `A6700`, `ZV-E10`
- Fujifilm shutter count confirmed for `X100F`, `X-H2`, `X-H2S`, `X-S20`, `X-E4`, `X-T1`, `X-T2`, `X-T3`, `X-T4`, `X-T5`, `X-T30`, `GFX50S II`, `GFX100 II`
- Olympus / OM System `ORF` did not yield a confirmed reliable in-file shutter counter in the tested release corpus

## Limitations

- Some formats still depend on model-specific offsets, especially Canon `CR3` and Sony `ARW`
- Unsupported does not always mean impossible; it can also mean no reliable offset has been validated yet
- The app is intentionally a single-file page, so parser logic, tested-camera notes and UI messaging need to stay in sync carefully
