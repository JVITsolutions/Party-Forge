# Hollow and Zangetsu Coin Variant Design

## Goal

Create three related eight-frame spinning coin sprite sheets for Party Forge. Every variant uses Ichigo Kurosaki's Hollow mask on the black-facing side and Old Man Zangetsu's face on the white-facing side.

These are fan-art placeholders. Public or commercial distribution requires appropriate rights to the depicted characters.

## Shared Animation Contract

- Use a 4-column by 2-row sheet with eight equal square cells.
- Order frames left-to-right across the top row, then left-to-right across the bottom row.
- Frames 0, 1, and 7 show the black Hollow-mask side.
- Frames 3, 4, and 5 show the white Old Man Zangetsu side.
- Frames 2 and 6 are thin edge-on transitions.
- Keep the coin upright, centered, identically scaled, and registered in every cell.
- Preserve the thin, battered medieval geometry established by the approved Party Forge coin sheets.
- Export a 1024x512 RGBA master with 256x256 cells and a 512x256 RGBA runtime sheet with 128x128 cells.
- Use transparent backgrounds in final PNGs. Do not include text, logos, grids, shadows, particles, or extra objects.

## Character Readability

### Black Side: Ichigo's Hollow Mask

- Use the complete white bone mask as the emblem rather than Ichigo's uncovered face.
- Retain its narrow eye openings, tooth pattern, horn-like silhouette, and red markings.
- Simplify fine detail enough to remain recognizable at 64x64 display size.

### White Side: Old Man Zangetsu

- Use a severe frontal or slight three-quarter head portrait.
- Retain long dark hair, beard and mustache, angular face, and dark wraparound sunglasses.
- Render the portrait as a bold relief or graphic silhouette appropriate to each treatment.

## Variant A: Gritty Enamel Relief

This is the recommended treatment and the closest match to Gogecoins.

- Black side: chipped black enamel over dark forged metal, with a raised bone-white Hollow mask and restrained red markings.
- White side: aged ivory enamel, with Old Man Zangetsu etched in charcoal-black relief.
- Use scratched surfaces, rubbed rims, dark patina, and restrained highlights.
- Filenames: `hollow_zangetsu_enamel_spin_master.png` and `hollow_zangetsu_enamel_spin_128.png`.

## Variant B: Pure Graphic Black and White

This treatment prioritizes maximum HUD readability.

- Use nearly flat pure black and white fields with hard-edged, poster-like character graphics.
- Keep only minimal gray edge shading required to communicate coin depth and rotation.
- Preserve the medieval irregular rim, but remove most surface texture from the faces.
- Use red only for the Hollow mask's canonical markings.
- Filenames: `hollow_zangetsu_graphic_spin_master.png` and `hollow_zangetsu_graphic_spin_128.png`.

## Variant C: Gunmetal and Silver

This treatment is the most grounded and least literal interpretation of black and white.

- Black side: dark gunmetal with the Hollow mask engraved and filled with pale silver and muted red.
- White side: bright worn silver with Old Man Zangetsu engraved in deep charcoal recesses.
- Emphasize metallic wear, hammered edges, and subtle specular highlights without becoming glossy.
- Filenames: `hollow_zangetsu_metal_spin_master.png` and `hollow_zangetsu_metal_spin_128.png`.

## Validation

For each final sheet:

- Confirm PNG format, RGBA mode, exact expected dimensions, and transparent corners.
- Confirm all eight cells contain visible coin pixels.
- Confirm edge-on frames are materially thinner than face-on frames.
- Confirm no visible chroma-key fringe in the 128-pixel runtime sheet.
- Visually verify the Hollow mask on black frames and Old Man Zangetsu on white frames at actual runtime size.
- Preserve all existing coin sheets and unrelated working-tree changes.
