# Routine: Add Zoner Comparison Page in New Language

Creates a translated version of the Zoner Photo Studio vs Lightroom comparison page for a new language.

## How to invoke

```
/routine add-comparison-page LANG_CODE="de" LANG_NAME="German" SLUG="zoner-photo-studio-vs-lightroom-vergleich"
```

## Parameters

| Parameter   | Description                                      | Example                                    |
|-------------|--------------------------------------------------|--------------------------------------------|
| `LANG_CODE` | ISO 639-1 language code                          | `de`, `fr`, `cs`, `pl`, `es`               |
| `LANG_NAME` | Full language name in English                    | `German`, `French`, `Czech`, `Polish`      |
| `SLUG`      | Localized URL slug (no slashes, lowercase, hyphens) | `zoner-photo-studio-vs-lightroom-vergleich` |

## Steps

1. **Read the English source file** at `/zoner-photo-studio-vs-lightroom/index.html` — this is the authoritative template.

2. **Translate all user-facing text** into `LANG_NAME`. Translate:
   - `<title>` and all `<meta>` content (description, keywords, og:*, twitter:*)
   - All visible HTML text: headings, paragraphs, table cells, list items, button labels, badge text, breadcrumb text, footer text
   - JSON-LD schema values: `name`, `description`, FAQ questions and answers
   - Keep all HTML structure, CSS classes, inline styles, and SVG logo code exactly as-is
   - Keep all URLs unchanged (href attributes, canonical, og:url, JSON-LD urls)
   - Keep the Zoner promo link href exactly as-is (same UTM parameters)
   - Keep `<html lang="en">` but change to `<html lang="LANG_CODE">`

3. **Update metadata** in the translated file:
   - `<html lang="LANG_CODE">`
   - `<link rel="canonical" href="https://shuttercount.app/LANG_CODE/SLUG/">`
   - `og:url` → `https://shuttercount.app/LANG_CODE/SLUG/`
   - JSON-LD `"url"` fields for the page → `https://shuttercount.app/LANG_CODE/SLUG/`
   - JSON-LD breadcrumb item 2: update `"name"` to translated page title, `"item"` to `https://shuttercount.app/LANG_CODE/SLUG/`
   - JSON-LD `"inLanguage"` → `LANG_CODE`

4. **Update the breadcrumb HTML** (visible on page):
   - Item 1: `<a href="/">ShutterCount</a>` — keep as-is
   - Item 2: translated page title text (no link needed)

5. **Update internal `<a href="/">` links** that say "Check Your Shutter Count →" — keep href as `/`, just translate the label text.

6. **Create the output file** at:
   ```
   /home/user/shutter-count-app/LANG_CODE/SLUG/index.html
   ```
   Create the directory if it does not exist.

7. **Add an entry to `sitemap.xml`** immediately after the existing English entry:
   ```xml
   <url>
     <loc>https://shuttercount.app/LANG_CODE/SLUG/</loc>
     <changefreq>monthly</changefreq>
     <priority>0.8</priority>
     <lastmod>TODAY_DATE</lastmod>
   </url>
   ```
   Insert it after the block for `/zoner-photo-studio-vs-lightroom/`.

8. **Commit and push** to branch `claude/add-comparison-pages-ZA2eJ`:
   ```
   git add LANG_CODE/SLUG/index.html sitemap.xml
   git commit -m "Add Zoner vs Lightroom comparison page (LANG_NAME)"
   git push -u origin claude/add-comparison-pages-ZA2eJ
   ```

## Quality checklist before committing

- [ ] `<html lang="LANG_CODE">` is set correctly
- [ ] Canonical URL points to the new page path
- [ ] All user-visible text is translated (no English left except brand names: Zoner, Adobe, Lightroom, Canon, Nikon, Sony, Fujifilm)
- [ ] Zoner promo link href is identical to the English version
- [ ] JSON-LD FAQ contains translated Q&A pairs
- [ ] Sitemap entry added

## Notes

- Brand names (Zoner Photo Studio X, Adobe Lightroom Classic, Photoshop, Canon, Nikon, Sony, Fujifilm) are **not translated** — keep them in English.
- Price figures ($9.99, $19.99) are kept as-is.
- The "sponsored" tag on the promo block should be translated (e.g., German: "gesponsert", French: "sponsorisé").
- The site uses the Czech directory as `/cz/` (not `/cs/`). If generating Czech, use `LANG_CODE=cz` for the path but `lang="cs"` in the HTML attribute.
- Related links at the bottom should remain pointing to the English content pages (they don't have translated counterparts yet).
