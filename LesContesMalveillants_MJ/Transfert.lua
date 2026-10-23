-- Transferer une entree d'une categorie a une autre (le MJ, 23 octobre 2026).
--
-- Le geste : dans le compendium, on glisse une entree sur le BOUTON d'une
-- autre categorie.
--   * un TYPE (une entree de « Liste ressources ») glisse sur une autre liste
--     (« Liste consommable ») : il change de liste, et les entrees de ce type
--     le suivent dans la categorie qui puise dans la nouvelle liste ;
--   * une entree typee (une ressource) glisse sur une categorie soeur
--     (Consommables) : elle passe seule.
--
-- Une entree garde son identifiant. Quand elle change de famille, elle note
-- l'ancienne reference (`transfertDe`), que le compendium sait encore
-- resoudre (Core/Compendium.lua) : ce qu'un sac, un coffre ou une recette
-- tenait ne disparait pas. C'est la raison d'etre du transfert — recreer a la
-- main laissait derriere soi tout ce qui citait l'ancienne entree.
--
-- Rien ne passe en douce. Quand la categorie d'arrivee n'a pas les memes
-- champs que celle de depart, que le jeu d'equilibrage de l'entree ne la vise
-- pas, ou que son type n'y existe pas, le panneau de l'entree s'ouvre
-- (l'editeur, ou la forge) pour que le MJ tranche. UN A LA FOIS : le suivant
-- n'ouvre qu'une fois le precedent ferme. Un panneau ferme sans enregistrer
-- laisse l'entree la ou elle etait, et on le dit.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local C = LCM.Compendium
local Brouillons = MJ.Brouillons
local UI = LCM.UI

local Transfert = {}
MJ.Transfert = Transfert
LCM.Transfert = Transfert

local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- ===== Ce qui se transfere ===================================================

-- La liste ou puise le Type d'une categorie, s'il en a un.
local function ListeDe(categorie)
    if not categorie then return nil end
    for _, champ in ipairs(C.Champs(categorie) or {}) do
        if champ.cle == "type" then
            local liste = tostring(champ.source or ""):match("^listes:(.+)$")
            if liste then return liste end
        end
    end
    return nil
end
Transfert.ListeDe = ListeDe

local function Modifiable(categorie)
    return categorie ~= nil and categorie.famille ~= nil and C.Editable(categorie)
        and not categorie.lectureSeule and Brouillons.Registre(categorie.famille) ~= nil
end

local function EstListe(categorie)
    return Modifiable(categorie) and categorie.famille == "listes" and categorie.type == "list"
end

local function EstTypee(categorie)
    return Modifiable(categorie) and categorie.famille ~= "listes" and ListeDe(categorie) ~= nil
end

-- La categorie qui puise dans `listeId`. S'il y en a plusieurs, celle de la
-- famille d'ou l'on vient : on ne change de famille que s'il le faut.
local function CategoriePour(listeId, familleVoulue)
    local trouvee
    for _, categorie in ipairs(C.categories) do
        if EstTypee(categorie) and ListeDe(categorie) == listeId then
            if categorie.famille == familleVoulue then return categorie end
            trouvee = trouvee or categorie
        end
    end
    return trouvee
end

-- Ce que montre une categorie : ses champs, sans le Type et la Forge, qui
-- puisent chacun dans les choix de LEUR categorie (ce sont eux qui changent
-- a coup sur). Deux categories de meme signature se remplissent pareil.
local function Signature(categorie)
    local out = {}
    for _, champ in ipairs(C.Champs(categorie) or {}) do
        if champ.cle ~= "type" and champ.cle ~= "forge" then
            out[#out + 1] = tostring(champ.cle) .. ":" .. tostring(champ.type)
        end
    end
    table.sort(out)
    return table.concat(out, ",") .. "|" .. tostring(categorie.statistiques)
end

-- L'element enregistre, remis en definition : ce que l'editeur fait de meme
-- quand il ouvre une entree (MJ/Compendium.lua, Travail).
local function Definition(element)
    local def = LCM.Copie(element)
    if type(def.avantage) == "table" and def.avantage[1] == nil then
        local liste = {}
        for id in pairs(def.avantage) do liste[#liste + 1] = id end
        table.sort(liste)
        def.avantage = liste[1] and liste or nil
    end
    if def.icone == LCM.Icone(nil) then def.icone = nil end
    return def
end

local function DansLaListe(listeId, typeId)
    for _, entree in ipairs(LCM.Listes.De(listeId)) do
        if entree.id == typeId then return true end
    end
    return false
end

-- Une etape : une entree, d'ou elle part, ou elle va, et ce qui demande la
-- main du MJ (`raisons`). `typeQuiSuit` : le type qui change de liste dans le
-- meme geste — il sera dans la liste d'arrivee quand l'entree y passera.
local function Etape(element, depart, arrivee, typeQuiSuit)
    local def = Definition(element)
    -- Le defaut d'arrivee designe la categorie (la liste d'une entree de
    -- liste, la categorie d'un objet) : il remplace celui de depart.
    for cle, valeur in pairs(arrivee.defaut or {}) do def[cle] = LCM.Copie(valeur) end
    local change = depart.famille ~= arrivee.famille
    if change then
        local ancienne = depart.famille .. "/" .. tostring(element.id)
        -- Une entree qui revient dans une famille quittee ne s'y cite pas
        -- elle-meme : son ancienne reference redevient la vraie.
        local actuelle = arrivee.famille .. "/" .. tostring(element.id)
        local refs = {}
        for _, ref in ipairs(type(def.transfertDe) == "table" and def.transfertDe or {}) do
            if ref ~= ancienne and ref ~= actuelle then refs[#refs + 1] = ref end
        end
        refs[#refs + 1] = ancienne
        def.transfertDe = refs
    end

    local raisons = {}
    if Signature(depart) ~= Signature(arrivee) then
        raisons[#raisons + 1] = string.format("%s et %s n'ont pas les mêmes champs", depart.label, arrivee.label)
    end
    local liste = ListeDe(arrivee)
    if liste and def.type and def.type ~= typeQuiSuit and not DansLaListe(liste, def.type) then
        raisons[#raisons + 1] = string.format("son type n'existe pas dans %s", arrivee.label)
    end
    local jeux = LCM.Forge.PourCategorie(arrivee.id)
    if #jeux > 0 then
        local jeu = LCM.Forge.Lire(def.forge)
        if not jeu then
            raisons[#raisons + 1] = string.format("il lui faut un jeu d'équilibrage de %s", arrivee.label)
        elseif jeu.categorie ~= arrivee.id then
            raisons[#raisons + 1] = string.format("son jeu « %s » n'équilibre pas %s", jeu.label, arrivee.label)
        end
    end
    -- Ce que le registre d'arrivee en penserait. Un refus qui ne tient pas au
    -- type ni a la forge (deja dits) se dit aussi : il faudra le corriger.
    if #raisons == 0 then
        local registre = Brouillons.Registre(arrivee.famille)
        local ok, neuf = pcall(registre.Construire, def)
        if not ok then
            raisons[#raisons + 1] = (tostring(neuf):gsub("^LCM/%a+ : ", ""))
        else
            local dansLeBareme, horsBareme = LCM.Forge.Verifier(arrivee.famille, neuf)
            if not dansLeBareme then raisons[#raisons + 1] = horsBareme end
        end
    end
    return { def = def, element = element, depart = depart, arrivee = arrivee,
             change = change, raisons = raisons }
end

-- Le panneau d'une categorie : la forge pour ce qu'elle dose, l'editeur sinon.
local function ParLaForge(categorie)
    return UI.Forge ~= nil and UI.Forge.EstCategorie(categorie)
end

-- ===== Le plan ===============================================================

local enCours

function Transfert.EnCours() return enCours ~= nil end

-- Ce que le glisser-deposer survole : peut-on lacher ICI ? Rapide, sans
-- rien preparer — c'est appele a chaque image du glissement.
function Transfert.Accepte(objet, cible)
    if not LCM.IsMaster() then return false, "le transfert est réservé au MJ." end
    if type(objet) ~= "table" or not objet.categorie or type(objet.element) ~= "table" then
        return false, nil
    end
    if enCours then return false, "un transfert est déjà en cours." end
    local depart = C.Get(objet.categorie)
    if not cible or not depart then return false, nil end
    if cible.id == depart.id then return false, "c'est déjà sa catégorie." end
    if EstListe(depart) then
        if not EstListe(cible) then return false, "un type se glisse sur une autre liste." end
        return true
    end
    if EstTypee(depart) then
        if not EstTypee(cible) then
            return false, "une entrée se glisse sur une catégorie qui a des types (Ressources, Consommables, Armes…)."
        end
        return true
    end
    return false, "cette catégorie ne se transfère pas."
end

-- Tout ce que le geste fera, sans rien en faire : { etapes, question }, ou
-- nil et la raison du refus. Un refus ici ne laisse rien a moitie fait.
function Transfert.Plan(objet, cible)
    local ok, raison = Transfert.Accepte(objet, cible)
    if not ok then return nil, raison or "ne va pas ici." end
    local depart = C.Get(objet.categorie)
    local element = objet.element
    local etapes = {}

    if EstListe(depart) then
        etapes[1] = Etape(element, depart, cible)
        -- Les entrees qui portent ce type, dans toutes les categories qui
        -- puisent dans la liste quittee.
        local listeDepart = depart.defaut and depart.defaut.liste
        local listeArrivee = cible.defaut and cible.defaut.liste
        for _, source in ipairs(C.categories) do
            if EstTypee(source) and ListeDe(source) == listeDepart then
                local suivantes = {}
                for _, e in ipairs(C.Entrees(source)) do
                    if e.type == element.id then suivantes[#suivantes + 1] = e end
                end
                if suivantes[1] then
                    local arrivee = CategoriePour(listeArrivee, source.famille)
                    if not arrivee then
                        return nil, string.format("aucune catégorie ne puise dans %s : les %d entrée(s) de %s "
                            .. "de ce type n'auraient nulle part où aller.", cible.label, #suivantes, source.label)
                    end
                    for _, e in ipairs(suivantes) do
                        etapes[#etapes + 1] = Etape(e, source, arrivee, element.id)
                    end
                end
            end
        end
    else
        etapes[1] = Etape(element, depart, cible)
    end

    -- Un panneau qu'on ne pourrait pas valider : la forge sans jeu ne sait
    -- rien enregistrer. On le dit AVANT de commencer.
    for _, etape in ipairs(etapes) do
        if etape.raisons[1] and ParLaForge(etape.arrivee)
            and #LCM.Forge.PourCategorie(etape.arrivee.id) == 0 then
            return nil, string.format("« %s » demande une modification (%s), mais aucun jeu d'équilibrage ne vise "
                .. "%s : crée-en un avant le transfert.", tostring(etape.element.label),
                etape.raisons[1], etape.arrivee.label)
        end
    end

    local suivent, aModifier = #etapes - 1, 0
    for _, etape in ipairs(etapes) do if etape.raisons[1] then aModifier = aModifier + 1 end end
    local lignes = { string.format("Transférer « %s » de %s vers %s ?", tostring(element.label),
        depart.label, cible.label) }
    if suivent > 0 then
        lignes[#lignes + 1] = string.format("%d entrée(s) de ce type suivent dans %s.", suivent,
            etapes[2].arrivee.label)
    end
    if aModifier > 0 then
        lignes[#lignes + 1] = string.format("%d demande(nt) une modification : leurs panneaux s'ouvriront "
            .. "l'un après l'autre.", aModifier)
    else
        lignes[#lignes + 1] = "Rien à modifier : tout passe tel quel."
    end
    return { etapes = etapes, question = table.concat(lignes, "\n"), cible = cible }
end

-- ===== L'execution ===========================================================

-- Remplace, partout dans `t`, la chaine `ancienne` par `nouvelle` — valeurs
-- ET cles (une regle de stock se range sous sa reference). Rend vrai si
-- quelque chose a change.
local function Substituer(t, ancienne, nouvelle)
    local change = false
    local cles = {}
    for cle in pairs(t) do cles[#cles + 1] = cle end
    for _, cle in ipairs(cles) do
        local valeur = t[cle]
        if valeur == ancienne then
            t[cle], change = nouvelle, true
        elseif type(valeur) == "table" and Substituer(valeur, ancienne, nouvelle) then
            change = true
        end
        if cle == ancienne then
            t[nouvelle], t[cle], change = t[cle], nil, true
        end
    end
    return change
end

-- Ce qui contient l'entree la suit (le MJ, 23 octobre 2026) : les modeles de
-- coffres, de vendeurs et de filons qui la citaient sous son ancienne
-- reference sont reecrits. L'ancienne se resout encore (`transfertDe`), mais
-- au chargement un coffre se lit avant que la file d'envoi ne rejoue
-- l'entree transferee : ses lignes tombaient de cote. Les points POSES
-- (MJ/Poses.lua) gardent l'ancienne, que la resolution suit : leur contenu
-- vit dans le magasin de chaque module, qu'on ne reecrit pas d'ici.
local function Reecrire(ancienne, nouvelle)
    local n = 0
    for _, point in ipairs(LCM.Points and LCM.Points.list or {}) do
        local copie = LCM.Copie(point)
        if Substituer(copie, ancienne, nouvelle) then
            local ok, raison = Brouillons.Enregistrer("points", copie, false)
            if ok then
                n = n + 1
            else
                LCM.Alerte(string.format("« %s » cite encore %s : %s", tostring(point.label or point.id),
                    ancienne, tostring(raison)))
            end
        end
    end
    return n
end
Transfert.Reecrire = Reecrire

-- Une entree passee : ecrite a l'arrivee, retiree du depart si elle a change
-- de famille (dans la meme famille, c'est la meme entree, modifiee).
local function Achever(etape)
    if etape.change then
        enCours.points = enCours.points + Reecrire(etape.depart.famille .. "/" .. tostring(etape.def.id),
            etape.arrivee.famille .. "/" .. tostring(etape.def.id))
        local ok, raison = Brouillons.Supprimer(etape.depart.famille, etape.def.id)
        if not ok then
            LCM.Alerte(string.format("« %s » est passée dans %s mais reste aussi dans %s : %s",
                tostring(etape.def.label), etape.arrivee.label, etape.depart.label, tostring(raison)))
        end
    end
    etape.fait = true
    enCours.passees = enCours.passees + 1
end

local function Ecrire(etape)
    local ok, refus = Brouillons.Enregistrer(etape.arrivee.famille, etape.def, etape.change)
    if not ok then return false, refus end
    Achever(etape)
    return true
end

-- Le prochain pas, une image plus tard : on ne rouvre pas un panneau dans le
-- OnHide de celui qui se ferme (le meme cadre, parfois).
local horloge = CreateFrame("Frame")
horloge:Hide()
horloge:SetScript("OnUpdate", function(self)
    self:Hide()
    if not self.attente then return end
    self.attente = nil
    Transfert.Suivant()
end)
local function PlusTard()
    horloge.attente = true
    horloge:Show()
end

local function Terminer()
    local bilan = enCours
    enCours = nil
    local message = string.format("transfert vers %s : %d entrée(s) passée(s)", bilan.cible.label, bilan.passees)
    if bilan.points > 0 then
        message = message .. string.format(", %d coffre(s), vendeur(s) ou filon(s) mis à jour", bilan.points)
    end
    if bilan.laissees[1] then
        message = message .. string.format(", %d laissée(s) à leur place (%s)", #bilan.laissees,
            table.concat(bilan.laissees, ", "))
        LCM.Alerte(message .. ".")
    else
        LCM.Ok(message .. ".")
    end
    if UI.Compendium and UI.Compendium.Actualiser then UI.Compendium.Actualiser() end
    return message
end

-- Le panneau courant se ferme. Enregistre : l'entree est deja passee.
-- Ferme sans enregistrer : elle reste ou elle etait.
local function Ferme(cadre)
    local etape = enCours and enCours.etapes[enCours.index]
    if not (etape and etape.ouvert and etape.cadre == cadre) then return end
    etape.ouvert = nil
    if not etape.fait then
        enCours.laissees[#enCours.laissees + 1] = tostring(etape.def.label)
        LCM.Alerte(string.format("« %s » n'a pas été transférée : elle reste dans %s.",
            tostring(etape.def.label), etape.depart.label))
    end
    enCours.index = enCours.index + 1
    PlusTard()
end

local suivis = {}
local function Suivre(cadre)
    if cadre and not suivis[cadre] then
        suivis[cadre] = true
        cadre:HookScript("OnHide", function(self) Ferme(self) end)
    end
end

local function Ouvrir(etape)
    if #etape.raisons > 0 then
        LCM.Alerte(string.format("« %s » : %s. Corrige-la puis enregistre.", tostring(etape.def.label),
            table.concat(etape.raisons, " ; ")))
    end
    local ok = LCM.CompendiumEditeur.Ouvrir(etape.arrivee, etape.def)
    local cadre = ParLaForge(etape.arrivee) and UI.Forge.Fenetre() or LCM.CompendiumEditeur.frame
    if ok == false or not (cadre and cadre:IsShown()) then return false end
    Suivre(cadre)
    etape.cadre, etape.ouvert = cadre, true
    return true
end

-- Avance jusqu'au prochain panneau a ouvrir, ou jusqu'a la fin.
function Transfert.Suivant()
    if not enCours then return end
    while enCours.index <= #enCours.etapes do
        local etape = enCours.etapes[enCours.index]
        if not etape.raisons[1] then
            local ok, refus = Ecrire(etape)
            if ok then
                enCours.index = enCours.index + 1
            else
                -- Prevu sans retouche, refuse quand meme : on montre le panneau.
                etape.raisons[1] = tostring(refus)
            end
        else
            if Ouvrir(etape) then return end
            enCours.laissees[#enCours.laissees + 1] = tostring(etape.def.label)
            LCM.Alerte(string.format("« %s » : son panneau ne s'ouvre pas, elle reste dans %s.",
                tostring(etape.def.label), etape.depart.label))
            enCours.index = enCours.index + 1
        end
    end
    return Terminer()
end

-- Lance un plan accepte par le MJ. Renvoie le message a afficher.
function Transfert.Lancer(plan)
    if enCours then return false, "un transfert est déjà en cours." end
    if type(plan) ~= "table" or not plan.etapes then return false, "rien à transférer." end
    enCours = { etapes = plan.etapes, index = 1, passees = 0, laissees = {}, cible = plan.cible, points = 0 }
    local fin = Transfert.Suivant()
    if fin then return true, fin end
    local reste = 0
    for i = enCours.index, #enCours.etapes do
        if enCours.etapes[i].raisons[1] then reste = reste + 1 end
    end
    return true, string.format("Transfert en cours : %d panneau(x) à valider.", reste)
end

-- La validation d'un panneau ouvert par le transfert, quel qu'il soit
-- (editeur ou forge) : l'entree est passee. La forge, qui reste ouverte
-- apres une modification, se referme pour laisser venir la suivante.
Brouillons.SurEnregistrement(function(famille, id)
    local etape = enCours and enCours.etapes[enCours.index]
    if not (etape and etape.ouvert and not etape.fait) then return end
    if famille ~= etape.arrivee.famille or id ~= tostring(etape.def.id) then return end
    Achever(etape)
    if ParLaForge(etape.arrivee) and etape.cadre:IsShown() then etape.cadre:Hide() end
end)
