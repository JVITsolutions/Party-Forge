# Hollow and Zangetsu Coin Variants Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create three transparent eight-frame Party Forge coin sprite sheets featuring Ichigo's Hollow mask on the black side and Old Man Zangetsu on the white side.

**Architecture:** Use the approved Gogecoins master sheet only as a geometry, registration, and animation reference. Generate each visual treatment separately with the built-in image-generation tool on a removable green background, convert that background to alpha with the installed helper, normalize the result into exact 1024x512 and 512x256 sheets, then validate geometry, color separation, alpha quality, and character readability.

**Tech Stack:** Built-in image generation, PNG/RGBA, Codex bundled Python, Pillow, `remove_chroma_key.py`, Godot 4 sprite-sheet conventions.

## Global Constraints

- Use an exact 4-column by 2-row sheet with eight equal cells.
- Frames 0, 1, and 7 show the black Hollow-mask side.
- Frames 3, 4, and 5 show the white Old Man Zangetsu side.
- Frames 2 and 6 are thin edge-on transitions.
- Export a 1024x512 RGBA master with 256x256 cells and a 512x256 RGBA runtime sheet with 128x128 cells.
- Preserve all existing coin sheets and `scenes/game/main.tscn`.
- Do not wire these variants into a scene in this plan.
- Do not stage or commit generated assets unless the user separately requests source-control publication.
- Treat the character depictions as fan-art placeholders requiring appropriate rights for public or commercial distribution.

---

### Task 1: Generate the Gritty Enamel Relief Variant

**Files:**
- Reference: `assets/ui/currency/gogecoins_spin_master.png`
- Create: `assets/ui/currency/hollow_zangetsu_enamel_spin_master.png`
- Create: `assets/ui/currency/hollow_zangetsu_enamel_spin_128.png`
- Temporary: `tmp/imagegen/hollow_zangetsu_enamel_spin_chroma.png`

**Interfaces:**
- Consumes: the established eight-frame geometry and frame registration from `gogecoins_spin_master.png`.
- Produces: a 1024x512 master and 512x256 runtime sheet whose frame order matches the shared animation contract.

- [ ] **Step 1: Inspect the reference at original resolution**

Use `view_image` on `assets/ui/currency/gogecoins_spin_master.png`. Confirm it contains eight centered frames in a 4x2 layout and that frames 2 and 6 are edge-on.

- [ ] **Step 2: Generate the enamel source sheet**

Use the built-in image-generation tool with `assets/ui/currency/gogecoins_spin_master.png` as the edit target and this exact prompt:

```text
Use case: precise-object-edit
Asset type: 2D Godot game currency animation sprite sheet
Input images: Image 1 is the geometry, animation, and registration reference.
Primary request: Create a gritty black-and-white enamel coin. The black obverse carries Ichigo Kurosaki's complete white Hollow mask in shallow raised relief, including narrow eye openings, teeth, horn-like silhouette, and restrained red markings. The white reverse carries Old Man Zangetsu's severe face in dark etched relief, including long dark hair, beard and mustache, angular features, and dark wraparound sunglasses.
Frame mapping: frames 1 and 2 show the black Hollow-mask side; frame 3 is edge-on; frames 4, 5, and 6 show the white Old Man Zangetsu side; frame 7 is edge-on; frame 8 returns toward the black Hollow-mask side.
Style: preserve the thin battered medieval coin geometry, chipped enamel, hammered rim, scratches, nicks, dark patina, rubbed highlights, and gritty hand-painted Party Forge style. Keep both portraits bold and readable at 64x64.
Layout: exact 4 columns by 2 rows, eight equal square cells, one identically scaled upright coin centered in each cell. No wobble, tilt, bounce, translation, cropping, overlap, or size drift.
Backdrop: perfectly flat solid #00ff00 chroma-key background with no shadows, gradients, texture, floor, reflections, or lighting variation.
Constraints: exactly eight coins; no text, Bleach logos, franchise logos, grid lines, dividers, cast shadows, particles, glow, border, watermark, or extra objects. Do not use #00ff00 in the coins. Crisp isolated silhouettes.
```

Record the exact generated PNG path returned by the tool as `$generatedSource`; do not infer or reconstruct that path.

- [ ] **Step 3: Convert the background to alpha**

Run in PowerShell after setting `$generatedSource` to the exact tool-returned path:

```powershell
$repo = 'F:\Projects(root)\Game dev\Projects\party-forge'
$python = 'C:\Users\Jacob\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$helper = 'C:\Users\Jacob\.codex\skills\.system\imagegen\scripts\remove_chroma_key.py'
$temp = Join-Path $repo 'tmp\imagegen\hollow_zangetsu_enamel_spin_chroma.png'
$alpha = Join-Path $repo 'tmp\imagegen\hollow_zangetsu_enamel_spin_alpha.png'
New-Item -ItemType Directory -Force -Path (Split-Path $temp) | Out-Null
Copy-Item -LiteralPath $generatedSource -Destination $temp
& $python $helper --input $temp --out $alpha --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill
```

Expected: the helper reports a sampled green key color and writes the alpha PNG.

- [ ] **Step 4: Normalize the two deliverable sizes**

Run:

```powershell
@'
from pathlib import Path
from PIL import Image
repo = Path(r"F:\Projects(root)\Game dev\Projects\party-forge")
source = Image.open(repo / "tmp/imagegen/hollow_zangetsu_enamel_spin_alpha.png").convert("RGBA")
assert source.width == source.height * 2, source.size
source.resize((1024, 512), Image.Resampling.LANCZOS).save(repo / "assets/ui/currency/hollow_zangetsu_enamel_spin_master.png", optimize=True)
source.resize((512, 256), Image.Resampling.LANCZOS).save(repo / "assets/ui/currency/hollow_zangetsu_enamel_spin_128.png", optimize=True)
'@ | & $python -
```

Expected: both output files exist with no Python assertion failure.

- [ ] **Step 5: Validate and visually review the enamel runtime sheet**

Run:

```powershell
@'
from pathlib import Path
from PIL import Image
path = Path(r"F:\Projects(root)\Game dev\Projects\party-forge\assets\ui\currency\hollow_zangetsu_enamel_spin_128.png")
image = Image.open(path)
assert image.format == "PNG" and image.mode == "RGBA" and image.size == (512, 256)
assert all(image.getpixel(point)[3] == 0 for point in ((0, 0), (511, 0), (0, 255), (511, 255)))
boxes = []
for frame in range(8):
    x, y = (frame % 4) * 128, (frame // 4) * 128
    alpha = image.getchannel("A").crop((x, y, x + 128, y + 128))
    box = alpha.getbbox()
    assert box is not None
    boxes.append(box)
assert (boxes[2][2] - boxes[2][0]) / (boxes[0][2] - boxes[0][0]) < 0.35
print("PASS enamel runtime: 512x256 RGBA, 8 occupied cells, thin edge frames")
'@ | & $python -
```

Expected: `PASS enamel runtime: 512x256 RGBA, 8 occupied cells, thin edge frames`.

Then use `view_image` on `hollow_zangetsu_enamel_spin_128.png` and confirm the Hollow mask reads on black frames while Old Man Zangetsu reads on white frames.

---

### Task 2: Generate the Pure Graphic Black-and-White Variant

**Files:**
- Reference: `assets/ui/currency/gogecoins_spin_master.png`
- Create: `assets/ui/currency/hollow_zangetsu_graphic_spin_master.png`
- Create: `assets/ui/currency/hollow_zangetsu_graphic_spin_128.png`
- Temporary: `tmp/imagegen/hollow_zangetsu_graphic_spin_chroma.png`

**Interfaces:**
- Consumes: the established eight-frame geometry and shared character/frame contract.
- Produces: a maximum-readability graphic variant in the same master/runtime dimensions.

- [ ] **Step 1: Generate the graphic source sheet**

Use the built-in image-generation tool with `assets/ui/currency/gogecoins_spin_master.png` as the edit target and this exact prompt:

```text
Use case: precise-object-edit
Asset type: 2D Godot game currency animation sprite sheet
Input images: Image 1 is the geometry, animation, and registration reference.
Primary request: Create a stark graphic black-and-white coin. The black obverse carries Ichigo Kurosaki's complete white Hollow mask as a hard-edged poster-like graphic with narrow eye openings, teeth, horn-like silhouette, and red mask markings. The white reverse carries Old Man Zangetsu's face as a hard-edged black graphic with long hair, beard and mustache, angular face, and wraparound sunglasses.
Frame mapping: frames 1 and 2 show the black Hollow-mask side; frame 3 is edge-on; frames 4, 5, and 6 show the white Old Man Zangetsu side; frame 7 is edge-on; frame 8 returns toward the black Hollow-mask side.
Style: nearly pure black and white face fields, very high contrast, minimal gray shading only where required for coin depth and rotation. Preserve the thin irregular medieval rim but remove most face texture. Optimize for readability at 64x64.
Layout: exact 4 columns by 2 rows, eight equal square cells, one identically scaled upright coin centered in each cell. No wobble, tilt, bounce, translation, cropping, overlap, or size drift.
Backdrop: perfectly flat solid #00ff00 chroma-key background with no shadows, gradients, texture, floor, reflections, or lighting variation.
Constraints: exactly eight coins; no text, Bleach logos, franchise logos, grid lines, dividers, cast shadows, particles, glow, border, watermark, or extra objects. Red may appear only in the Hollow mask markings. Do not use #00ff00 in the coins. Crisp isolated silhouettes.
```

Record the exact generated PNG path as `$generatedSource`.

- [ ] **Step 2: Convert, normalize, and inspect the graphic variant**

After setting `$generatedSource` to the exact tool-returned path, run:

```powershell
$repo = 'F:\Projects(root)\Game dev\Projects\party-forge'
$python = 'C:\Users\Jacob\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$helper = 'C:\Users\Jacob\.codex\skills\.system\imagegen\scripts\remove_chroma_key.py'
$temp = Join-Path $repo 'tmp\imagegen\hollow_zangetsu_graphic_spin_chroma.png'
$alpha = Join-Path $repo 'tmp\imagegen\hollow_zangetsu_graphic_spin_alpha.png'
New-Item -ItemType Directory -Force -Path (Split-Path $temp) | Out-Null
Copy-Item -LiteralPath $generatedSource -Destination $temp
& $python $helper --input $temp --out $alpha --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill
@'
from pathlib import Path
from PIL import Image
repo = Path(r"F:\Projects(root)\Game dev\Projects\party-forge")
source = Image.open(repo / "tmp/imagegen/hollow_zangetsu_graphic_spin_alpha.png").convert("RGBA")
assert source.width == source.height * 2, source.size
source.resize((1024, 512), Image.Resampling.LANCZOS).save(repo / "assets/ui/currency/hollow_zangetsu_graphic_spin_master.png", optimize=True)
source.resize((512, 256), Image.Resampling.LANCZOS).save(repo / "assets/ui/currency/hollow_zangetsu_graphic_spin_128.png", optimize=True)
'@ | & $python -
```

Use `view_image` on the runtime sheet. Confirm it is visually flatter and higher contrast than the enamel version while preserving a readable rotating coin silhouette.

- [ ] **Step 3: Validate the graphic runtime sheet**

Run:

```powershell
@'
from pathlib import Path
from PIL import Image
path = Path(r"F:\Projects(root)\Game dev\Projects\party-forge\assets\ui\currency\hollow_zangetsu_graphic_spin_128.png")
image = Image.open(path)
assert image.format == "PNG" and image.mode == "RGBA" and image.size == (512, 256)
assert all(image.getpixel(point)[3] == 0 for point in ((0, 0), (511, 0), (0, 255), (511, 255)))
boxes = []
for frame in range(8):
    x, y = (frame % 4) * 128, (frame // 4) * 128
    alpha = image.getchannel("A").crop((x, y, x + 128, y + 128))
    box = alpha.getbbox()
    assert box is not None
    boxes.append(box)
assert (boxes[2][2] - boxes[2][0]) / (boxes[0][2] - boxes[0][0]) < 0.35
print("PASS graphic runtime: 512x256 RGBA, 8 occupied cells, thin edge frames")
'@ | & $python -
```

Expected: `PASS graphic runtime: 512x256 RGBA, 8 occupied cells, thin edge frames`.

---

### Task 3: Generate the Gunmetal-and-Silver Variant

**Files:**
- Reference: `assets/ui/currency/gogecoins_spin_master.png`
- Create: `assets/ui/currency/hollow_zangetsu_metal_spin_master.png`
- Create: `assets/ui/currency/hollow_zangetsu_metal_spin_128.png`
- Temporary: `tmp/imagegen/hollow_zangetsu_metal_spin_chroma.png`

**Interfaces:**
- Consumes: the established eight-frame geometry and shared character/frame contract.
- Produces: a grounded dark-gunmetal/bright-silver variant in the same master/runtime dimensions.

- [ ] **Step 1: Generate the metal source sheet**

Use the built-in image-generation tool with `assets/ui/currency/gogecoins_spin_master.png` as the edit target and this exact prompt:

```text
Use case: precise-object-edit
Asset type: 2D Godot game currency animation sprite sheet
Input images: Image 1 is the geometry, animation, and registration reference.
Primary request: Create a grounded gunmetal-and-silver coin. The dark gunmetal obverse carries Ichigo Kurosaki's complete Hollow mask engraved and inlaid with pale silver and muted red markings. The bright worn-silver reverse carries Old Man Zangetsu's face engraved into deep charcoal recesses, including long hair, beard and mustache, angular face, and wraparound sunglasses.
Frame mapping: frames 1 and 2 show the gunmetal Hollow-mask side; frame 3 is edge-on; frames 4, 5, and 6 show the silver Old Man Zangetsu side; frame 7 is edge-on; frame 8 returns toward the gunmetal Hollow-mask side.
Style: thin battered medieval coin, hammered edge, metallic wear, scratches, nicks, dark patina, rubbed high points, subtle specular highlights, gritty hand-painted Party Forge rendering. Grounded metal, not glossy chrome. Keep both designs readable at 64x64.
Layout: exact 4 columns by 2 rows, eight equal square cells, one identically scaled upright coin centered in each cell. No wobble, tilt, bounce, translation, cropping, overlap, or size drift.
Backdrop: perfectly flat solid #00ff00 chroma-key background with no shadows, gradients, texture, floor, reflections, or lighting variation.
Constraints: exactly eight coins; no text, Bleach logos, franchise logos, grid lines, dividers, cast shadows, particles, glow, border, watermark, or extra objects. Do not use #00ff00 in the coins. Crisp isolated silhouettes.
```

Record the exact generated PNG path as `$generatedSource`.

- [ ] **Step 2: Convert, normalize, and inspect the metal variant**

After setting `$generatedSource` to the exact tool-returned path, run:

```powershell
$repo = 'F:\Projects(root)\Game dev\Projects\party-forge'
$python = 'C:\Users\Jacob\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$helper = 'C:\Users\Jacob\.codex\skills\.system\imagegen\scripts\remove_chroma_key.py'
$temp = Join-Path $repo 'tmp\imagegen\hollow_zangetsu_metal_spin_chroma.png'
$alpha = Join-Path $repo 'tmp\imagegen\hollow_zangetsu_metal_spin_alpha.png'
New-Item -ItemType Directory -Force -Path (Split-Path $temp) | Out-Null
Copy-Item -LiteralPath $generatedSource -Destination $temp
& $python $helper --input $temp --out $alpha --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill
@'
from pathlib import Path
from PIL import Image
repo = Path(r"F:\Projects(root)\Game dev\Projects\party-forge")
source = Image.open(repo / "tmp/imagegen/hollow_zangetsu_metal_spin_alpha.png").convert("RGBA")
assert source.width == source.height * 2, source.size
source.resize((1024, 512), Image.Resampling.LANCZOS).save(repo / "assets/ui/currency/hollow_zangetsu_metal_spin_master.png", optimize=True)
source.resize((512, 256), Image.Resampling.LANCZOS).save(repo / "assets/ui/currency/hollow_zangetsu_metal_spin_128.png", optimize=True)
'@ | & $python -
```

Use `view_image` on the runtime sheet. Confirm the gunmetal side remains clearly darker than the worn-silver side without collapsing facial details into black.

- [ ] **Step 3: Validate the metal runtime sheet**

Run:

```powershell
@'
from pathlib import Path
from PIL import Image
path = Path(r"F:\Projects(root)\Game dev\Projects\party-forge\assets\ui\currency\hollow_zangetsu_metal_spin_128.png")
image = Image.open(path)
assert image.format == "PNG" and image.mode == "RGBA" and image.size == (512, 256)
assert all(image.getpixel(point)[3] == 0 for point in ((0, 0), (511, 0), (0, 255), (511, 255)))
boxes = []
for frame in range(8):
    x, y = (frame % 4) * 128, (frame // 4) * 128
    alpha = image.getchannel("A").crop((x, y, x + 128, y + 128))
    box = alpha.getbbox()
    assert box is not None
    boxes.append(box)
assert (boxes[2][2] - boxes[2][0]) / (boxes[0][2] - boxes[0][0]) < 0.35
print("PASS metal runtime: 512x256 RGBA, 8 occupied cells, thin edge frames")
'@ | & $python -
```

Expected: `PASS metal runtime: 512x256 RGBA, 8 occupied cells, thin edge frames`.

---

### Task 4: Run Shared Technical and Visual QA

**Files:**
- Verify: `assets/ui/currency/hollow_zangetsu_enamel_spin_master.png`
- Verify: `assets/ui/currency/hollow_zangetsu_enamel_spin_128.png`
- Verify: `assets/ui/currency/hollow_zangetsu_graphic_spin_master.png`
- Verify: `assets/ui/currency/hollow_zangetsu_graphic_spin_128.png`
- Verify: `assets/ui/currency/hollow_zangetsu_metal_spin_master.png`
- Verify: `assets/ui/currency/hollow_zangetsu_metal_spin_128.png`

**Interfaces:**
- Consumes: all six outputs from Tasks 1-3.
- Produces: fresh evidence that every deliverable satisfies the common Godot sprite-sheet contract.

- [ ] **Step 1: Run the shared validation script**

Run with the Codex bundled Python:

```powershell
$python = 'C:\Users\Jacob\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
@'
from pathlib import Path
from PIL import Image

root = Path(r"F:\Projects(root)\Game dev\Projects\party-forge\assets\ui\currency")
prefixes = (
    "hollow_zangetsu_enamel_spin",
    "hollow_zangetsu_graphic_spin",
    "hollow_zangetsu_metal_spin",
)

for prefix in prefixes:
    for suffix, expected, cell in (
        ("master", (1024, 512), 256),
        ("128", (512, 256), 128),
    ):
        path = root / f"{prefix}_{suffix}.png"
        image = Image.open(path)
        assert image.format == "PNG", (path, image.format)
        assert image.mode == "RGBA", (path, image.mode)
        assert image.size == expected, (path, image.size)
        assert all(image.getpixel(point)[3] == 0 for point in (
            (0, 0), (image.width - 1, 0),
            (0, image.height - 1), (image.width - 1, image.height - 1),
        ))
        boxes = []
        visible_green = 0
        visible = 0
        for red, green, blue, alpha in image.getdata():
            if alpha >= 32:
                visible += 1
                if green > red * 1.35 and green > blue * 1.35 and green > 100:
                    visible_green += 1
        for frame in range(8):
            x = (frame % 4) * cell
            y = (frame // 4) * cell
            alpha = image.getchannel("A").crop((x, y, x + cell, y + cell))
            box = alpha.getbbox()
            opaque = sum(1 for value in alpha.getdata() if value >= 128)
            assert box is not None and opaque > cell * cell * 0.02, (path, frame)
            boxes.append(box)
        face_width = boxes[0][2] - boxes[0][0]
        edge_width = boxes[2][2] - boxes[2][0]
        assert edge_width / face_width < 0.35, (path, edge_width, face_width)
        if suffix == "128":
            assert visible_green == 0, (path, visible_green, visible)
        print(f"PASS {path.name}: {image.size} RGBA, frames=8, edge_ratio={edge_width / face_width:.3f}, green={visible_green}/{visible}")
'@ | & $python -
```

Expected: six `PASS` lines and no assertion traceback.

- [ ] **Step 2: Compare the three runtime sheets visually**

Use `view_image` at original detail on each 512x256 runtime sheet. Confirm:

- Enamel is the most textured and closest to Gogecoins.
- Graphic is the highest-contrast and clearest at small size.
- Metal is the most grounded and materially subtle.
- Every black-side frame depicts the Hollow mask.
- Every white-side frame depicts Old Man Zangetsu.
- Frames 2 and 6 remain thin and emblem-free.

- [ ] **Step 3: Remove only generated temporary files**

Resolve each exact path under `F:\Projects(root)\Game dev\Projects\party-forge\tmp\imagegen`, confirm it begins with the repository path, and remove only these six task-owned files:

```text
hollow_zangetsu_enamel_spin_chroma.png
hollow_zangetsu_enamel_spin_alpha.png
hollow_zangetsu_graphic_spin_chroma.png
hollow_zangetsu_graphic_spin_alpha.png
hollow_zangetsu_metal_spin_chroma.png
hollow_zangetsu_metal_spin_alpha.png
```

- [ ] **Step 4: Verify repository scope**

Run:

```powershell
git -C 'F:\Projects(root)\Game dev\Projects\party-forge' status --short -- scenes/game/main.tscn assets/ui/currency docs/superpowers
```

Expected: the pre-existing `scenes/game/main.tscn` modification remains present, existing coin assets remain preserved, and the six new Hollow/Zangetsu PNGs are visible as untracked project assets unless the user separately requested committing them.

---

### Task 5: Organize All Generated Art in the Shared Art Library

**Files:**
- Create directory: `F:\Projects(root)\Game dev\Projects\art\ui\currency\party-forge`
- Create directory: `F:\Projects(root)\Game dev\Projects\art\concepts\coins`
- Create directory: `F:\Projects(root)\Game dev\Projects\art\models`
- Create directory: `F:\Projects(root)\Game dev\Projects\art\characters`
- Create directory: `F:\Projects(root)\Game dev\Projects\art\environments`
- Create directory: `F:\Projects(root)\Game dev\Projects\art\textures`
- Move: `F:\Projects(root)\Game dev\Projects\coin-icon-concepts`
- Move: every generated PNG from `F:\Projects(root)\Game dev\Projects\party-forge\assets\ui\currency`
- Move: the six reviewed Hollow/Zangetsu PNGs from the isolated worktree's `assets\ui\currency` directory

**Interfaces:**
- Consumes: the reviewed outputs from Tasks 1-4 plus every earlier coin asset created in this conversation.
- Produces: one category-organized shared art library outside the Party Forge repository, with concepts separated from runtime-ready UI currency sheets.

- [ ] **Step 1: Resolve and verify every move boundary**

Resolve the absolute source and destination paths. Require every path to begin with `F:\Projects(root)\Game dev\Projects`. Refuse the move if a destination file already exists or if any resolved path falls outside that workspace root.

- [ ] **Step 2: Create the category folders**

Create the six exact directories listed above. Empty future-facing categories such as `models` are intentional.

- [ ] **Step 3: Move the source concepts**

Move the complete `coin-icon-concepts` directory to:

```text
F:\Projects(root)\Game dev\Projects\art\concepts\coins\coin-icon-concepts
```

Preserve its `64px` and `128px` subdirectories and all source PNGs.

- [ ] **Step 4: Move the runtime-ready currency sheets**

Move every generated currency PNG from the live Party Forge asset directory and all six reviewed Hollow/Zangetsu PNGs from the isolated worktree into:

```text
F:\Projects(root)\Game dev\Projects\art\ui\currency\party-forge
```

Do not move Godot scenes, scripts, import caches, `.import` sidecars, plans, specifications, or unrelated art.

- [ ] **Step 5: Verify the organized inventory**

List every PNG recursively under the shared art library. Confirm:

- `art\concepts\coins\coin-icon-concepts` contains the four full-size concepts and their eight 64px/128px derivatives.
- `art\ui\currency\party-forge` contains all previously generated coin sheets plus the six Hollow/Zangetsu sheets.
- `party-forge\assets\ui\currency` contains no generated PNGs.
- The isolated worktree's `assets\ui\currency` contains no Hollow/Zangetsu PNGs after the move.
- `scenes/game/main.tscn` remains untouched.
