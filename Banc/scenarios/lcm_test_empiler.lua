-- Ranger sans dire ou (Inventaire.Deposer) complete les piles existantes
-- (13 octobre 2026). Chaque eau recoltee ouvrait sa propre case : « Eau »,
-- « Eau x9 », « Eau »… Une pile se remplit jusqu'a sa pile maximale, et une
-- case ne s'ouvre que pour le reste. Tout tient, ou rien ne bouge.
--
-- Contenu TEMOIN : ressources et sac d'essai, jamais ceux de la campagne.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

LCM.Brouillons.Set("ressources", { id = "eau_temoin", label = "Eau témoin" })
LCM.Brouillons.Set("ressources", { id = "fer_temoin", label = "Fer témoin", pileMax = 5 })
LCM.Brouillons.Set("ressources", { id = "gemme_temoin", label = "Gemme témoin", pileMax = 1 })
LCM.Brouillons.Set("sacs", { id = "sac_temoin", label = "Sac témoin", places = 4 })
__declencher("PLAYER_LOGIN")
__personnage()
local I = LCM.Inventaire
local moi = LCM.Entities.Self()
I.Poser(moi, "sacs", 1, "sac_temoin", true)

-- Les piles d'une entree, dans l'ordre ou on les voit : « 5,5,2 ».
local function Piles(ref)
    local out = {}
    for _, categorie in ipairs(I.categories) do
        for index = 1, I.Capacite(categorie.id) do
            local e = I.Emplacement(moi, categorie.id, index)
            if e then
                for case = 1, I.Cases(e) do
                    local c = I.Case(e, case)
                    if c and c.ref == ref then out[#out + 1] = tostring(c.quantite) end
                end
            end
        end
    end
    return table.concat(out, ",")
end

local function Libres()
    local n = 0
    for _, categorie in ipairs(I.categories) do
        for index = 1, I.Capacite(categorie.id) do
            local e = I.Emplacement(moi, categorie.id, index)
            if e then
                local total, places = I.Cases(e)
                for case = 1, math.min(total, places) do
                    if not I.Case(e, case) then n = n + 1 end
                end
            end
        end
    end
    return n
end

dire("== sans pile maximale : une seule pile, qui grossit")
local EAU = "ressources/eau_temoin"
attendu("une première eau", (I.Deposer(moi, EAU, 1)), true)
attendu("une deuxième", (I.Deposer(moi, EAU, 1)), true)
attendu("neuf de plus", (I.Deposer(moi, EAU, 9)), true)
attendu("une seule pile de onze", Piles(EAU), "11")

dire("== avec une pile maximale : on remplit, puis on déborde")
local FER = "ressources/fer_temoin"
I.Deposer(moi, FER, 3)
attendu("trois", Piles(FER), "3")
I.Deposer(moi, FER, 4)
attendu("la pile se remplit à 5, le reste ouvre une case", Piles(FER), "5,2")
I.Deposer(moi, FER, 3)
attendu("la seconde se complète d'abord", Piles(FER), "5,5")
I.Deposer(moi, FER, 1)
attendu("pleines : une nouvelle case", Piles(FER), "5,5,1")

dire("== une pile maximale de 1 : chaque unité a sa case")
local GEMME = "ressources/gemme_temoin"
local libres = Libres()
attendu("deux gemmes", (I.Deposer(moi, GEMME, 2)), true)
attendu("deux cases", Piles(GEMME), "1,1")
attendu("  prises sur les libres", Libres(), libres - 2)

dire("== tout ou rien")
libres = Libres()
local avantFer = Piles(FER)
-- Il reste 4 sur la derniere pile de fer, plus 5 par case libre.
local place = 4 + 5 * libres
local ok, raison = I.Deposer(moi, FER, place + 1)
attendu("une unité de trop : refusé", ok, false)
attendu("  et on dit pourquoi", raison, "aucune place libre.")
attendu("  rien n'a bougé", Piles(FER), avantFer)
attendu("  aucune case prise", Libres(), libres)
attendu("tout juste ce qu'il faut : accepté", (I.Deposer(moi, FER, place)), true)
attendu("  les cases libres sont remplies", Libres(), 0)

dire("== une quantité illisible est refusée")
attendu("zéro", (I.Deposer(moi, EAU, 0)), false)
attendu("  fractionnaire", (I.Deposer(moi, EAU, 1.5)), false)
attendu("  l'eau n'a pas bougé", Piles(EAU), "11")

dire("== un contenant acheté se PORTE dans l'emplacement fait pour lui")
-- Range comme un objet, un sac achete echouait : sans sac porte, ou avec des
-- sacoches seulement, il n'avait nulle part ou aller (13 octobre 2026). Il
-- s'equipe d'abord ; sans emplacement libre, il se range comme avant.
LCM.Brouillons.Set("sacs", { id = "sac_achat", label = "Sac acheté", places = 6 })
LCM.Brouillons.Set("sacs", { id = "sacoche_achat", label = "Sacoche achetée", nature = "sacoche", places = 3 })
LCM.Brouillons.Set("sacs", { id = "ceinture_achat", label = "Ceinture achetée", nature = "ceinture", places = 2 })
-- Les brouillons poses apres la connexion entrent tout de suite au registre.
for _, id in ipairs({ "sac_achat", "sacoche_achat", "ceinture_achat" }) do
    if not LCM.Sacs.Get(id) then LCM.Sacs.Add(LCM.Brouillons.Get("sacs", id)) end
end
local function Porte(categorie)
    local out = {}
    for index = 1, I.Capacite(categorie) do
        local e = I.Emplacement(moi, categorie, index)
        out[#out + 1] = (e and (e.sac or e.tente)) or "-"
    end
    return table.concat(out, ",")
end
local sacsAvant = Porte("sacs")

local ok2, pourquoi = I.Deposer(moi, "sacs/ceinture_achat", 1)
attendu("la ceinture s'achète", ok2, true)
attendu("  elle se porte sur la Ceinture", I.Emplacement(moi, "ceintures", 1).sac, "ceinture_achat")
ok2, pourquoi = I.Deposer(moi, "sacs/ceinture_achat", 1)
attendu("une seconde : la Ceinture est prise, et aucun sac plein ne la prend", ok2, false)
attendu("  on dit pourquoi", pourquoi, "l'emplacement Ceinture est déjà pris, et aucun sac ne peut le contenir.")

ok2 = I.Deposer(moi, "sacs/sacoche_achat", 1)
attendu("la sacoche s'achète", ok2, true)
attendu("  elle va sur un emplacement de sacoche", Porte("saccoches"):find("sacoche_achat", 1, true) ~= nil, true)
attendu("  pas sur un emplacement de sac", Porte("sacs"), sacsAvant)

ok2 = I.Deposer(moi, "sacs/sac_achat", 1)
attendu("le sac s'achète", ok2, true)
attendu("  il va sur un emplacement de sac libre", Porte("sacs"):find("sac_achat", 1, true) ~= nil, true)
attendu("  jamais en sacoche", Porte("saccoches"):find("sac_achat", 1, true), nil)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
