-- Chaque objet a SON etat (20 octobre 2026).
--
-- L'usure et les vies etaient rangees sur le personnage, au nom du modele :
-- six kits de crochetage partageaient un compteur, et un kit detruit le
-- leguait au suivant qu'on mettait dans son sac. Elles vivent maintenant sur
-- l'exemplaire (Core/Exemplaires.lua) : en utiliser, briser ou detruire un
-- n'affecte ni les autres, ni les prochains. Dans une pile, c'est le plus
-- entame qui sert le premier.
local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

LCM.Brouillons.Set("sacs", { id = "sac_d_essai", label = "Sac d'essai", places = 12, icone = "inv_misc_bag_30" })
__declencher("PLAYER_LOGIN")
__personnage()
local moi = LCM.Entities.Self()
local O, I = LCM.Objets, LCM.Inventaire
I.Poser(moi, "sacs", 1, "sac_d_essai", true)

-- Des objets temoins : un etat de 4, et la rarete par la couleur du titre
-- (vert : une vie ; rose : aucune).
O.Add({ id = "kit_temoin", label = "Kit témoin", categorie = "outil", couleurTitre = "4DE04D", etat = { max = 4 } })
O.Add({ id = "kit_fragile", label = "Kit fragile", categorie = "outil", couleurTitre = "FF8CB8", etat = { max = 4 } })
O.Add({ id = "capuche_temoin", label = "Capuche témoin", categorie = "equipement",
        etat = { max = 10 }, bonus = { force = 10 } })
local KIT, FRAGILE = "objets/kit_temoin", "objets/kit_fragile"

local function Pile(ref)
    local p = I.Piles(moi, ref)[1]
    return p and p.pile
end
local function Usures(ref)
    local out = {}
    for _, p in ipairs(I.Piles(moi, ref)) do
        for _, e in ipairs(p.pile.exemplaires or {}) do out[#out + 1] = tonumber(e.usure) or 0 end
    end
    table.sort(out, function(a, b) return a > b end)
    return table.concat(out, ",")
end

dire("== six kits : chacun son etat")
attendu("six kits dans le sac", (I.Deposer(moi, KIT, 6)), true)
attendu("une pile de six", Pile(KIT).quantite, 6)
O.UserInventaire(moi, "kit_temoin", 1)
attendu("un seul s'use", Usures(KIT), "1,0,0,0,0,0")
O.UserInventaire(moi, "kit_temoin", 1)
attendu("le plus entame sert encore : on le finit", Usures(KIT), "2,0,0,0,0,0")
attendu("la pile montre celui qui servira", O.Usure(moi, "kit_temoin", O.ExemplaireDePile(Pile(KIT))), 2)
local etat = LCM.UI.EtatObjet(moi, O.Get("kit_temoin"), O.ExemplaireDePile(Pile(KIT)))
attendu("et son etat s'affiche", etat, "2/4")

dire("== il se brise seul")
O.UserInventaire(moi, "kit_temoin", 2)
local brise
for _, e in ipairs(Pile(KIT).exemplaires) do if (tonumber(e.usure) or 0) >= 4 then brise = e end end
attendu("a zero, il se brise", brise ~= nil, true)
attendu("  et perd sa vie, a lui", brise and brise.viesPerdues, 1)
local viesPerdues = 0
for _, e in ipairs(Pile(KIT).exemplaires) do viesPerdues = viesPerdues + (tonumber(e.viesPerdues) or 0) end
attendu("  les cinq autres gardent la leur", viesPerdues, 1)
O.UserInventaire(moi, "kit_temoin", 1)
attendu("un brise ne sert plus : un neuf prend le relais", Usures(KIT), "4,1,0,0,0,0")
attendu("rien n'a quitte la pile", Pile(KIT).quantite, 6)

dire("== detruit, il part seul et emporte son etat")
I.Deposer(moi, FRAGILE, 3)
O.UserInventaire(moi, "kit_fragile", 1)
local _, detruit = O.UserInventaire(moi, "kit_fragile", 3)
attendu("un kit sans vie tombe a zero : detruit", detruit, true)
attendu("la pile perd UN kit", Pile(FRAGILE).quantite, 2)
attendu("les deux restants sont neufs", Usures(FRAGILE), "0,0")

dire("== le cas du joueur : detruire, puis en remettre un")
-- « Je prends un kit, je l'use, je le detruis, j'en remets un : il reprend
-- l'etat du premier. » Plus maintenant.
local p = I.Piles(moi, FRAGILE)[1]
I.Vider(moi, p.categorie, p.index, p.case)
attendu("plus de kit fragile", #I.Piles(moi, FRAGILE), 0)
I.Deposer(moi, FRAGILE, 1)
attendu("le nouveau est neuf", Usures(FRAGILE), "0")
attendu("  avec toutes ses vies", (O.Vies(moi, O.Get("kit_fragile"), O.ExemplaireDePile(Pile(FRAGILE)))), 0)
attendu("rien n'est reste sur le personnage", moi.usureArmure == nil and moi.viesObjet == nil, true)

dire("== deux capuches identiques portees")
O.Placer(moi, "capuche_temoin")
O.Placer(moi, "capuche_temoin")
local ids = O.Ids(moi, "equipement")
attendu("deux capuches", #ids, 2)
O.Encaisser(moi, "capuche_temoin", 3, 1)
attendu("la premiere est touchee", O.Usure(moi, "capuche_temoin", O.ExemplairePorte(moi, "equipement", 1)), 3)
attendu("la seconde non", O.Usure(moi, "capuche_temoin", O.ExemplairePorte(moi, "equipement", 2)), 0)
-- 70 % de +10 donne 7, plus les 10 de la neuve.
attendu("chacune apporte selon SON etat", LCM.Effets.Bonus(moi, "force"), 17)
local _, exTouchee = O.Enlever(moi, "capuche_temoin", O.ExemplairePorte(moi, "equipement", 1).id)
attendu("retiree, elle emporte son usure", O.Usure(moi, "capuche_temoin", exTouchee), 3)
attendu("celle qui reste est neuve", O.Usure(moi, "capuche_temoin", O.ExemplairePorte(moi, "equipement", 1)), 0)
O.Enlever(moi, "capuche_temoin")

dire("== l'etat voyage avec l'objet, et se verifie")
local copie = LCM.Copie(Pile(KIT).exemplaires)
local lue = LCM.Exemplaires.Lire(KIT, #copie, copie)
attendu("un etat lisible passe", lue ~= nil, true)
copie[1].usure = -2
local _, raison = LCM.Exemplaires.Lire(KIT, #copie, copie)
attendu("une usure negative est refusee", raison, "état d'exemplaire illisible.")
copie[1].usure, copie[1].viesPerdues = nil, 1.5
_, raison = LCM.Exemplaires.Lire(KIT, #copie, copie)
attendu("des vies non entieres aussi", raison, "état d'exemplaire illisible.")

dire("== une sauvegarde d'avant")
-- L'ancien compteur, au nom du modele : chaque exemplaire possede le recoit
-- (c'est ce que la fiche affichait pour tous), puis il disparait.
local autre = { id = "ancien", inventaire = LCM.Copie(moi.inventaire) }
autre.usureArmure = { kit_temoin = 3, objet_disparu = 2 }
autre.viesObjet = { kit_temoin = 1 }
attendu("avant la reprise : le compteur commun", O.Usure(autre, "kit_temoin", {}), 3)
O.MigrerEtats(autre)
local tous = {}
for _, q in ipairs(I.Piles(autre, KIT)) do
    for _, e in ipairs(q.pile.exemplaires) do tous[#tous + 1] = (e.usure or 0) .. "/" .. (e.viesPerdues or 0) end
end
attendu("chaque kit recoit l'etat qu'il affichait", table.concat(tous, ","), "3/1,3/1,3/1,3/1,3/1,3/1")
attendu("le compteur du modele est parti", autre.usureArmure and autre.usureArmure.kit_temoin, nil)
attendu("un objet inconnu de cette version garde le sien", autre.usureArmure and autre.usureArmure.objet_disparu, 2)
attendu("les vies aussi sont parties", autre.viesObjet, nil)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
