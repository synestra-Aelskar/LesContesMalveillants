# Icônes Système — 15 octobre 2026

Générées avec l’outil imagegen intégré. Référence de style :
`LesContesMalveillants/ressources/radial/icones/fenetres-objets.tga`.
Les PNG sont les sources ; les textures livrées sont des TGA RGBA 128 × 128,
sans compression, dans `LesContesMalveillants/ressources/radial/icones/`.
La conversion réduit seulement la taille et change le format.

## Lieux — fenetres-lieux.png / fenetres-lieux.tga

Create one square game UI icon for Lieux (places). Reference image is ONLY the exact style reference: richly engraved warm antique gold linework and brown shading on an almost black charcoal background, detailed fantasy RPG inventory icon, readable at 46px. Replace the backpack subject with a rolled parchment map bearing a simple compass rose and a location marker. One centered cohesive map symbol filling 80 percent of square. No text, no letters, no border, no circular frame, no blue red white or colored accents. Match the reference dark gold palette and strong silhouette. Save image as a project asset.

## Interactions — fenetres-interactions.png / fenetres-interactions.tga

Create one square game UI icon for Interactions. Input backpack is ONLY a visual style reference: detailed engraved antique warm gold linework, dark bronze shading, nearly black charcoal background, fantasy RPG icon legible at 46px. Subject: an upright open gloved hand with palm facing viewer, a small luminous golden four-point sparkle just above the palm, symbolizing interacting with world objects. Match reference material and craftsmanship. Single centered strong silhouette occupying 80 percent of square. No text, letters, border, circular frame or other colors. Fingers anatomically coherent, compact icon.


## Interactions — 16 octobre 2026

Outil imagegen intégré, référence : reference-objets.png. Sources : fenetres-{coffres,vendeurs,recoltes}.png. Textures livrées : mêmes noms en TGA RGBA 128 × 128 non compressé.

### coffres

Create one square fantasy RPG UI icon. Subject: a solid medieval treasure chest, three-quarter view, hinged lid slightly open with subtle golden light inside, prominent central keyhole, clearly a rigid wooden chest not a backpack. Match the provided reference ONLY for style: engraved warm antique gold edges, detailed dark brown bronze shading, nearly black charcoal background. Centered silhouette filling 80% of square, very readable at 40 pixels. No text, no letters, no border, no circle, no other colors. Single finished game asset.

### vendeurs

Create one square fantasy RPG UI icon. Subject: a medieval merchant balance scale above a small stack of gold coins, compact cohesive emblem, clear symmetrical silhouette. Match the provided reference ONLY for style: engraved warm antique gold edges, detailed dark brown bronze shading, nearly black charcoal background. Centered silhouette filling 80% of square, very readable at 40 pixels. No text, no letters, no border, no circle, no other colors. Single finished game asset.

### recoltes

Create one square fantasy RPG UI icon. Subject: a small curved harvesting sickle crossed behind a leafy herb sprig and a rough mineral crystal, compact cohesive emblem. Match the provided reference ONLY for style: engraved warm antique gold edges, detailed dark brown bronze shading, nearly black charcoal background. Centered silhouette filling 80% of square, very readable at 40 pixels. No text, no letters, no border, no circle, no other colors. Single finished game asset.


## Campement — 3 novembre 2026

Outil imagegen intégré. Source : `fenetres-campement.png` ; texture livrée :
`LesContesMalveillants/ressources/radial/icones/fenetres-campement.tga`,
RGBA 128 × 128 non compressé. Référence de style : `fenetres-coffres.png`.

Prompt :
Create one square fantasy RPG game UI icon for Campement. Subject: a medieval pitched canvas tent, three-quarter view, open triangular entrance, compact clear silhouette. Match the reference ONLY for style: engraved warm antique gold edges, detailed dark brown bronze shading, nearly black charcoal background. Tent centered occupying 80% of square, readable at 46 pixels. No fire, no text, letters, border, circle, landscape or colors outside gold bronze black. Save finished asset.

## Éventails concentriques — 3 novembre 2026

`python Outils/art/radial/construire_eventails.py` construit les neuf textures
`grimoire-subfan-1..9.tga` par projection géométrique du cuir existant.
Les deux niveaux gardent le même centre, la même épaisseur et 16 unités UI
entre leurs bords. Le pas angulaire du second niveau préserve la longueur
par entrée. Les constantes du générateur correspondent à `UI/Radial.lua`.
