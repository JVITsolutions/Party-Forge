# Living Forge UI Asset Provenance

**Retrieved:** 2026-08-28
**Scope:** Packaged fonts, interface icons, and their redistribution licences for the Living Forge UI. Runtime resources reference only these local files; no floating CDN resource is used.

## Pinned upstreams

| Asset family | Reviewed version | Immutable source | Licence |
| --- | --- | --- | --- |
| Cinzel | 2.000 | Google Fonts commit `45071f07c63e863a539442ef3562b71ab1f147a6` (`cinzel: v2.000 added`) | SIL Open Font License 1.1 |
| Source Sans 3 | 3.052R | `adobe-fonts/source-sans` tag `3.052R`, resolved commit `ed1808970eb3c7301c9a523bee26473ba0bb62fa` | SIL Open Font License 1.1; Reserved Font Name `Source` |
| Noto Sans | NotoSans-v2.014 | `notofonts/latin-greek-cyrillic` tag `NotoSans-v2.014`, resolved commit `22328ea1ab03320d5519445fb74fd5659eebcb81`; official release archive SHA-256 `1dffbaf31a0a699ee2c57dfb60c1a628010425301dd076cfb485adbe017352c1` | SIL Open Font License 1.1 |
| Noto Sans Symbols 2 | NotoSansSymbols2-v2.008 | `notofonts/symbols` tag `NotoSansSymbols2-v2.008`, resolved commit `25b00f0d3f40873a005287514ba2a48558655314`; official release archive SHA-256 `346c930bbe8eb946701a05c54e9c11a2094dee1d93c387bf1771c0a3e335688f` | SIL Open Font License 1.1 |
| Tabler Icons | v3.46.0 | `tabler/tabler-icons` tag `v3.46.0`, resolved commit `8ac7d81b72ece11072ef25ea9fd92e80c6f3c9fc` | MIT |

The Noto archive selections are the official Google Fonts distribution variants: `NotoSans/googlefonts/variable-ttf/NotoSans[wdth,wght].ttf` and `NotoSansSymbols2/googlefonts/ttf/NotoSansSymbols2-Regular.ttf`. Their licences come from each release archive's root `OFL.txt`.

## Imported file inventory

Every SHA-256 below is calculated from the packaged local file.

| Family | Original path in pinned source | Local path | SHA-256 |
| --- | --- | --- | --- |
| Cinzel 2.000 | `ofl/cinzel/Cinzel[wght].ttf` | `assets/ui/living_forge/fonts/cinzel-2.000/Cinzel[wght].ttf` | `f4d83d34d1f6c741193e4acf4b3dff9531e5a67b6aa65228d00a7db72a4e0f34` |
| Cinzel 2.000 | `ofl/cinzel/OFL.txt` | `assets/ui/living_forge/fonts/cinzel-2.000/OFL.txt` | `f5a242cf68ad6ebd0603b3359a74c593ca080318a681035be5296ba2c6b04ae6` |
| Source Sans 3 3.052R | `VF/SourceSans3VF-Upright.ttf` | `assets/ui/living_forge/fonts/source-sans-3.052/SourceSans3VF-Upright.ttf` | `1147db9a3f0edd4956068de77930148acce2742dd76d57f7239b2b1c687ac63f` |
| Source Sans 3 3.052R | `LICENSE.md` | `assets/ui/living_forge/fonts/source-sans-3.052/LICENSE.md` | `937d1985d2d6d003b6efdfa47e098b96c69d55395175f154d7f56410c942f978` |
| Noto Sans v2.014 | `NotoSans-v2.014.zip!/NotoSans/googlefonts/variable-ttf/NotoSans[wdth,wght].ttf` | `assets/ui/living_forge/fonts/noto-sans-2.014/NotoSans[wdth,wght].ttf` | `90a2b3c1fc4895e0d5f4ada26aab1592c0c52f4255b874734a8ede8c30cbaa29` |
| Noto Sans v2.014 | `NotoSans-v2.014.zip!/OFL.txt` | `assets/ui/living_forge/fonts/noto-sans-2.014/OFL.txt` | `e2e177a32561584d4fc13aaa3cd8e53758a12910f013fe9ca125419111722029` |
| Noto Sans Symbols 2 v2.008 | `NotoSansSymbols2-v2.008.zip!/NotoSansSymbols2/googlefonts/ttf/NotoSansSymbols2-Regular.ttf` | `assets/ui/living_forge/fonts/noto-sans-symbols-2.008/NotoSansSymbols2-Regular.ttf` | `7d5fb73b7ca67a6798101741f5d280a3d016a56a197afcd4199dbb57b4b82a21` |
| Noto Sans Symbols 2 v2.008 | `NotoSansSymbols2-v2.008.zip!/OFL.txt` | `assets/ui/living_forge/fonts/noto-sans-symbols-2.008/OFL.txt` | `e87c2ed7ff174c637d55fa381939ebb96f43f0415ad94605a37589228f4cbf4f` |
| Tabler Icons v3.46.0 | `LICENSE` | `assets/ui/living_forge/icons/tabler-3.46.0/LICENSE` | `b740a1d46122672da62833e97f7e7c8a13fa85cbc7445b584b297cc00dde93db` |
| Tabler Icons v3.46.0 | `icons/outline/alert-triangle.svg` | `assets/ui/living_forge/icons/tabler-3.46.0/alert-triangle.svg` | `fc82f02dc9702293cb8609a8aed3242c0fe5f5b3337d79d341aa9343b4526ad4` |
| Tabler Icons v3.46.0 | `icons/outline/arrow-left.svg` | `assets/ui/living_forge/icons/tabler-3.46.0/arrow-left.svg` | `058fc4190c178ecce118b6294b74235d4f88c4dfbd17c6159d67210a03222bc0` |
| Tabler Icons v3.46.0 | `icons/outline/check.svg` | `assets/ui/living_forge/icons/tabler-3.46.0/check.svg` | `fe359b27c74ed0f4f72bfabbe5ca969a8bb13a5f39648bae63f9e798034ebed3` |
| Tabler Icons v3.46.0 | `icons/outline/device-gamepad.svg` | `assets/ui/living_forge/icons/tabler-3.46.0/device-gamepad.svg` | `a2591eec1e15bbe8740ad349260c838abe55994e358030b3e5fec09b9a111682` |
| Tabler Icons v3.46.0 | `icons/outline/hourglass.svg` | `assets/ui/living_forge/icons/tabler-3.46.0/hourglass.svg` | `64316d209522bc02b8a205184af4143584d7a4de7b5cb7c1ef8a84aec7aebd3e` |
| Tabler Icons v3.46.0 | `icons/outline/keyboard.svg` | `assets/ui/living_forge/icons/tabler-3.46.0/keyboard.svg` | `8dcb52240a7f121651455a0a71322cb306c7e4695c70b4a9c14c453dc231c5da` |
| Tabler Icons v3.46.0 | `icons/outline/lock.svg` | `assets/ui/living_forge/icons/tabler-3.46.0/lock.svg` | `19ef0a4888688ea415b611b7c9e085134683a7fbdce5517be1f722a65e28928d` |
| Tabler Icons v3.46.0 | `icons/outline/player-play.svg` | `assets/ui/living_forge/icons/tabler-3.46.0/player-play.svg` | `0178cf0262ec89422d632f6122c6be34a8b57db32dd1aea38dd283bdeecbfc2f` |
| Tabler Icons v3.46.0 | `icons/outline/settings.svg` | `assets/ui/living_forge/icons/tabler-3.46.0/settings.svg` | `d71136dfd83ad19efe1777d01768a5d23d7b295de5dde3b1fccc50806809a423` |
| Tabler Icons v3.46.0 | `icons/outline/shield.svg` | `assets/ui/living_forge/icons/tabler-3.46.0/shield.svg` | `98a7e284db5311c030b1dac736c9300e8c2799980ceb424806cc09894d373a0e` |
| Tabler Icons v3.46.0 | `icons/outline/user.svg` | `assets/ui/living_forge/icons/tabler-3.46.0/user.svg` | `4aeefe49af9decdd7b348ada73d9ef410b39f3599a2f2d38abb9e9eb3967e272` |

The official Source Sans `LICENSE.md` is CRLF-encoded upstream (SHA-256 `89ad2c4f66dd29127527493e729c31e731f111cf10faf5774c3db9275ed0c22c`). Repository text policy normalizes licence copies to LF and removes trailing end-of-line whitespace where present, without changing licence wording. The packaged normalized file hashes are recorded in the inventory.

## Party Forge-owned assets

These original, project-owned SVGs were authored for this UI slice on an eight-pixel geometry grid. They contain no baked text or semantic state color and use `currentColor` for caller-controlled presentation.

| Local path | Purpose | SHA-256 |
| --- | --- | --- |
| `assets/ui/living_forge/frames/forge_panel.svg` | Clipped-corner forged panel with one restrained upper notch | `c56ba15c51fc53b213e3088e9fa4202e9dddfb89c80b3923f616013fc1fc667e` |
| `assets/ui/living_forge/frames/class_silhouette.svg` | Neutral, class-agnostic bust fallback | `73d7f659a0e3d75b43d4932967e99cb225e09a06981fc4e738d61f911406e778` |
