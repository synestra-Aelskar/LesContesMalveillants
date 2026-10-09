-- Creation de personnage : budgets, plafonds, refus.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
local C = LCM.Creation
local E = LCM.Equilibrage

dire("== un brouillon neuf demarre au niveau 5")
local b = C.Nouveau()
attendu("niveau de depart", b.niveau, 5)
attendu("rien de depense", C.Depense(b, "primaires"), 0)

dire("== les budgets au niveau 5")
attendu("primaires  17 + 3x5", C.Total(b, "primaires"), 32)
attendu("secondaires 12 + 4x5", C.Total(b, "secondaires"), 32)
attendu("expertises  8 + 2x5", C.Total(b, "expertises"), 18)
attendu("mecaniques  2 + 3x5", C.Total(b, "mecaniques"), 17)
attendu("traits      2 + 5/5", C.Total(b, "traits"), 3)

dire("== plafond d'une statistique primaire : 4 + niveau")
attendu("plafond", C.Plafond(b, "primaires", "force"), 9)
attendu("9 passe", (C.Definir(b, "primaires", "force", 9)), true)
local ok, raison = C.Definir(b, "primaires", "mystique", 10)
attendu("10 refuse", ok, false)
attendu("et le refus s'explique", tostring(raison):find("plafond") ~= nil, true)
attendu("la valeur refusee n'est pas ecrite", C.Valeur(b, "mystique"), 0)

dire("== le budget primaire s'epuise")
C.Definir(b, "primaires", "mystique", 9)
C.Definir(b, "primaires", "perception", 9)
attendu("depense 27 sur 32", C.Depense(b, "primaires"), 27)
attendu("reste 5", C.Budget(b, "primaires").reste, 5)

dire("== Adresse et Esprit coutent deux points et plafonnent plus bas")
attendu("cout d'une primaire ordinaire", C.Cout("primaires", "force"), 1)
attendu("cout de l'adresse", C.Cout("primaires", "adresse"), 2)
attendu("plafond de l'adresse : 2 + niveau", C.Plafond(b, "primaires", "adresse"), 7)
attendu("plafond de l'esprit", C.Plafond(b, "primaires", "esprit"), 7)
ok, raison = C.Definir(b, "primaires", "adresse", 7)
attendu("7 refuse, faute de points", ok, false)
attendu("le refus compte les points", tostring(raison):find("reste") ~= nil, true)
-- 5 points restants, 2 par cran : deux crans.
attendu("le maximum atteignable", C.Maximum(b, "primaires", "adresse"), 2)
attendu("2 passe", (C.Definir(b, "primaires", "adresse", 2)), true)
attendu("quatre points depenses pour deux crans", C.Budget(b, "primaires").reste, 1)

dire("== R et M : remettre a zero, monter au maximum")
attendu("remise a zero", (C.Remettre(b, "primaires", "adresse")), true)
attendu("les points reviennent", C.Budget(b, "primaires").reste, 5)
C.Definir(b, "primaires", "adresse", C.Maximum(b, "primaires", "adresse"))
attendu("M pose deux crans", C.Valeur(b, "adresse"), 2)
C.RemettreCategorie(b, "primaires")
attendu("la categorie entiere revient", C.Budget(b, "primaires").reste, 32)
attendu("et les valeurs sont parties", C.Valeur(b, "force"), 0)

dire("== penetration : l'exemple de l'utilisateur (3 + 3 + 3)")
local p = C.Nouveau()
C.Definir(p, "primaires", "force", 3)
C.Definir(p, "primaires", "mystique", 3)
C.Definir(p, "primaires", "perception", 3)
-- 9 / 1,75 = 5,14 arrondi a 5, plus la base de 3.
attendu("plafond d'un type", C.Plafond(p, "penetration", "pen_tranchant"), 8)
attendu("8 passe", (C.Definir(p, "penetration", "pen_tranchant", 8)), true)
attendu("9 refuse", (C.Definir(p, "penetration", "pen_perforant", 9)), false)

dire("== plus on investit en degats, plus on peut se specialiser")
attendu("sans statistique", C.Plafond(C.Nouveau(), "penetration", "pen_feu"), 3)
local fort = C.Nouveau()
C.Definir(fort, "primaires", "force", 9)
C.Definir(fort, "primaires", "mystique", 9)
attendu("avec 18 points de degats", C.Plafond(fort, "penetration", "pen_feu"), 13)

dire("== resistance : constitution / 4")
local r = C.Nouveau()
attendu("sans constitution", C.Plafond(r, "resistance", "resi_feu"), 3)
C.Definir(r, "primaires", "constitution", 4)
-- Template : 3 + Constitution / 0,25
attendu("avec 4 de constitution", C.Plafond(r, "resistance", "resi_feu"), 19)
C.Definir(r, "primaires", "constitution", 9)
attendu("avec 9 de constitution", C.Plafond(r, "resistance", "resi_feu"), 39)

dire("== les points secondaires ne coutent pas tous pareil")
local s = C.Nouveau()
attendu("un point d'action coute 8", (C.Definir(s, "secondaires", "sec_pa", 1)), true)
attendu("depense", C.Depense(s, "secondaires"), 8)
attendu("plafond PA a 5 : 1 + 5/3", C.Plafond(s, "secondaires", "sec_pa"), 2)
attendu("3 refuse", (C.Definir(s, "secondaires", "sec_pa", 3)), false)
attendu("plafond vitalite : 2 x niveau", C.Plafond(s, "secondaires", "sec_vitalite"), 10)
attendu("plafond initiative : 3 x niveau (template)", C.Plafond(s, "secondaires", "sec_initiative"), 15)

dire("== investir en Expertises agrandit le budget d'expertises")
local x = C.Nouveau()
attendu("budget de base", C.Total(x, "expertises"), 18)
C.Definir(x, "secondaires", "sec_expertises", 4)
attendu("quatre points secondaires = huit d'expertise", C.Total(x, "expertises"), 26)
attendu("plafond d'une expertise : 5 + niveau", C.Plafond(x, "expertises", "escalade"), 10)
attendu("11 refuse", (C.Definir(x, "expertises", "escalade", 11)), false)
attendu("10 passe", (C.Definir(x, "expertises", "escalade", 10)), true)

dire("== baisser une statistique fait deborder un type deja rempli")
local d = C.Nouveau()
C.Definir(d, "primaires", "force", 9)
C.Definir(d, "penetration", "pen_tranchant", 8)
attendu("rien ne deborde", #C.Debordements(d), 0)
C.Definir(d, "primaires", "force", 0)
local debordements = C.Debordements(d)
attendu("un debordement signale", #debordements, 1)
attendu("  la ligne", debordements[1].label, "Tranchant")
attendu("  son nouveau plafond", debordements[1].plafond, 3)
attendu("il bloque la creation", #C.Problemes(d) > 0, true)

dire("== les traits coutent de 1 a 4 points")
local t = C.Nouveau()
attendu("budget de traits", C.Budget(t, "traits").total, 3)
attendu("le trait d'exemple coute 2", LCM.Traits.Get("escalade_jungle").cout, 2)
attendu("pris", (C.AjouterTrait(t, "escalade_jungle")), true)
attendu("reste 1", C.Budget(t, "traits").reste, 1)
attendu("deux fois le meme : refuse", (C.AjouterTrait(t, "escalade_jungle")), false)
attendu("trait inconnu : refuse", (C.AjouterTrait(t, "ne_existe_pas")), false)
attendu("retire", (C.RetirerTrait(t, "escalade_jungle")), true)
attendu("budget rendu", C.Budget(t, "traits").reste, 3)
local ok2 = pcall(LCM.Traits.Add, { id = "trop_cher", label = "Trop cher", cout = 5 })
attendu("un trait a 5 points est refuse au chargement", ok2, false)

dire("== mecaniques de competence")
local m = C.Nouveau()
-- Vingt-trois depuis le « Dot » (9 octobre 2026).
attendu("les mecaniques de competence", #C.Lignes("mecaniques"), 24)
attendu("budget 2 + 3x5", C.Budget(m, "mecaniques").total, 17)
C.Definir(m, "secondaires", "sec_mecanique", 4)
attendu("quatre points secondaires = quatre de plus", C.Total(m, "mecaniques"), 21)
attendu("plafond, comme une expertise", C.Plafond(m, "mecaniques", "meca_soin"), 10)
attendu("11 refuse", (C.Definir(m, "mecaniques", "meca_soin", 11)), false)
attendu("10 passe", (C.Definir(m, "mecaniques", "meca_soin", 10)), true)
attendu("depense comptee", C.Budget(m, "mecaniques").depense, 10)
attendu("la repulsion existe", LCM.Schema.Field("meca_repulsion").label, "Répulsion")
attendu("la provocation existe", LCM.Schema.Field("meca_provocation").label, "Provocation")
attendu("l'intimidation existe", LCM.Schema.Field("meca_intimidation").label, "Intimidation")
attendu("investir en provocation", C.Definir(m, "mecaniques", "meca_provocation", 1), true)
attendu("investir en intimidation", C.Definir(m, "mecaniques", "meca_intimidation", 1), true)
attendu("leurs points sont comptes", C.Budget(m, "mecaniques").depense, 12)

dire("== un brouillon incomplet ne cree rien")
local n = C.Nouveau()
-- Nom, race, et les sept budgets encore entiers : neuf raisons de refuser.
local raisons = C.Problemes(n)
attendu("sans nom ni race", #raisons, 9)
attendu("la premiere est le nom", raisons[1], "il faut un nom.")
attendu("et on dit combien de points trainent",
    table.concat(raisons, " "):find("il reste %d+ points? de statistiques a placer") ~= nil, true)
attendu("creation refusee", (C.Appliquer(n)), nil)

dire("== creation complete")
local final = C.Nouveau()
final.nom = "Ysolde"
final.race = "humain"
C.Definir(final, "primaires", "constitution", 6)
C.Definir(final, "secondaires", "sec_vitalite", 4)
C.Definir(final, "expertises", "escalade", 3)
C.Definir(final, "penetration", "pen_tranchant", 3)
C.AjouterTrait(final, "escalade_jungle")
-- Il reste des points partout : on ne cree pas un personnage a moitie fait.
attendu("des points trainent encore", #C.Problemes(final) > 0, true)

dire("== tout placer, jusqu'au dernier point")
-- On vide chaque budget sur la premiere ligne qui veut bien le prendre.
-- Les traits sont a part : ce ne sont pas des lignes a incrementer, mais une
-- liste dans laquelle on pioche tant qu'un trait est abordable.
for _, categorie in ipairs(C.CATEGORIES) do
    if categorie == "traits" then
        while C.PeutEncoreDepenser(final, "traits") do
            local pris = false
            for _, trait in ipairs(LCM.Traits.list) do
                if (trait.cout or 1) <= C.Budget(final, "traits").reste
                    and not C.ATrait(final, trait.id) then
                    C.AjouterTrait(final, trait.id) pris = true break
                end
            end
            if not pris then break end
        end
    else
        while C.PeutEncoreDepenser(final, categorie) do
            local pose = false
            for _, ligne in ipairs(C.Lignes(categorie)) do
                local id = ligne.id or ligne
                local avant = C.Valeur(final, id)
                local plafond = C.Maximum(final, categorie, id)
                if plafond > avant then
                    C.Definir(final, categorie, id, plafond) pose = true break
                end
            end
            if not pose then break end
        end
    end
end
local restants = {}
for _, categorie in ipairs(C.CATEGORIES) do
    local reste = C.Budget(final, categorie).reste
    if reste ~= 0 then restants[#restants + 1] = categorie .. "=" .. reste end
end
attendu("plus un point en poche", table.concat(restants, ","), "")
attendu("aucun probleme", #C.Problemes(final), 0)
local entity = C.Appliquer(final)
attendu("personnage cree", entity ~= nil, true)
attendu("il est joue", LCM.Personnages.ActifId(), entity.id)
attendu("sa race", LCM.Entities.Get_Value(entity, "race"), "humain")
attendu("son niveau", LCM.Entities.Get_Value(entity, "niveau"), 5)
attendu("sa constitution", LCM.Entities.Get_Value(entity, "constitution"), 6)
-- Le brouillon a ete rempli jusqu'au dernier point : on compare la fiche a ce
-- qu'il contient, pas a des nombres ecrits d'avance qui ne survivent pas au
-- premier changement d'equilibrage.
attendu("sa vitalite", LCM.Entities.Get_Value(entity, "sec_vitalite"), C.Valeur(final, "sec_vitalite"))
attendu("sa penetration tranchante", LCM.Entities.Get_Value(entity, "pen_tranchant"), C.Valeur(final, "pen_tranchant"))
attendu("son trait", LCM.Traits.Has(entity, "escalade_jungle"), true)
-- Les PV suivent la formule de la fiche, appliquee aux valeurs transmises.
attendu("ses PV max", LCM.Entities.Get_Value(entity, "pv_max"),
    LCM.Schema.Field("pv_max").formula(entity))

dire("== rééditer une fiche")
LCM.Entities.Set_Value(entity, "age", 28)
LCM.Entities.Set_Value(entity, "portrait", "moon")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
local peut, pourquoi = C.PeutEditer(entity)
attendu("un joueur sans jeton est refusé", peut, false)
attendu("et la raison parle du jeton", tostring(pourquoi):find("jeton") ~= nil, true)
attendu("le MJ donne un jeton", (C.DonnerJeton(entity)), true)
attendu("le joueur peut alors rééditer", (C.PeutEditer(entity)), true)
local reprise = C.Depuis(entity)
attendu("la même fiche sera modifiée", reprise.entite == entity, true)
attendu("le nom est repris", reprise.nom, entity.name)
attendu("l'âge est repris", reprise.valeurs.age, 28)
attendu("le portrait est repris", reprise.valeurs.portrait, "moon")
-- Une valeur retirée doit réellement partir de la fiche, pas seulement du
-- brouillon. C'était le piège du premier brouillon de la réédition.
reprise.valeurs.age = nil
local reeditee = C.Appliquer(reprise)
attendu("la réédition conserve l'entité", reeditee == entity, true)
attendu("la valeur retirée est effacée", entity.values.age, nil)
attendu("le jeton est consommé à la validation", C.ADesJetons(entity), false)
attendu("une seconde réédition est refusée", (C.Appliquer(C.Depuis(entity))), nil)

LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true
local refonteMJ = C.Depuis(entity)
refonteMJ.nom = "Ysolde rééditée"
attendu("le MJ réédite sans jeton", C.Appliquer(refonteMJ) == entity, true)
attendu("le nouveau nom est appliqué", entity.name, "Ysolde rééditée")
attendu("aucun jeton n'est consommé chez le MJ", C.ADesJetons(entity), false)

dire("== ce qui vaut le defaut n'est pas sauvegarde")
local ecrits = 0
for _ in pairs(entity.values) do ecrits = ecrits + 1 end
dire("   " .. ecrits .. " valeurs ecrites sur " .. LCM.Schema.Count() .. " champs")
attendu("le niveau de depart n'est pas stocke", entity.values.niveau, nil)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
