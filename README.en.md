# area counter — floor areas for SketchUp 2024 / 2025 / 2026

[Русский](README.md) · **English**

A SketchUp extension that automates area calculations right in the model — the
first tool in automating the architectural workflow. Tested in SketchUp 2024,
2025 and 2026.

Version 1.1 · [Apache 2.0](LICENSE) license · © 2026 B&A community

Creators: [maksarsanjeev](https://github.com/maksarsanjeev),
[Royalb21](https://github.com/Royalb21) — see [AUTHORS](AUTHORS).

The extension does one job — **calculate areas**. The window is meant to be
clear without a guide: few settings, hints on hover.

## How to use

1. Select a building (or a complex, or the floors themselves), tell the window
   what is selected, click **Calculate**.
2. The **Section** method cuts each floor at a height above its bottom
   (**1000 mm** by default) and measures the area **by the outer contour** —
   with all facade relief and windows. Gaps in the facade **up to 20 mm** are closed.
3. If the cut lands on a slab or a sill, it moves 2 mm up. If an open doorway
   breaks the facade ring, the plugin picks another height and says which.
4. The table arrives collapsed to the top level; the chevron in the **Object**
   header expands and collapses the whole tree. A **red** floor status means the
   area cannot be trusted. **Highlight** shows the contour in green and the
   breaks in orange.
5. **Copy** puts the table on the clipboard for Google Sheets and Excel.

Outputting sections into the model as faces was removed from area counter in
1.1 — it moves to a separate extension.

## Download and install

Release **1.1**: [release page](https://github.com/B-A-community/area-counter/releases/tag/v1.1).
The previous [1.0](https://github.com/B-A-community/area-counter/releases/tag/v1.0) still has
section output and the in-window guide.

| Русский интерфейс | English UI |
|---|---|
| [area-counter-1.1-rus.zip](https://github.com/B-A-community/area-counter/releases/download/v1.1/area-counter-1.1-rus.zip) | [area-counter-1.1-eng.zip](https://github.com/B-A-community/area-counter/releases/download/v1.1/area-counter-1.1-eng.zip) |

Each archive contains the `.rbz` extension and a one-page PDF guide.

Install: SketchUp → `Window → Extension Manager → Install Extension` → pick the
`.rbz` → restart SketchUp. Remove the previous version first.

Both builds come from the same source and differ only in UI language: all
strings live in `src/area_counter/lang.rb` (Ruby — menus, messages, tables) and
`src/area_counter/html/i18n.js` (windows); the build script swaps the
`LANG = 'ru'|'en'` line in a copy. The English build uses a decimal point.

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
  tried and the one used is written in the status. Only the cut height is in
  the window; weld, gaps, hidden objects and courtyards use the defaults
  (courtyards are not subtracted). Separate pieces over 0.1 m² are not included
  in the floor area and are mentioned in the status. Sections output by
  versions before 1.1 are recognised and never counted as floors.

**The window** follows the [B&A design code](https://github.com/B-A-community/ralncs/tree/main/design):
buttons in one row → status line → complex → building → floor tree → footer,
settings pinned on the right, “About…” in the menu.

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

`tools/selftest.rb` — 41 checks (section modules, the 10 spec test cases,
sections left by earlier versions, top face, hierarchy and tables). In the
SketchUp Ruby Console with the extension loaded:

```ruby
load 'C:/path/to/repo/tools/selftest.rb'
BACommunity::AreaCounter::SelfTest.run
```

As of 18.10.2026: 41 of 41 in SketchUp 2024, Russian and English builds
(1.0 was also tested in 2025 and 2026).

## License

Apache License 2.0 — see [LICENSE](LICENSE).
