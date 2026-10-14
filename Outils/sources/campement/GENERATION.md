# Campement : sources et conversion

Images creees avec l'outil integre image_gen, fond transparent. Sources :
`atlas.png` et `feu.png`. Les fichiers `apercu-nuit.png` et `apercu-jour.png`
sont des compositions de controle faites a partir des BLP relus, pas des captures du jeu.

Conversion reproductible :

```
Banc/.venv/Scripts/python.exe Outils/campement_blp.py Outils/sources/campement/atlas.png Outils/sources/campement/feu.png
```

Sortie : `LesContesMalveillants/ressources/campement/`, BLP2 DXT5 avec alpha,
dimensions en puissances de deux. Les images generees sont decoupees et
redimensionnees au plus proche ; les PNG sources restent intacts.

## Prompt atlas

Create a production game asset atlas on a truly TRANSPARENT background. Beautiful handcrafted 16-bit pixel art for a fantasy woodland camping night animation. A single square 2x2 sprite atlas with FOUR strictly separate equal quadrants and generous transparent gutters; no sprite crosses quadrant boundaries. TOP LEFT: wide panoramic layer of atmospheric pine forest silhouettes, varied detailed evergreen trees, blue teal foliage, uneven treetop edge, no sky and no ground, transparent between trees. TOP RIGHT: wide grassy forest clearing ground platform, moss, rocks, tiny ferns, low profile, no trees no tent. BOTTOM LEFT: one attractive ochre canvas medieval camping tent in three-quarter front view, warm doorway, ropes and pegs, isolated with transparent surround. BOTTOM RIGHT: three isolated small sprites spaced widely horizontally: luminous ivory moon, golden sun, small bright campfire with logs. Crisp intentional pixel clusters, rich restrained palette, polished indie pixel RPG scenery, no blur, no text, no letters, no border, no checkerboard painted in. Assets must be separated so we can use texture coordinates for each quadrant and animate independently. All areas outside actual artwork must have alpha zero. Forest and ground should fill their quadrant horizontally while remaining inside it. Tent should fit entirely within its quadrant.

## Prompt feu anime

Production sprite sheet for a fantasy pixel-art game: FOUR animation frames of the SAME small campfire crackling on identical crossed wooden logs. Single wide horizontal row of 4 equal square cells, transparent background, no labels, no borders, no text. Flame changes silhouette and curls between frames; log base exactly same size position perspective in all cells. Rich orange amber flames with pale yellow center, tiny sparks above. Detailed hand-crafted 16-bit pixel-art style, crisp pixels, front three-quarter view, suitable layered in front of a fantasy canvas tent in pine forest. Each campfire completely isolated inside its cell with 15 percent transparent margin, no artwork crosses cells. True alpha transparency, no painted checkerboard. Four different coherent consecutive animation frames, not four different fires.
