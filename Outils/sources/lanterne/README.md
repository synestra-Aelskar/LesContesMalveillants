# Lanterne suspendue

Sources produites avec l'outil ImageGen intégré, à partir des références
fournies par l'utilisateur le 23 octobre 2026. Alpha conservé.

- `corps.png` : lanterne vide, crochet ouvert vers le haut, logements de jauges.
- `cristal.png` : cristal vert indépendant, teinté et désaturé en jeu.
- `levier.png` : levier en laiton, orienté vers le haut ou le bas en jeu.

`Banc/.venv/Scripts/python.exe Outils/lanterne_blp.py` convertit ces sources en
`LesContesMalveillants/ressources/lanterne/{corps,cristal,levier}.blp` (BLP2/DXT5).
Le rapport d'aspect original est rétabli par les dimensions de l'interface.

`UI/LanterneCeinture.lua` contient les coordonnées normalisées, les jauges et
les zones interactives. Le point d'accrochage est à (87,2 %, 14 %) du corps.
Une reprise locale de l'anneau de la ceinture passe devant ce point.
`Outils/apercu_lanterne.py` rend trois contrôles de placement dans `Banc/apercus`.
Ce sont des rendus de contrôle, pas des captures du client WoW.

## Prompts envoyés à ImageGen

### Correction du crochet

Le corps mesure désormais 210 unités de large au lieu de 300 (−30 %).
La platine de l'interrupteur mesure 24 × 42, avec une zone de clic de 30 × 44.
`crochet.png` / `crochet.blp` est utilisé uniquement pour le quart supérieur
droit : le corps original conserve sa chambre sombre et ses logements.

Prompt intégré : « Precise edit of this transparent game asset. Keep the entire lantern body, empty chamber, bars, three empty bottom gauge windows, switch mounting plate, silhouette, scale, canvas, framing, and pixel positions unchanged. ONLY redesign the upper-right external attachment hook. It is currently an upward-open U and upside down for hanging. Replace it with a DOWNWARD-OPEN inverted U hook: solid rounded arch at TOP, opening and pointed free end toward BOTTOM, like a coat hook that hooks down through a belt ring. Keep the same black steel and brass spiderweb ornament, roughly the same bounding box x=77%-99%, y=1%-29%. Keep its left mounting connection connected to the lantern. Interior opening must be alpha-transparent. The inner ceiling of the new inverted U should be around x=89.5%, y=9% of canvas so a belt ring can support it there. No upward protruding spikes on top of the hook. Do not alter any part of the lantern below or left of this hook. Genuine transparent background, no labels or text. »

### Corps

Edit reference 1 into a production-ready isolated game UI lantern body on genuinely transparent background. Reference 2 is the belt-attachment hook design. Preserve the blackened steel, antique gold spiderweb ornament, emerald fantasy technology style. Remove the 'Image copiée' notification. Front-facing readable object, full silhouette with margins, portrait composition. IMPORTANT this is the EMPTY INACTIVE mechanical body layer: central glass chamber has NO crystal and NO green glow, empty dark interior, thin front cage bars. At bottom exactly three EMPTY DARK rectangular gauge recesses with crisp straight horizontal edges: one long upper gauge, two small lower gauges left and right. NO gauge ticks or numbers: code will draw those. Between the small gauges a small brass switch mounting plate, but NO switch lever: separate interactive layer will be added. Adapt large right-side belt hook so its mouth points upward and its attachment notch is near the top-right of the silhouette (about x=84%, y=18%), suitable to hang from a belt ring: body hangs BELOW and LEFT of that notch. Keep hook physically connected to lantern, substantial elegant brass/black metal hook, opening fully transparent. Remove giant top carry-handle if necessary to keep all body below attachment notch. This must be a clean cutout, no floor, no shadow outside silhouette, no background, no words, no UI labels. Output single empty lantern body only.

### Cristal

Reference is style only. Produce ONE isolated elongated emerald green faceted magical crystal, vertical narrow double pointed shard, matching the crystal inside this fantasy lantern. No lantern, no metal cage, no bracket, no gauge, no text. Bright translucent green crystal, restrained internal glow and fine luminous facets, pointed top and bottom, straight vertical silhouette. Entire object visible with generous transparent margin. Actual alpha transparency outside crystal, no black background and no external halo. Asset will be overlaid inside an empty lantern UI and desaturated at runtime for depleted state.

### Levier

Single tiny game UI asset: antique brass toggle switch LEVER ONLY, isolated on transparent background. Straight vertical short polished brass stem with a round spherical gold knob at its TOP and a small circular pivot at the BOTTOM. Front view, orthographic, dramatic subtle metallic shading matching dark gothic fantasy equipment. No mounting plate, no housing, no lantern, no background, no text, no cast shadow. A simple upright lever with bulb top, centered and entire object visible.
