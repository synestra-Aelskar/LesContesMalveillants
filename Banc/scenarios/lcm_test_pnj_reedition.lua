-- Clic droit sur l'engrenage d'un PNJ : sa CREATION se rouvre.
--
-- Le clic gauche ouvre sa fiche — ce qu'il EST. La fiche ne montre pas ce qui
-- a ete CHOISI (race, niveau, repartition des points), et aucun chemin n'y
-- ramenait : un PNJ mal dose se refaisait de zero (11 octobre 2026).
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = obtenu == voulu
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
local C = LCM.Creation

dire("== Un brouillon de creation fait du modele du compendium")
local pnj = LCM.PNJ.Get("assassin_du_culte")
attendu("le PNJ du compendium est la", pnj ~= nil, true)
local b = C.DepuisPNJ(pnj)
attendu("c'est bien une creation de PNJ", b.mode, "pnj")
attendu("et une REPRISE, pas un nouveau", b.pnj, "assassin_du_culte")
attendu("nom", b.nom, "Assassin du culte")
attendu("race", b.race, "aelskardien")
attendu("niveau", b.niveau, 12)
attendu("une primaire", b.valeurs.perception, 10)
attendu("une secondaire", b.valeurs.sec_pa, 2)
attendu("une mecanique", b.valeurs.meca_perce_armure, 8)
attendu("les traits", #b.traits, 3)
-- Ce que la creation ne depense pas n'a rien a faire dans ses valeurs : la
-- race et le niveau sont des champs a part, l'equipement ne la regarde pas.
attendu("la race n'est pas une ligne a depenser", b.valeurs.race, nil)
attendu("le niveau non plus", b.valeurs.niveau, nil)

dire("== Les metiers reviennent en rangs, pas en XP")
-- Le modele les range en XP (Core/Contenus.lua les convertit a la
-- construction) ; la creation, elle, les depense en rangs.
local metier = LCM.Metiers.list[1]
pnj.metiers = { [metier.id] = LCM.Metiers.XPPourNiveau(3) }
attendu("rang 3 et pas son cumul d'XP", C.DepuisPNJ(pnj).metiers[metier.id], 3)
pnj.metiers = nil

dire("== « Autre » se relit comme un « Autre »")
-- « Autre » se precise librement, et c'est CE TEXTE qui est enregistre.
pnj.valeurs.sexe = "Non binaire"
local sexue = C.DepuisPNJ(pnj)
attendu("le bouton Autre se rallume", sexue.valeurs.sexe, "Autre")
attendu("et la precision revient", sexue.sexeAutre, "Non binaire")
pnj.valeurs.sexe = nil

dire("== L'engrenage : a gauche la fiche, a droite la creation")
local f = LCM.UI.Compendium.Ouvrir("pnj")
attendu("la categorie PNJ est a l'ecran", f.actif, "pnj")
local r
for _, ligne in ipairs(f.rangees) do
    if ligne.element and ligne.element.id == "assassin_du_culte" then r = ligne end
end
attendu("la ligne du PNJ est la", r ~= nil, true)

local creation = LCM.UI.Creation.Fenetre()
creation:Hide()
r.reglages:Click("LeftButton")
attendu("clic gauche : sa fiche", LCM.UI.ConsultationMJ.fenetre:IsShown(), true)
attendu("  et pas la creation", creation:IsShown(), false)
LCM.UI.ConsultationMJ.fenetre:Hide()

r.reglages:Click("RightButton")
attendu("clic droit : sa creation", creation:IsShown(), true)
attendu("  elle annonce une reedition", creation.valider.label:GetText(), "Enregistrer le PNJ")
attendu("  elle vise CE PNJ", creation.brouillon.pnj, "assassin_du_culte")
attendu("  et elle est remplie", creation.brouillon.valeurs.perception, 10)

dire("== Enregistrer la reprise : meme identifiant, equipement intact")
-- Le PNJ du fichier a ete ecrit a la main : ses points ne respectent pas les
-- budgets actuels, et la creation le dit au lieu de l'avaler. On repart donc
-- d'une repartition propre pour verifier l'enregistrement.
local b2 = creation.brouillon
C.RemettreTout(b2)
for _, categorie in ipairs(C.CATEGORIES) do
    -- Les metiers d'un PNJ sont facultatifs (Creation.Problemes les exempte) :
    -- on les laisse ou ils sont.
    if categorie == "metiers" then -- rien
    elseif categorie == "traits" then
        while C.PeutEncoreDepenser(b2, "traits") do
            local pris = false
            for _, trait in ipairs(LCM.Traits.list) do
                if (trait.cout or 1) <= C.Budget(b2, "traits").reste and not C.ATrait(b2, trait.id) then
                    C.AjouterTrait(b2, trait.id) pris = true break
                end
            end
            if not pris then break end
        end
    else
        while C.PeutEncoreDepenser(b2, categorie) do
            local pose = false
            for _, ligne in ipairs(C.Lignes(categorie)) do
                local id = ligne.id or ligne
                if C.Maximum(b2, categorie, id) > C.Valeur(b2, id) then
                    C.Definir(b2, categorie, id, C.Maximum(b2, categorie, id))
                    pose = true break
                end
            end
            if not pose then break end
        end
    end
end
creation:Actualiser()
local restes = {}
for _, p in ipairs(C.Problemes(b2)) do restes[#restes + 1] = p end
attendu("rien ne bloque plus", #restes, 0)
for _, p in ipairs(restes) do dire("     " .. p) end

local equipementAvant = #(pnj.equipement.equipement or {})
attendu("le PNJ portait son equipement", equipementAvant > 0, true)
creation.valider:Click()

local repris = LCM.PNJ.Get("assassin_du_culte")
attendu("le PNJ n'a pas ete duplique", repris ~= nil, true)
-- 15 octobre 2026 : plus de marque « brouillon ». Le PNJ repris est le meme
-- PNJ, modifie ; la file d'envoi le porte jusqu'au /reload (verifie plus bas).
attendu("  aucune marque de brouillon", repris.brouillon, nil)
attendu("  son nom est conserve", repris.label, "Assassin du culte")
-- Le gros du geste : la creation ne connait ni equipement, ni etats, ni
-- apprentissages. Reprise sans report, elle deshabillait le PNJ.
attendu("  et son equipement a survecu", #(repris.equipement.equipement or {}), equipementAvant)
attendu("  la sauvegarde du compagnon aussi",
    LCM_MJ_DB.brouillons.pnj["assassin_du_culte"] ~= nil, true)
attendu("  avec l'equipement dedans",
    #((LCM_MJ_DB.brouillons.pnj["assassin_du_culte"].equipement or {}).equipement or {}), equipementAvant)
-- « remplace du publie » n'a plus de sens : modifier une entree la modifie.
attendu("  sans marque « remplace le publie »",
    LCM_MJ_DB.brouillons.pnj["assassin_du_culte"].remplacePublie, nil)
attendu("la fenetre de creation se referme", creation:IsShown(), false)

dire("== Le bouton clique voyage jusqu'a l'editeur")
-- Seule la branche PNJ lit ce mode ; les autres familles l'ignorent, mais il
-- doit leur parvenir, sinon le geste ne serait branche nulle part.
local g = LCM.UI.Compendium.Ouvrir("traits")
local rt
for _, ligne in ipairs(g.rangees) do if ligne.element then rt = rt or ligne end end
attendu("une ligne de traits", rt ~= nil, true)
local ouvert = { nil }
local vraiOuvrir = LCM.UI.Compendium.Editeur.Ouvrir
LCM.UI.Compendium.Editeur.Ouvrir = function(categorie, element, mode)
    ouvert[1] = (categorie and categorie.id or "?") .. ":" .. tostring(mode)
    return true
end
rt.reglages:Click("RightButton")
attendu("le mode est bien transmis", ouvert[1], "traits:creation")
LCM.UI.Compendium.Editeur.Ouvrir = vraiOuvrir

dire("== Les metiers d'un PNJ ne sont pas bornes a quatre")
-- Quatre, c'est la limite d'un JOUEUR, qui n'a que quatre points en tout. Un
-- PNJ en recoit quatre par niveau : le forgeron legendaire du village devait
-- pouvoir en etre un (11 octobre 2026).
local metierTest = LCM.Metiers.list[1]
local joueur = C.Nouveau(12)
local pnjNeuf = C.NouveauPNJ(12)
attendu("un joueur reste a 4", C.Plafond(joueur, "metiers", metierTest.id), 4)
attendu("un PNJ va jusqu'au bout du bareme",
    C.Plafond(pnjNeuf, "metiers", metierTest.id), LCM.Metiers.RangMax())
attendu("  soit les trente paliers", LCM.Metiers.RangMax(), 30)
-- Niveau 12 : 48 points de metier, de quoi depasser 4 sur un seul metier.
attendu("son budget le permet", C.Total(pnjNeuf, "metiers"), 48)
local pose = C.Definir(pnjNeuf, "metiers", metierTest.id, 12)
attendu("on pose un rang 12", pose, true)
attendu("  et il est retenu", pnjNeuf.metiers[metierTest.id], 12)
attendu("  un joueur, lui, est refuse des 5", C.Definir(joueur, "metiers", metierTest.id, 5), false)
-- Au-dela du dernier palier le rang n'existe pas : converti en XP il
-- retomberait a zero, donc perdu sans un mot.
attendu("au-dela du bareme, non",
    C.Definir(pnjNeuf, "metiers", metierTest.id, LCM.Metiers.RangMax() + 1), false)

dire("== Et le rang survit a l'aller-retour par le modele")
-- Le compendium range les metiers en XP ; c'est la que le rang se perdrait.
local xp = LCM.Metiers.XPPourNiveau(12)
attendu("le rang 12 a une XP", xp > 0, true)
attendu("  et on le relit rang 12", LCM.Metiers.Palier({ metiers = { [metierTest.id] = xp } }, metierTest.id).rang, 12)
attendu("le dernier rang aussi",
    LCM.Metiers.Palier({ metiers = { [metierTest.id] = LCM.Metiers.XPPourNiveau(LCM.Metiers.RangMax()) } },
        metierTest.id).rang, LCM.Metiers.RangMax())

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
