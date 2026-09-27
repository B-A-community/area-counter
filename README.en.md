# area counter — floor areas for SketchUp 2024 / 2025 / 2026

[Русский](README.md) · **English**

A SketchUp extension that automates area calculations right in the model — the
first tool in automating the architectural workflow. Tested in SketchUp 2024,
2025 and 2026.

Version 1.0 · [Apache 2.0](LICENSE) license · © 2026 B&A community

Creators: [maksarsanjeev](https://github.com/maksarsanjeev),
[Royalb21](https://github.com/Royalb21) — see [AUTHORS](AUTHORS).

## Download and install

Release **1.0**: [release page](https://github.com/B-A-community/area-counter/releases/tag/v1.0).

| Русский интерфейс | English UI |
|---|---|
| [area-counter-1.0-rus.zip](https://github.com/B-A-community/area-counter/releases/download/v1.0/area-counter-1.0-rus.zip) | [area-counter-1.0-eng.zip](https://github.com/B-A-community/area-counter/releases/download/v1.0/area-counter-1.0-eng.zip) |

Each archive contains the `.rbz` extension and a one-page PDF guide.

Install: SketchUp → `Window → Extension Manager → Install Extension` → pick the
`.rbz` → restart SketchUp. Remove any earlier test build first.

Both builds come from the same source and differ only in UI language: all
strings live in `src/area_counter/lang.rb` (Ruby — menus, messages, tables,
names in the model) and `src/area_counter/html/i18n.js` (windows); the build
script swaps the `LANG = 'ru'|'en'` line in a copy. The English build uses a
decimal point and puts sections on the `AC_Sections` tag; both builds recognise
sections output by either one and never count them as floors.

## Guide in five lines

1. Select a building (or a complex, or the floors themselves), tell the window
   what is selected, click **Calculate**.
2. The **Section** method cuts each floor at a height above its bottom
   (**1000 mm** by default) and measures the area **by the outer contour** —
   with all facade relief and windows. Gaps in the facade **up to 20 mm** are closed.
3. If the cut lands on a slab or a sill, it moves 2 mm up. If an open doorway
   breaks the facade ring, the plugin picks another height and says which.
4. A **red** floor status means the area cannot be trusted. **Highlight** shows
   the contour in green and the breaks in orange.
5. **Output sections** puts a flat section face of each floor into the model,
   its area shows in Entity Info. **Copy** puts the table on the clipboard for
   Google Sheets and Excel.

A single floor without the window: select it and choose **Extensions → area
counter → Floor section…** — the plugin asks for the parameters, builds the
face and shows the result in its window.

## What it does

**Hierarchy: Floor → Building → Complex.** The anchor is the selection; floors
lie at the chosen depth under it and are counted as a whole, with everything
nested inside. In the window this is “What is selected”: Floors, Building,
Complex — depth 0, 1 and 2.

**Two methods:**

- **Top face** — fast. Takes all horizontal faces at the top elevation, in world
  coordinates, so rotated group axes do not matter.
- **Section** — exact, a clean horizontal floor section computed in memory; the
  source geometry is not changed. Faces are sliced by the plane, points welded
  (1 mm), segments split at crossings and joints, gaps closed (20 mm), the outer
  boundary found in a half-edge planar graph, and the contour simplified only
  where points lie on straight lines. The result is checked (closed, no
  self-intersection, sane size); if the facade ring is broken, other heights are
  tried and the one used is written in the status. Courtyards are not subtracted
  by default (“subtract courtyards” box); separate pieces over 0.1 m² are not
  included in the floor area and are mentioned in the status.

**The window** follows the [B&A design code](https://github.com/B-A-community/ralncs/tree/main/design):
buttons → status line → complex → building → floor tree → footer, settings
pinned on the right, “Guide” with the full description, “About…” in the menu.

**Output sections** — a root group “area counter: sections” on the
**AC_Sections** tag with the same hierarchy; one flat face per floor at the cut
height, `area_counter` attributes (`floor_pid`, `cut_mm`, `area_m2`, `date`).
Running again replaces the floor’s previous section. One operation — Ctrl+Z
removes it all.

**Copy** — the table of the chosen level (Floors, Buildings, Complexes) as text
and HTML at once; long format, upper-level areas repeated in the same rows.

## Build

```bash
powershell -ExecutionPolicy Bypass -File "tools\build_rbz.ps1"
```

Produces `dist\area-counter-<version>-rus.rbz` and `-eng.rbz` (`-Lang en` for
English only). Release archives: print the guides, then add `-Release`.

```bash
powershell -ExecutionPolicy Bypass -File "tools\build_guides.ps1"
```

```bash
powershell -ExecutionPolicy Bypass -File "tools\build_rbz.ps1" -Release
```

## Self-test

`tools/selftest.rb` — 49 checks (section modules, the 10 spec test cases, faces
in the model, top face, hierarchy and tables). In the SketchUp Ruby Console with
the extension loaded:

```ruby
load 'C:/path/to/repo/tools/selftest.rb'
BACommunity::AreaCounter::SelfTest.run
```

As of 27.09.2026: 49 of 49 in SketchUp 2024, 2025 and 2026, Russian and English builds.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
