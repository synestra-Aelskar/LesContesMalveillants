-- Le lanceur radial des ACTIONS.
--
-- Comme dans Necronicon (RadialLauncher.lua), il sert aux actions, pas aux
-- fenetres : ses categories sont les barres du template (Offensives,
-- Supports, Competences, Controles ; Animation pour le MJ). Les fenetres
-- passent par le menu (UI/Menu.lua). Chaque entree joue une resolution du
-- compendium (Core/Actions.lua) ; une entree sans resolution reste eteinte et
-- le dit.
--
-- Il est affiche en permanence. Clic gauche sur le sceau : la couronne des
-- categories se deploie. Clic sur une categorie : ses entrees s'ouvrent en
-- eventail. Clic droit sur le sceau : la selection du personnage.
--
-- La structure est FIGEE ici. Un module n'ajoute pas d'entree : il en habille
-- une qui existe deja, par Radial.Lier(id, fonction). `resolution` dit quelle
-- entree du compendium (Systeme-Resolution-Action, Actions-MJ) le bouton joue :
-- ce sont celles des barres d'action du profil Necronicon (quickMenu,
-- RunCompendiumEntryShortcut). UI/Composeur.lua fait la liaison. Un identifiant inconnu
-- est refuse — c'est ce qui evite les menus qui poussent tout seuls et les
-- ordres negocies au vol qu'on a subis dans Necronicon.
--
-- Un chouilla plus petit que celui de Necronicon : sceau de 58 au lieu de 64,
-- categories a 94 au lieu de 106, actions a 172 au lieu de 202.

local _, LCM = ...
local UI = LCM.UI

local Radial = {}
UI.Radial = Radial

local ART = "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\"
local SCEAU = ART .. "sceau.tga"
local SIGIL = ART .. "sigil.tga"
local ICONE = ART .. "icones\\"

Radial.SCEAU = 58
Radial.CATEGORIE = 40
Radial.ACTION = 52 -- actions lisibles ; 61 unites entre deux centres voisins
Radial.RAYON_CATEGORIE = 94
Radial.RAYON_ACTION = 172
Radial.FOND = 436
Radial.MAX_ENTREES = 8 -- au-dela, l'eventail n'a plus de dessin (fan-1..8)

-- ===== La structure, figee =================================================
-- Ajouter une entree ici est un acte de developpement, pas un reglage : les
-- identifiants sont ceux que citeront les liaisons, les raccourcis et la doc.

Radial.STRUCTURE = {
    {
        id = "offensives", label = "Offensives", icone = ICONE .. "offensives.tga",
        entrees = {
            { id = "attaque_simple",     label = "Attaque",              icone = ICONE .. "attaque_simple.tga",
              resolution = "attaque_composeur" },
            { id = "perce_armure",       label = "Perce-armure",         icone = ICONE .. "perce_armure.tga",
              resolution = "perce_armure_composeur" },
            { id = "brise_armure",       label = "Brise-armure",         icone = ICONE .. "brise_armure.tga",
              resolution = "brise_armure_composeur" },
            { id = "generation_debuff",  label = "Génération de débuff", icone = ICONE .. "generation_debuff.tga",
              resolution = "generation_de_debuff_composeur" },
        },
    },
    {
        id = "supports", label = "Supports", icone = ICONE .. "supports.tga",
        entrees = {
            { id = "generation_bouclier", label = "Génération de bouclier", icone = ICONE .. "generation_bouclier.tga",
              resolution = "generation_de_bouclier" },
            { id = "generation_soin",     label = "Génération de soin",     icone = ICONE .. "generation_soin.tga",
              resolution = "generation_de_soin" },
            { id = "generation_buff",     label = "Génération de buff",     icone = ICONE .. "generation_buff.tga",
              resolution = "generation_de_buff_composeur" },
            { id = "dissipation",         label = "Dissipation",            icone = ICONE .. "dissipation.tga",
              resolution = "dissipation" },
        },
    },
    -- La seule categorie dont le contenu n'est pas ecrit ici : ce sont les
    -- sorts du personnage joue, qui changent de personnage en personnage.
    -- Dans Necronicon, la barre « Compétences » portait la meme chose
    -- (RunGrimoireShortcutExec). Huit au plus : un eventail ne sait pas
    -- dessiner davantage de branches, et au-dela on ne choisit plus, on
    -- cherche.
    { id = "competences", label = "Compétences", icone = ICONE .. "competences.tga",
      contenu = function()
          local moi = LCM.Entities.Self()
          if not moi then return {} end
          local out = {}
          for _, sort in ipairs(LCM.Sorts.Liste(moi)) do
              out[#out + 1] = {
                  id = "sort_" .. tostring(sort.id), label = sort.label, icone = sort.icone,
                  onClick = function()
                      -- Un sort qui se lance se lance ; les autres se citent
                      -- dans le chat, ce qui est leur seule action utile.
                      if sort.jet then
                          local resultat, mini, maxi = LCM.Roll.Des(sort.jet.min, sort.jet.max)
                          LCM.Canal.Dire(string.format("%s : |cffffd36b%d|r  (%d-%d)",
                              tostring(sort.label), resultat, mini, maxi))
                      else
                          LCM.Lien.Inserer(LCM.Lien.Sort(moi, sort))
                      end
                  end,
              }
              if #out >= 8 then break end
          end
          return out
      end },
    {
        id = "controles", label = "Contrôles", icone = ICONE .. "controles.tga",
        entrees = {
            { id = "repulsion",      label = "Répulsion",      icone = ICONE .. "repulsion.tga",
              resolution = "repulsion" },
            { id = "attraction",     label = "Attraction",     icone = ICONE .. "attraction.tga",
              resolution = "attraction" },
            { id = "permutation",    label = "Permutation",    icone = ICONE .. "permutation.tga",
              resolution = "permutation" },
            { id = "immobilisation", label = "Immobilisation", icone = ICONE .. "immobilisation.tga",
              resolution = "immobilisation" },
            { id = "entrave",        label = "Entrave",        icone = ICONE .. "entrave.tga",
              resolution = "entrave" },
            { id = "levitation",     label = "Lévitation",     icone = ICONE .. "levitation.tga",
              resolution = "levitation" },
        },
    },
    -- Le second lanceur du template (« Action mj ») : une categorie reservee.
    {
        id = "animation", label = "Animation", icone = ICONE .. "animation.tga", mjSeulement = true,
        entrees = {
            -- « Résolution Test MJ » a quitté cette place le 2 octobre 2026.
            -- Elle etait fidele au template et ne servait a rien : elle se
            -- proposait l'epreuve a soi-meme, avec un paquet vide. Le vrai
            -- emetteur d'une epreuve de MJ, c'est « Dégât MJ ».
            { id = "degat_mj",           label = "Dégât MJ",           icone = ICONE .. "resolution_test_mj.tga",
              resolution = "degat_mj" },
            { id = "buff_debuff_mj",     label = "Buff / Débuff MJ",   icone = ICONE .. "buff_debuff_mj.tga",
              resolution = "buff_debuff_mj" },
            { id = "attaque_mj",         label = "Attaque MJ",         icone = ICONE .. "attaque_mj.tga",
              resolution = "attaque_mj" },
        },
    },
}

-- Verification au chargement : un eventail ne sait dessiner que 1 a 8 branches.
for _, categorie in ipairs(Radial.STRUCTURE) do
    local nombre = #(categorie.entrees or {})
    if nombre > Radial.MAX_ENTREES then
        error(string.format("radial : la categorie %s a %d entrees (maximum %d)",
            categorie.id, nombre, Radial.MAX_ENTREES))
    end
end

-- ===== Liaisons ============================================================

local function Trouver(id)
    id = tostring(id or "")
    for _, categorie in ipairs(Radial.STRUCTURE) do
        if categorie.id == id then return categorie end
        for _, entree in ipairs(categorie.entrees or {}) do
            if entree.id == id then return entree, categorie end
        end
    end
end
Radial.Trouver = Trouver

-- LCM.UI.Radial.Lier("fiche", function() ... end)
function Radial.Lier(id, onClick)
    local cible = Trouver(id)
    if not cible then
        LCM.Erreur(string.format("radial : entree inconnue « %s »", tostring(id)))
        return false
    end
    if type(onClick) ~= "function" then return false end
    cible.onClick = onClick
    return true
end

function Radial.EstLiee(id)
    local cible = Trouver(id)
    return cible ~= nil and type(cible.onClick) == "function"
end

-- Ce que le joueur a le droit de voir. Le MJ voit en plus ses outils.
function Radial.Categories()
    local out = {}
    for _, categorie in ipairs(Radial.STRUCTURE) do
        if (not categorie.mjSeulement) or LCM.IsMaster() then out[#out + 1] = categorie end
    end
    return out
end

function Radial.Entrees(categorieId)
    local categorie = Trouver(categorieId)
    local out = {}
    if not categorie then return out end
    -- Une categorie reservee au MJ ne laisse rien filtrer de son contenu.
    if categorie.mjSeulement and not LCM.IsMaster() then return out end
    -- Une categorie peut calculer son contenu (les sorts du personnage) plutot
    -- que le declarer. La structure du lanceur reste figee : c'est le contenu
    -- d'UNE case qui suit le personnage, pas le lanceur qui se reorganise.
    if type(categorie.contenu) == "function" then
        local ok, calcule = pcall(categorie.contenu)
        if not ok then
            LCM.Erreur(string.format("radial : « %s » : %s", tostring(categorie.label), tostring(calcule)))
            return out
        end
        -- Le plafond se tient ICI, pas dans chaque calcul : la verification au
        -- chargement ne voit que les entrees declarees, et un eventail de neuf
        -- branches n'existe pas.
        for i, entree in ipairs(calcule or {}) do
            if i > Radial.MAX_ENTREES then break end
            out[i] = entree
        end
        return out
    end
    for _, entree in ipairs(categorie.entrees or {}) do
        if (not entree.mjSeulement) or LCM.IsMaster() then out[#out + 1] = entree end
    end
    return out
end

-- ===== Animation ===========================================================
-- Un seul cadre d'animation pour tout le lanceur : aucun minuteur ne peut
-- terminer une fermeture devenue obsolete apres une reouverture rapide.

local transitions = {}
local animateur = CreateFrame("Frame")

local function Arreter(cible)
    transitions[cible] = nil
    if not next(transitions) then animateur:SetScript("OnUpdate", nil) end
end

local function Battement(_, ecoule)
    -- Les callbacks peuvent masquer des cadres ou annuler d'autres mouvements :
    -- on fige la liste avant de les appeler.
    local en_cours = {}
    for cible, mouvement in pairs(transitions) do
        en_cours[#en_cours + 1] = { cible, mouvement }
    end
    for _, entree in ipairs(en_cours) do
        local cible, mouvement = entree[1], entree[2]
        if transitions[cible] == mouvement then
            mouvement.temps = mouvement.temps + ecoule
            if mouvement.temps >= 0 then
                local t = math.min(1, mouvement.temps / mouvement.duree)
                mouvement.pas(1 - (1 - t) ^ 3)
                if t == 1 and transitions[cible] == mouvement then
                    transitions[cible] = nil
                    if mouvement.fin then mouvement.fin() end
                end
            end
        end
    end
    if not next(transitions) then animateur:SetScript("OnUpdate", nil) end
end

local function Mouvement(cible, duree, delai, pas, fin)
    Arreter(cible)
    transitions[cible] = { temps = -(delai or 0), duree = duree, pas = pas, fin = fin }
    pas(0)
    animateur:SetScript("OnUpdate", Battement)
end

-- Le bouton sort du centre en tournant : c'est ce mouvement-la qui fait le
-- caractere du menu de Necronicon, on le garde tel quel.
local TOURNIS = 0.95

local function Deployer(bouton, centre, x, y, departX, departY, delai)
    local dx, dy = x - departX, y - departY
    local rayon, angle = math.sqrt(dx * dx + dy * dy), math.atan2(dy, dx)
    Mouvement(bouton, 0.34, delai, function(t)
        local a = angle - (1 - t) * TOURNIS
        bouton:SetAlpha(t)
        bouton:ClearAllPoints()
        bouton:SetPoint("CENTER", centre, "CENTER",
            departX + math.cos(a) * rayon * t, departY + math.sin(a) * rayon * t)
    end)
end

local function Replier(bouton, centre, x, y, arriveeX, arriveeY, delai, fin)
    local dx, dy = x - arriveeX, y - arriveeY
    local rayon, angle = math.sqrt(dx * dx + dy * dy), math.atan2(dy, dx)
    Mouvement(bouton, 0.3, delai, function(t)
        local u = 1 - t
        local a = angle - (1 - u) * TOURNIS
        bouton:SetAlpha(u)
        bouton:ClearAllPoints()
        bouton:SetPoint("CENTER", centre, "CENTER",
            arriveeX + math.cos(a) * rayon * u, arriveeY + math.sin(a) * rayon * u)
    end, fin)
end

-- ===== Habillage ===========================================================

local function Surface(parent, nom, taille, couche)
    local t = parent:CreateTexture(nil, couche or "BACKGROUND")
    t:SetTexture(ART .. nom .. ".tga")
    t:SetPoint("CENTER", parent, "CENTER")
    t:SetSize(taille, taille)
    return t
end

-- Une ambiance permanente, independante des transitions d'ouverture.
-- Les textures sont creees une seule fois ; OnUpdate dort quand le sceau
-- (ou son parent) est masque. Aucun cadre supplementaire ne capte la souris.
local function ConstruireLivre(f)
    local livre = { ouverture = 0, temps = 0, images = {}, sceaux = {} }
    f.livre = livre
    -- Poses successives de la couverture puis d'une feuille autour du dos.
    -- Images prechargees, dimensions fixes : aucune deformation des pages.
    for i = 1, 7 do
        local pose = f.sceau:CreateTexture(nil, "ARTWORK", nil, 1)
        pose:SetTexture(ART .. (i == 7 and "grimoire-ouvert-v2.tga" or
            "grimoire-animation-" .. i .. ".tga"))
        pose:SetPoint("CENTER", f.sceau, "CENTER")
        pose:SetSize(76, 64)
        pose:SetAlpha(0)
        livre.images[i] = pose
    end
    -- Seul le sceau gauche scintille ; la rune droite est en encre noire.
    do
        local sceau = f.sceau:CreateTexture(nil, "ARTWORK", nil, 2)
        sceau:SetTexture(SIGIL)
        sceau:SetBlendMode("ADD")
        sceau:SetVertexColor(0.72, 0.24, 1)
        sceau:SetAlpha(0)
        livre.sceaux[1] = sceau
    end
    livre.etincelles = {}
    for i = 1, 3 do
        local point = f.sceau:CreateTexture(nil, "OVERLAY")
        point:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        point:SetBlendMode("ADD")
        point:SetVertexColor(0.85, 0.48, 1)
        point:SetSize(1.2, 1.2)
        point:SetAlpha(0)
        livre.etincelles[i] = point
    end
    f.sceau.icone:ClearAllPoints()
    f.sceau.icone:SetPoint("CENTER", f.sceau, "CENTER")
    f.sceau.icone:SetSize(Radial.SCEAU - 6, Radial.SCEAU - 6)
end

local function ActualiserLivre(f, ecoule)
    local livre = f.livre
    -- La cible suffit : un clic rapide inverse le mouvement en cours sans saut.
    local cible = f.ouvert and 1 or 0
    local pas = ecoule / 0.85
    if livre.ouverture < cible then
        livre.ouverture = math.min(cible, livre.ouverture + pas)
    elseif livre.ouverture > cible then
        livre.ouverture = math.max(cible, livre.ouverture - pas)
    end
    local t = livre.ouverture
    livre.temps = (livre.temps + ecoule) % (20 * math.pi)
    local temps = livre.temps
    local index = math.min(7, math.floor(t * 8))
    if index ~= livre.index then
        f.sceau.icone:SetAlpha(index == 0 and 0.9 or 0)
        for i, pose in ipairs(livre.images) do pose:SetAlpha(i == index and 1 or 0) end
        livre.index = index
    end
    local magie = math.max(0, (t - 0.9) / 0.1)
    for i, sceau in ipairs(livre.sceaux) do
        local pulse = 0.5 + 0.5 * math.sin(temps * 2 + (i - 1) * math.pi)
        sceau:SetPoint("CENTER", f.sceau, "CENTER", -15.2, -7)
        sceau:SetSize(12 + pulse, 12 + pulse)
        sceau:SetAlpha(magie * (0.3 + 0.3 * pulse))
    end
    for i, point in ipairs(livre.etincelles) do
        local a = i * 2.399963 + temps * 0.5
        point:SetPoint("CENTER", f.sceau, "CENTER",
            -15.2 + math.cos(a) * 5, -7 + math.sin(a) * 5)
        point:SetAlpha(magie * 0.8 * math.max(0, math.sin(temps * 3 + i * 2)) ^ 6)
    end
end

local nombreMagies = 0
local function HabillerMagie(b, taille)
    nombreMagies = nombreMagies + 1
    local magie = { phase = nombreMagies * 1.7, points = {} }
    b.magie = magie
    -- Les icones ont un fond opaque : une teinte additive tres faible colore
    -- surtout leurs noirs, sans masquer le dessin ni les details dores.
    magie.fond = b:CreateTexture(nil, "ARTWORK", nil, 1)
    magie.fond:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    magie.fond:SetPoint("CENTER", b, "CENTER")
    magie.fond:SetSize(taille - 6, taille - 6)
    magie.fond:SetVertexColor(0.34, 0.07, 0.52)
    magie.fond:SetBlendMode("ADD")
    magie.fond:SetAlpha(0.12)

    magie.runes = Surface(b, "sigil", taille * 1.13, "OVERLAY")
    magie.runes:SetVertexColor(0.85, 0.55, 1)
    magie.runes:SetBlendMode("ADD")
    magie.runes:SetAlpha(0.22)
    for i = 1, 3 do
        local point = b:CreateTexture(nil, "OVERLAY")
        point:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        point:SetBlendMode("ADD")
        point:SetVertexColor(1, 0.78, 0.48)
        point:SetSize(1.5, 1.5)
        local angle = (i - 1) * math.pi * 2 / 3 + magie.phase
        point:SetPoint("CENTER", b, "CENTER",
            math.cos(angle) * taille * 0.47, math.sin(angle) * taille * 0.47)
        point:SetAlpha(0)
        magie.points[i] = point
    end
end

local function ActualiserMagie(b, temps)
    local magie = b.magie
    if not magie or not b:IsShown() then return end
    local phase = temps + magie.phase
    local pulse = 0.5 + 0.5 * math.sin(phase)
    local intensite = b.disponible == false and 0.22 or (b.survole and 1.5 or (b.choisi and 1.25 or 1))
    magie.fond:SetAlpha((0.10 + 0.035 * pulse) * intensite)
    magie.runes:SetAlpha((0.16 + 0.10 * pulse) * intensite)
    -- Un tour en 48 secondes ; les points restent fixes sur le pourtour.
    magie.runes:SetRotation(temps * 0.1 + magie.phase)
    for i, point in ipairs(magie.points) do
        point:SetAlpha(math.max(0, math.sin(phase + i * 2)) ^ 10 * 0.65 * intensite)
    end
end

local function AnimerSceau(f)
    local tour = 2 * math.pi
    local angle = 0
    local tempsMagie = 0
    local particules = {}
    for i = 1, 14 do
        local texture = f.sceau:CreateTexture(nil, "OVERLAY")
        texture:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        texture:SetBlendMode("ADD")
        texture:SetVertexColor(0.72, 0.25, 1)
        local taille = 0.8 + (i % 4) * 0.3
        texture:SetSize(taille, taille)
        texture:SetAlpha(0)
        particules[i] = {
            texture = texture,
            phase = (i - 1) / 14,
            duree = 2.8 + (i % 5) * 0.43,
            angle = i * 2.399963,
            rayon = Radial.SCEAU * (0.60 + (i % 4) * 0.035),
        }
    end

    local function Actualiser(_, ecoule)
        ActualiserLivre(f, ecoule)
        tempsMagie = (tempsMagie + ecoule * (2 * math.pi / 4.8)) % (20 * math.pi)
        if f.orbite and f.orbite:IsShown() then
            for _, b in ipairs(f.boutonsCategorie) do ActualiserMagie(b, tempsMagie) end
            for _, b in ipairs(f.boutonsEntree) do ActualiserMagie(b, tempsMagie) end
        end
        -- SetRotation utilise les radians positifs dans le sens antihoraire.
        angle = (angle + ecoule * tour / 48) % tour
        f.sigil:SetRotation(angle)
        for _, p in ipairs(particules) do
            p.phase = (p.phase + ecoule / p.duree) % 1
            local vie = p.phase
            local a = p.angle + angle + vie * 0.48
            local rayon = p.rayon + vie * 7
            p.texture:SetPoint("CENTER", f.sceau, "CENTER",
                math.cos(a) * rayon, math.sin(a) * rayon + vie * 4)
            p.texture:SetAlpha(0.55 * math.sin(math.pi * vie) ^ 2)
        end
    end
    Actualiser(f.sceau, 0)
    f.sceau:SetScript("OnUpdate", Actualiser)
end

local function Rond(bouton, taille)
    -- Le masque arrondit l'icone carree ; sans lui, des vignettes carrees dans
    -- un menu circulaire, ca se voit tout de suite.
    if not bouton.CreateMaskTexture then return end
    local masque = bouton:CreateMaskTexture()
    masque:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    masque:SetAllPoints(bouton.icone)
    if bouton.icone.AddMaskTexture then bouton.icone:AddMaskTexture(masque) end
    bouton.masque = masque
end

local function Halo(bouton, taille)
    local halo = CreateFrame("Frame", nil, bouton)
    halo:SetAllPoints()
    halo:EnableMouse(false)
    Surface(halo, "glow", taille * 64 / 48, "OVERLAY")
    halo:SetAlpha(0)
    bouton.halo = halo
    bouton:HookScript("OnHide", function(self)
        Arreter(self.halo)
        self.halo:SetAlpha(0)
        self.survole = false
    end)
end

local function Eclairer(bouton, choisi, survole)
    bouton.choisi, bouton.survole = choisi, survole
    local vise = survole and 1 or (choisi and 0.78 or 0)
    local depuis = bouton.halo:GetAlpha()
    Mouvement(bouton.halo, 0.12, 0, function(t)
        bouton.halo:SetAlpha(depuis + (vise - depuis) * t)
    end)
    if bouton.legende then
        local couleur = (choisi or survole) and UI.C.titre or UI.C.discret
        bouton.legende:SetTextColor(couleur[1], couleur[2], couleur[3])
    end
end

local function Bulle(bouton, titre, detail)
    bouton:SetScript("OnEnter", function(self)
        Eclairer(self, self.choisi, true)
        if self.legende then self.legende:Show() end
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(titre, UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
        if detail then GameTooltip:AddLine(detail, 0.7, 0.68, 0.62, true) end
        GameTooltip:Show()
    end)
    bouton:SetScript("OnLeave", function(self)
        Eclairer(self, self.choisi, false)
        if self.legende and self.legendeAuSurvol then self.legende:Hide() end
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function Vignette(parent, taille, legendeAuSurvol, magique)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(taille, taille)
    Surface(b, "button", taille * 64 / 48)
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetPoint("TOPLEFT", 3, -3)
    b.icone:SetPoint("BOTTOMRIGHT", -3, 3)
    Rond(b, taille)
    if magique then HabillerMagie(b, taille) end
    b.legende = UI.Texte(b, "", UI.C.discret, "GameFontNormalSmall")
    b.legende:SetPoint("TOP", b, "BOTTOM", 0, -4)
    b.legende:SetJustifyH("CENTER")
    b.legendeAuSurvol = legendeAuSurvol and true or false
    if legendeAuSurvol then b.legende:Hide() end
    Halo(b, taille)
    return b
end

-- ===== Le lanceur ==========================================================

local function Fond(f, t)
    f.fond:SetAlpha(t)
    local phase, echelle = -(1 - t) * TOURNIS, 0.65 + 0.35 * t
    if f.fond.surface.SetSize then
        f.fond.surface:SetSize(Radial.FOND * echelle, Radial.FOND * echelle)
    end
    if f.fond.surface.SetRotation then f.fond.surface:SetRotation(phase) end
end

local function Eventail(f, angle, nombre, avancement)
    f.secteur.surface:SetTexture(ART .. "fan-" .. nombre .. ".tga")
    if f.secteur.surface.SetRotation then
        f.secteur.surface:SetRotation(angle - math.pi / 2)
    end
    local taille = Radial.FOND * (0.94 + 0.06 * (avancement or 1))
    f.secteur.surface:SetSize(taille, taille)
    f.secteur:Show()
end

local Dessiner

-- Replie les entrees vers leur categorie, puis appelle `apres`.
local function ReplierEntrees(f, apres)
    local une = false
    for i, b in ipairs(f.boutonsEntree) do
        if b:IsShown() then
            une = true
            Replier(b, f, b.rx, b.ry, f.choisiX or 0, f.choisiY or 0, (i - 1) * 0.012,
                function() b:Hide() end)
        end
    end
    if not une then if apres then apres() end return end
    f.replie = true
    Mouvement(f.secteur, 0.3, 0, function(t) f.secteur:SetAlpha(1 - t) end, function()
        f.replie = nil
        f.secteur:Hide()
        if apres then apres() end
    end)
end

local function Fermer(f, anime)
    Arreter(f.orbite) Arreter(f.fond) Arreter(f.secteur)
    for _, liste in ipairs({ f.boutonsCategorie, f.boutonsEntree }) do
        for _, b in ipairs(liste) do Arreter(b) end
    end
    local choisiX, choisiY = f.choisiX, f.choisiY
    f.ouvert, f.choisi, f.replie = false, nil, nil
    if not anime or not f.orbite:IsShown() then
        f.orbite:Hide()
        f.orbite:SetAlpha(1)
        Fond(f, 1)
        return
    end
    -- Les entrees rentrent dans leur categorie, les categories rentrent dans le
    -- sceau, le fond se replie en meme temps.
    local attente = 0
    for i, b in ipairs(f.boutonsEntree) do
        if b:IsShown() then
            Replier(b, f, b.rx, b.ry, choisiX or 0, choisiY or 0, (i - 1) * 0.012,
                function() b:Hide() end)
            attente = 0.12
        end
    end
    if f.secteur:IsShown() then
        Mouvement(f.secteur, 0.25, 0, function(t) f.secteur:SetAlpha(1 - t) end,
            function() f.secteur:Hide() end)
    end
    for i, b in ipairs(f.boutonsCategorie) do
        if b:IsShown() then
            Replier(b, f, b.rx, b.ry, 0, 0, attente + (i - 1) * 0.02)
        end
    end
    Mouvement(f.fond, 0.32, attente + 0.05, function(t) Fond(f, 1 - t) end)
    Mouvement(f.orbite, 0.42 + attente, 0, function() end, function()
        f.orbite:Hide()
        f.orbite:SetAlpha(1)
        Fond(f, 1)
    end)
end

local function Lancer(f, cible)
    if type(cible.onClick) == "function" then
        Fermer(f, true)
        local ok, err = pcall(cible.onClick)
        if not ok then LCM.Erreur(string.format("%s : %s", tostring(cible.label), tostring(err))) end
        return
    end
    LCM.Alerte(string.format("%s : pas encore disponible.", tostring(cible.label)))
end

Dessiner = function(f, animeCategories, animeEntrees)
    Arreter(f.orbite) Arreter(f.fond) Arreter(f.secteur)
    f.orbite:SetAlpha(1)
    for _, b in ipairs(f.boutonsCategorie) do Arreter(b) b:SetAlpha(1) b:Hide() end
    for _, b in ipairs(f.boutonsEntree) do Arreter(b) b:SetAlpha(1) b:Hide() end
    f.secteur:Hide()
    if not f.ouvert then f.orbite:Hide() return end
    f.orbite:Show()
    if animeCategories then
        Mouvement(f.fond, 0.4, 0, function(t) Fond(f, t) end)
    else
        Fond(f, 1)
    end

    local categories = Radial.Categories()
    local choisie, angleChoisi
    for i, categorie in ipairs(categories) do
        local b = f.boutonsCategorie[i]
        if not b then
            b = Vignette(f.orbite, Radial.CATEGORIE, false, true)
            f.boutonsCategorie[i] = b
        end
        -- Premiere categorie en haut, puis dans le sens horaire.
        local angle = math.pi / 2 - (i - 1) * 2 * math.pi / #categories
        b.rx, b.ry = math.cos(angle) * Radial.RAYON_CATEGORIE, math.sin(angle) * Radial.RAYON_CATEGORIE
        b.cible = categorie
        b:ClearAllPoints()
        b:SetPoint("CENTER", f, "CENTER", b.rx, b.ry)
        b.icone:SetTexture(categorie.icone)
        b.legende:SetText(categorie.label)
        b.choisi = (f.choisi == categorie.id)
        local teinte = b.choisi and 1 or 0.95
        b.icone:SetVertexColor(teinte, teinte, teinte)
        Bulle(b, categorie.label, categorie.direct and "Clic : ouvrir." or "Clic : deployer.")
        Eclairer(b, b.choisi, false)
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript("OnClick", function(bouton)
            local cat = bouton.cible
            if cat.direct or #Radial.Entrees(cat.id) == 0 then
                Lancer(f, cat)
                return
            end
            f.choisi = (f.choisi ~= cat.id) and cat.id or nil
            -- Un clic pendant le repli : le choix est memorise, le dessin qui
            -- suit la fin du repli l'utilisera.
            if f.replie then return end
            ReplierEntrees(f, function() if f.ouvert then Dessiner(f, false, true) end end)
        end)
        b:Show()
        if animeCategories then Deployer(b, f, b.rx, b.ry, 0, 0, (i - 1) * 0.025) end
        if f.choisi == categorie.id then choisie, angleChoisi = categorie, angle end
    end
    for i = #categories + 1, #f.boutonsCategorie do f.boutonsCategorie[i]:Hide() end
    f.nombreCategories = #categories

    if not choisie then
        f.choisiX, f.choisiY = nil, nil
        f.nombreEntrees = 0
        return
    end

    local entrees = Radial.Entrees(choisie.id)
    f.choisiX = math.cos(angleChoisi) * Radial.RAYON_CATEGORIE
    f.choisiY = math.sin(angleChoisi) * Radial.RAYON_CATEGORIE
    if animeEntrees then
        Mouvement(f.secteur, 0.4, 0, function(t)
            Eventail(f, angleChoisi - (1 - t) * TOURNIS, #entrees, t)
            f.secteur:SetAlpha(t)
        end)
    else
        Eventail(f, angleChoisi, #entrees)
        f.secteur:SetAlpha(1)
    end

    for i, entree in ipairs(entrees) do
        local b = f.boutonsEntree[i]
        if not b then
            b = Vignette(f.orbite, Radial.ACTION, true, true)
            f.boutonsEntree[i] = b
        end
        -- Sens horaire : la premiere entree a gauche, la derniere a droite,
        -- comme on lit (Fiche ... Apprentissage).
        local angle = angleChoisi - (i - (#entrees + 1) / 2) * math.pi / 8.75
        b.rx, b.ry = math.cos(angle) * Radial.RAYON_ACTION, math.sin(angle) * Radial.RAYON_ACTION
        b.cible = entree
        b:ClearAllPoints()
        b:SetPoint("CENTER", f, "CENTER", b.rx, b.ry)
        b:SetSize(Radial.ACTION, Radial.ACTION)
        b.icone:SetTexture(entree.icone)
        b.legende:SetText(entree.label)
        -- Une entree sans fenetre derriere elle reste visible mais eteinte : le
        -- menu ne ment pas sur ce qui existe.
        local prete = type(entree.onClick) == "function"
        b.disponible = prete
        local teinte = prete and 1 or 0.42
        b.icone:SetVertexColor(teinte, teinte, teinte)
        Bulle(b, entree.label, prete and "Clic : ouvrir." or "Pas encore disponible.")
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript("OnClick", function(bouton) Lancer(f, bouton.cible) end)
        b:Show()
        if animeEntrees then
            Deployer(b, f, b.rx, b.ry, f.choisiX, f.choisiY, (i - 1) * 0.018)
        end
    end
    for i = #entrees + 1, #f.boutonsEntree do f.boutonsEntree[i]:Hide() end
    f.nombreEntrees = #entrees
end

local function Construire()
    local f = CreateFrame("Frame", "LCM_Radial", UIParent)
    f:SetSize(Radial.SCEAU, Radial.SCEAU)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f.boutonsCategorie, f.boutonsEntree = {}, {}

    f.sceau = Vignette(f, Radial.SCEAU, false)
    f.sceau:SetAllPoints(f)
    f.sceau.icone:SetTexture(SCEAU)
    f.sceau.icone:SetAlpha(0.9)
    f.sceau.legende:Hide()
    f.sigil = f.sceau:CreateTexture(nil, "ARTWORK", nil, -1)
    f.sigil:SetTexture(SIGIL)
    f.sigil:SetPoint("CENTER", f.sceau, "CENTER")
    f.sigil:SetSize(Radial.SCEAU * 1.55, Radial.SCEAU * 1.55)
    f.sigil:SetAlpha(0.62)
    ConstruireLivre(f)
    AnimerSceau(f)

    f.orbite = CreateFrame("Frame", "LCM_RadialOrbite", f)
    f.orbite:SetAllPoints()
    f.orbite:Hide()
    f.sceau:SetFrameLevel(f.orbite:GetFrameLevel() + 3)

    f.fond = CreateFrame("Frame", nil, f.orbite)
    f.fond:SetAllPoints()
    f.fond:EnableMouse(false)
    f.fond.surface = Surface(f.fond, "background", Radial.FOND)

    f.secteur = CreateFrame("Frame", nil, f.orbite)
    f.secteur:SetAllPoints()
    f.secteur:EnableMouse(false)
    f.secteur.surface = Surface(f.secteur, "fan-1", Radial.FOND)
    f.secteur:Hide()
    Fond(f, 1)

    -- Echap referme la couronne.
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "LCM_RadialOrbite" end
    f.orbite:SetScript("OnHide", function()
        Arreter(f.orbite) Arreter(f.fond) Arreter(f.secteur)
        for _, liste in ipairs({ f.boutonsCategorie, f.boutonsEntree }) do
            for _, b in ipairs(liste) do Arreter(b) end
        end
        f.ouvert, f.choisi = false, nil
    end)

    -- Glisser (clic gauche, sans Maj depuis le 2 octobre 2026) deplace le
    -- sceau ; sa place est retenue.
    --
    -- Le jeu envoie quand meme OnClick au relache d'un glisser fini sur le
    -- sceau : sans garde, chaque deplacement ouvrait le menu. `f.glisse` dit
    -- « ce clic-la est la fin d'un glisser ». Il est remis a zero a CHAQUE
    -- appui, et pas seulement par le clic qu'il avale : un glisser relache
    -- hors du sceau ne recoit pas d'OnClick, et le drapeau reste pose — il
    -- mangerait alors le vrai clic suivant.
    f.sceau:RegisterForDrag("LeftButton")
    f.sceau:SetScript("OnMouseDown", function() f.glisse = false end)
    f.sceau:SetScript("OnDragStart", function()
        f.glisse = true
        f:StartMoving()
    end)
    f.sceau:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        LCM.EnsureDatabase()
        LCM.db.settings.radial = type(LCM.db.settings.radial) == "table" and LCM.db.settings.radial or {}
        local x, y = f:GetCenter()
        local cx, cy = UIParent:GetCenter()
        if x and cx then
            LCM.db.settings.radial.x, LCM.db.settings.radial.y = x - cx, y - cy
        end
    end)

    f.sceau:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f.sceau:SetScript("OnClick", function(_, souris)
        if f.glisse then
            f.glisse = false
            return
        end
        if souris == "RightButton" then
            Fermer(f, true)
            if UI.Personnages then UI.Personnages.Ouvrir() end
            return
        end
        if f.ouvert then Fermer(f, true) return end
        f.ouvert = true
        f.choisi = nil
        Dessiner(f, true, false)
    end)
    Bulle(f.sceau, "Les Contes Malveillants",
        "Clic : le menu\nClic droit : choisir un personnage\nGlisser : déplacer")

    Radial.frame = f
    return f
end

function Radial.Fenetre()
    if not Radial.frame then Construire() end
    return Radial.frame
end

-- Place le sceau : au centre-bas par defaut, ou la ou le joueur l'a laisse.
function Radial.Placer()
    local f = Radial.Fenetre()
    LCM.EnsureDatabase()
    local place = LCM.db.settings and LCM.db.settings.radial
    local x = type(place) == "table" and tonumber(place.x) or 0
    local y = type(place) == "table" and tonumber(place.y) or -160
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

function Radial.Basculer()
    local f = Radial.Fenetre()
    if f.ouvert then Fermer(f, true) return end
    f.ouvert = true
    f.choisi = nil
    Dessiner(f, true, false)
end

function Radial.Fermer() Fermer(Radial.Fenetre(), true) end

-- Montre ou cache le sceau lui-meme (il est affiche en permanence par defaut).
function Radial.Afficher(visible)
    local f = Radial.Fenetre()
    if visible == nil then visible = not f:IsShown() end
    if not visible then Fermer(f) end
    f:SetShown(visible and true or false)
    LCM.EnsureDatabase()
    LCM.db.settings.radialCache = (not visible) and true or nil
end

LCM.AddCommand("actions", "ouvre le lanceur d'actions", function() Radial.Basculer() end)
LCM.AddCommand("sceau", "montre ou cache le sceau des actions", function() Radial.Afficher() end)

LCM.WhenReady(function()
    Radial.Placer()
    local f = Radial.Fenetre()
    f:SetShown(not (LCM.db.settings and LCM.db.settings.radialCache))
end)

-- Nom lisible dans les raccourcis clavier de WoW.
_G.BINDING_HEADER_LESCONTESMALVEILLANTS = "Les Contes Malveillants"
_G.BINDING_NAME_LCM_MENU = "Ouvrir le menu des fenêtres"
_G.BINDING_NAME_LCM_FICHE = "Ouvrir la fiche"

function LCM_ToggleMenu() LCM.UI.Menu.Basculer() end
function LCM_ToggleFiche()
    local f = LCM.UI.Fiche.Fenetre()
    if f:IsShown() then f:Hide() else f:Montrer(LCM.Entities.Self()) end
end
