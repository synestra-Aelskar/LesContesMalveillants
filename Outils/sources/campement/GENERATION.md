# Campement d'apres le modele fourni

Direction artistique : image utilisateur Medal_beQdPOWpCI.png, pixel art bleu nuit
et ambre, grand arbre/lanterne a gauche, petite tente triangulaire, foyer au centre,
lac et sommet enneige. Generations et retouches faites avec l'outil integre image_gen.
Sources retenues seulement : lac-montagne.png, tente.png, feu.png, ciel-pixel.png.

## Construction

```
Banc/.venv/Scripts/python.exe Outils/campement_blp.py
Banc/.venv/Scripts/python.exe Outils/apercu_campement.py
```

Les dix BLP2 DXT5 sont dans LesContesMalveillants/ressources/campement.
Les apercus sont regeneres dans le dossier temporaire lcm-apercu-campement.
La scene est plein ecran sans bordure ; la tente reste a gauche, le ciel est fixe,
les astres se deplacent. Le feu utilise quatre poses. Le vote reste a 80 %.

## Prompt du decor, avec le modele en reference

Use the attached image as the STRICT art direction and composition reference for a layered game cinematic. Create ONLY the stationary environment layer. Match its authentic fine pixel art exactly: intentional square pixel clusters, strong silhouettes, rich deep navy and warm amber palette, NOT realistic painted foliage and NOT a fancy pavilion. Expand the composition to a 2:1 fullscreen landscape. Very large warm firelit tree trunk with a hanging amber lantern on LEFT, its branches arch across upper left. Foreground camp clearing and rocks/ferns across bottom. Leave EMPTY SPACE at lower left for the small A-frame tent and at lower middle for fire, which will be separate sprites. On the RIGHT a moonlit lake leading toward a snow-capped triangular mountain at center distance, with dark pine silhouettes along the lake banks, and silvery blue reflection strokes on the lake. Keep the reference's beautiful mountain, lake, tree, fern, rock, stump details. Remove the tent and fire entirely but keep their warm illumination on the ground and tree. Remove moon and sky: all SKY ABOVE the mountain silhouettes and BETWEEN the branches must be true transparent alpha. Mountains, water, trees and foreground opaque. Entire landscape reaches the rectangular image edges full bleed; NO circular vignette, no decorative border, no black oval background, no text. High quality detailed pixel art at high resolution, not blurry photo realism. Canvas2:1.

## Prompt de la tente, avec le modele en reference

Extract and recreate ONLY the small camping tent with backpack, bedroll and small wooden crate from this strict reference, as ONE isolated sprite on genuine transparent background. MATCH the reference's true 16-bit fine pixel art, visible deliberate square pixel clusters, limited deep brown and amber palette, NOT smooth digital painting. A simple small triangular A-frame orange-brown canvas tent with a ridge pole, three-quarter view, entrance at right, warmly lit from a campfire offscreen to its right. No ornate pavilion, no rounded circus roof, no decoration, no lantern on tent. Backpack and crate on left, rolled bedroll inside. Match the reference's proportions and charming detailed pixel craft. NO background, NO trees, NO ground patch, NO fire, NO moon, no text. Full sprite with transparent margin all around. High resolution asset, clean alpha edges, no colored fringe. Square canvas.

## Prompt du feu, avec le modele en reference

Use this image as STRICT pixel-art style reference. Generate a horizontal animation sprite sheet with FOUR equal-width cells, each one a consecutive animation frame of the SAME campfire in a circle of gray stones, crossed dark logs, bright orange flame with yellow center and tiny drifting pixel sparks. Match the reference's hand-crafted 16-bit pixel art: sharp square pixel clusters, limited amber orange deep brown palette, NOT realistic smooth rendered flames. Every cell same view and scale, same stone circle and logs at same bottom baseline, only flame/sparks change silhouette. Entire sprites fully inside their cell with generous transparent gutters and margins. TRUE alpha transparent background, no painted checkerboard, no ground, no sky, no tent, no text or borders. Four frames side by side, landscape4:1.

## Prompt du ciel, avec le modele en reference

Make a production 2x2 equal-quadrant atlas MATCHING THIS REFERENCE'S EXACT authentic fine 16-bit pixel art, square pixel clusters, navy-blue and ivory palette, never photo realism. Upper-left quadrant is an OPAQUE rectangular midnight blue starry sky background with a few angular pixel-art blue clouds, no moon. Upper-right quadrant is an OPAQUE rectangular dawn sky background with the SAME clouds, pale desaturated blue and warm gold near lower edge, no sun and no stars. These two upper quadrants fill their whole cells right up to edges; there is a straight divider at the exact half width. Bottom-left quadrant is just an isolated large round ivory pixel-art moon with simple pixel crater patches like in the reference, transparent surroundings. Bottom-right quadrant is just an isolated round warm pale golden pixel-art sun with a subtle halo, no rays or spikes, transparent surroundings. Exactly FOUR equal square cells on a SQUARE atlas. No text, no borders, no landscape, no tree, no tent. Keep transparent space between the isolated moon/sun and the cell boundaries. Sky cells must be opaque, remaining lower background truly transparent. Precise consistent palette and pixel size matching the provided reference.
