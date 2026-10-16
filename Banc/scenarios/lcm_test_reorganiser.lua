-- Reorganiser ses sacs (16 octobre 2026) : glisser un emplacement sur un autre.
-- Libre, le sac s'y deplace ; occupe, les deux echangent leur place, chacun avec
-- son contenu. Un sac plein ne peut que changer d'emplacement : aucune autre
-- cible ne l'accepte, sinon il serait pose ailleurs sans quitter sa place.
--
-- Et chacun sa place (le MJ, le meme jour) : un SAC dans Sacs, une SACOCHE
-- dans Saccoches, une ceinture sur la Ceinture. Ni la pose, ni le deplacement,
-- ni l'echange ne mettent l'un a la place de l'autre.
--
-- Contenu TEMOIN : deux sacs, deux sacoches et une ressource.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

LCM.Brouillons.Set("sacs", { id = "sac_petit", label = "Petit sac", nature = "sac", places = 4 })
LCM.Brouillons.Set("sacs", { id = "sac_grand", label = "Grand sac", nature = "sac", places = 12 })
LCM.Brouillons.Set("sacs", { id = "sacoche_a", label = "Sacoche A", nature = "sacoche", places = 3 })
LCM.Brouillons.Set("sacs", { id = "sacoche_b", label = "Sacoche B", nature = "sacoche", places = 5 })
LCM.Brouillons.Set("ressources", { id = "pierre_temoin", label = "Pierre" })
LCM.Brouillons.Set("ressources", { id = "plume_temoin", label = "Plume", pileMax = 5 })

__declencher("PLAYER_LOGIN")
__personnage()
local moi = LCM.Entities.Self()
local Inv = LCM.Inventaire
local PIERRE = "ressources/pierre_temoin"
local function Sac(onglet, index)
    local c = Inv.Contenant(Inv.Emplacement(moi, onglet, index))
    return c and c.id or "vide"
end

dire("== chacun sa place, a la pose")
attendu("un sac dans Sacs", Inv.Poser(moi, "sacs", 1, "sac_petit"), true)
local ok, raison = Inv.Poser(moi, "saccoches", 1, "sac_grand")
attendu("un sac dans Saccoches : refus", ok, false)
attendu("  dit pourquoi", raison, "un sac se porte dans un emplacement Sacs.")
ok, raison = Inv.Poser(moi, "sacs", 2, "sacoche_a")
attendu("une sacoche dans Sacs : refus", ok, false)
attendu("  dit pourquoi", raison, "une sacoche se porte dans un emplacement Saccoches.")
attendu("une sacoche dans Saccoches", Inv.Poser(moi, "saccoches", 1, "sacoche_a"), true)
Inv.Poser(moi, "sacs", 2, "sac_grand")
Inv.Poser(moi, "saccoches", 2, "sacoche_b")
Inv.Ranger(moi, "sacs", 1, 1, PIERRE, 3)

dire("== le coeur : deplacer, echanger, et rien a la mauvaise place")
attendu("une sacoche vers une saccoche libre", Inv.Deplacer(moi, "saccoches", 2, "saccoches", 3), true)
attendu("  elle y est", Sac("saccoches", 3), "sacoche_b")
attendu("deux sacs echangent leur place", Inv.Deplacer(moi, "sacs", 1, "sacs", 2), true)
attendu("  le petit est passe", Sac("sacs", 2), "sac_petit")
attendu("  le grand a pris sa place", Sac("sacs", 1), "sac_grand")
attendu("  le petit garde son contenu", Inv.Case(Inv.Emplacement(moi, "sacs", 2), 1).ref, PIERRE)
attendu("  et sa quantite", Inv.Case(Inv.Emplacement(moi, "sacs", 2), 1).quantite, 3)
ok, raison = Inv.Deplacer(moi, "sacs", 1, "saccoches", 2)
attendu("un sac vers une saccoche libre : refus", ok, false)
ok, raison = Inv.Deplacer(moi, "sacs", 1, "saccoches", 1)
attendu("un echange sac / sacoche : refus", ok, false)
attendu("  rien n'a bouge", Sac("sacs", 1) .. "/" .. Sac("saccoches", 1), "sac_grand/sacoche_a")
_, raison = Inv.Deplacer(moi, "sacs", 1, "sacs", 1)
attendu("sur sa propre place : rien", raison, "c'est déjà là.")

dire("== a la souris : glisser une carte sur une autre")
LCM.UI.Inventaires.Basculer()
local f = LCM.UI.Inventaires.frame
LCM.UI.Inventaires.Actualiser()
local function Carte(onglet, index)
    for _, c in ipairs(f.cartes or {}) do
        if c:IsShown() and c.onglet == onglet and c.index == index then return c end
    end
end
local function Prendre(carte)
    local glisse
    local commencer = LCM.UI.Glisser.Commencer
    LCM.UI.Glisser.Commencer = function(objet) glisse = objet end
    carte.__scripts.OnDragStart(carte)
    LCM.UI.Glisser.Commencer = commencer
    return glisse
end
local glisse = Prendre(Carte("sacs", 2))
attendu("un sac plein se prend", glisse ~= nil, true)
attendu("  mais sans reference : il ne va nulle part ailleurs", glisse and glisse.ref, nil)
attendu("  et ne sait pas quitter sa place", glisse and glisse.retirer, nil)
local arrivee = Carte("sacs", 1)
attendu("l'autre emplacement de sac l'accepte", (arrivee.glisserAccepte(glisse)), true)
arrivee.glisserDepose(glisse)
attendu("echange a la souris", Sac("sacs", 1) .. "/" .. Sac("sacs", 2), "sac_petit/sac_grand")
attendu("le contenu a suivi", Inv.Case(Inv.Emplacement(moi, "sacs", 1), 1).ref, PIERRE)
local accepte, pourquoi = Carte("saccoches", 1).glisserAccepte(Prendre(Carte("sacs", 1)))
attendu("une saccoche refuse le sac", accepte, false)
attendu("  et dit pourquoi", pourquoi, "un sac se porte dans un emplacement Sacs.")

dire("== transvaser : un objet lache sur un autre sac passe dedans")
-- 16 octobre 2026 (le MJ) : glisser un objet d'un sac sur l'emplacement d'un
-- autre sac ne l'equipe pas, il le fait passer DEDANS.
local PLUME = "ressources/plume_temoin"
LCM.UI.Inventaires.Actualiser()
-- Sacs 1 : le petit sac (4 places, la pierre en case 1) ; Sacs 2 : le grand.
Inv.Ranger(moi, "sacs", 2, 1, PLUME, 4)
Inv.Ranger(moi, "sacs", 1, 2, PLUME, 3)
local function DeLaCase(onglet, index, case)
    local c = Inv.Case(Inv.Emplacement(moi, onglet, index), case)
    return { ref = c.ref, quantite = c.quantite, nom = "x",
        origine = { onglet = onglet, index = index, case = case },
        retirer = function() Inv.Vider(moi, onglet, index, case) end,
        rendre = function() Inv.Ranger(moi, onglet, index, case, c.ref, c.quantite) end }
end
local plumes = DeLaCase("sacs", 1, 2)
local grand = Carte("sacs", 2)
attendu("la carte du grand sac l'accepte", (grand.glisserAccepte(plumes)), true)
grand.glisserDepose(plumes)
attendu("les 3 plumes ont quitte le petit sac", Inv.Case(Inv.Emplacement(moi, "sacs", 1), 2), nil)
attendu("  la pile du grand est completee jusqu'a 5", Inv.Case(Inv.Emplacement(moi, "sacs", 2), 1).quantite, 5)
attendu("  le reste prend une case libre", LCM.Prix.Avoir(moi, PLUME), 7)
local pierres = DeLaCase("sacs", 1, 1)
attendu("une ressource aussi passe d'un sac a l'autre", (grand.glisserAccepte(pierres)), true)
-- Le grand sac rempli de piles PLEINES (la pierre, sans pile maximale,
-- completerait sinon une pile de pierres) : ce qui ne tient pas est refuse,
-- et reste a sa place.
for case = 1, 12 do
    if not Inv.Case(Inv.Emplacement(moi, "sacs", 2), case) then Inv.Ranger(moi, "sacs", 2, case, PLUME, 5) end
end
Inv.Case(Inv.Emplacement(moi, "sacs", 2), 2).quantite = 5
local ok, pourquoi = grand.glisserAccepte(pierres)
attendu("sac plein : refuse", ok, false)
attendu("  et dit pourquoi", tostring(pourquoi):find("pas assez de place") ~= nil, true)
local petit = Carte("sacs", 1)
attendu("le lacher sur son propre sac ne fait rien", (petit.glisserAccepte(pierres)), true)
petit.glisserDepose(pierres)
attendu("  la pierre est toujours la", Inv.Case(Inv.Emplacement(moi, "sacs", 1), 1).ref, PIERRE)

dire("== les emplacements vides")
attendu("plus de tas de cranes", Carte("saccoches", 2).icone:GetTexture(), "Interface\\PaperDoll\\UI-Backpack-EmptySlot")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
