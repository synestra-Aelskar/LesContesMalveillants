-- L'armure portee : la jauge #armure (« armure_portee »), decision du
-- 2 octobre 2026. Nu, 0 / 0 ; chaque piece d'armure equipee apporte sa valeur
-- (2 par defaut) ; la jauge compte ce qui a ete encaisse ; chaque piece garde
-- son usure, meme enlevee.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function Jauge(e)
    local j = LCM.Entities.Gauge(e, "armure_portee")
    return j.current .. "/" .. j.max
end

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit
local O, A = LCM.Objets, LCM.Actions
-- Placer / Enlever : les gestes bruts, sans passer par les sacs (ce scenario
-- parle de la jauge, lcm_test_equipement.lua des sacs).
local moi = LCM.Entities.Self()

dire("== la valeur d'une piece")
local tshirt = O.Add({ id = "tshirt_d_essai", label = "T-shirt", categorie = "equipement" })
local plastron = O.Add({ id = "plastron_d_essai", label = "Plastron", categorie = "equipement", armure = 10 })
local epee = O.Add({ id = "epee_d_essai", label = "Épée", categorie = "arme", armure = 10 })
attendu("sans valeur : celle de l'equilibrage", tshirt.armure, LCM.Equilibrage.armure.parDefaut)
attendu("la sienne", plastron.armure, 10)
attendu("une arme n'a pas d'armure", epee.armure, nil)
attendu("une case vide : le defaut", O.Construire({ id = "x", categorie = "equipement", armure = "" }).armure, 2)
attendu("illisible : refuse", (pcall(O.Construire, { id = "x", categorie = "equipement", armure = "beaucoup" })), false)
attendu("negative : refusee", (pcall(O.Construire, { id = "x", categorie = "equipement", armure = -1 })), false)

dire("== la jauge suit ce qu'on porte")
-- Ce que la jauge COMPTE a change le 10 octobre 2026 : sa capacite est l'ETAT
-- FORGE des pieces portees (leur durabilite), et non plus leur petite
-- statistique `armure`. Un t-shirt vaut donc son etat, pas ses 2 d'armure.
-- On lit les etats dans les objets : ils ont le droit de bouger.
local etatT, etatP = O.EtatMax(tshirt), O.EtatMax(plastron)
local totalArmure = etatT + etatP
attendu("nu", Jauge(moi), "0/0")
O.Placer(moi, "tshirt_d_essai")
attendu("un t-shirt", Jauge(moi), "0/" .. etatT)
O.Placer(moi, "plastron_d_essai")
attendu("et un plastron", Jauge(moi), "0/" .. totalArmure)
O.Placer(moi, "epee_d_essai")
attendu("une arme ne compte pas dans la jauge d'armure", Jauge(moi), "0/" .. totalArmure)
attendu("rien dans les valeurs", moi.values.armure_portee, nil)
attendu("ni d'usure retenue", moi.usureArmure, nil)

dire("== une attaque : une case par objet porte")
-- Tout ce qu'on porte s'use, l'arme comprise : les cases sont les objets
-- equipes, dans l'ordre des categories (les armes d'abord). La JAUGE, elle,
-- ne compte que les armures.
local cases, inconnus = A.Zones(moi, { "#armure" })
attendu("trois objets portes", #cases, 3)
attendu("dans l'ordre des categories",
    cases[1].nom .. "," .. cases[2].nom .. "," .. cases[3].nom, "Épée,T-shirt,Plastron")
attendu("ce qui protege encore", cases[3].plafond, etatP)
attendu("#armure n'est plus inconnu", #inconnus, 0)
local ctx = { entity = moi, journal = {} }
A.Repartir(ctx, cases, { 0, 2, 3 }, "-")
attendu("encaisse", Jauge(moi), "5/" .. totalArmure)
attendu("le t-shirt a pris deux points", O.Usure(moi, "tshirt_d_essai"), 2)
attendu("le journal le dit", ctx.journal[1], "Réparti : T-shirt -2, Plastron -3")
cases = A.Zones(moi, { "#armure" })
attendu("une piece entamee n'absorbe plus que le reste", cases[2].plafond, etatT - 2)

dire("== chaque piece garde son usure")
O.Enlever(moi, "plastron_d_essai")
attendu("sans le plastron", Jauge(moi), "2/" .. etatT)
attendu("son usure reste retenue", O.Usure(moi, "plastron_d_essai"), 3)
O.Placer(moi, "plastron_d_essai")
attendu("remis, toujours abime", Jauge(moi), "5/" .. totalArmure)

dire("== reparer")
A.Repartir({ entity = moi, journal = {} }, A.Zones(moi, { "#armure" }), { 0, 0, 1 }, "+")
attendu("un gain repare", O.Usure(moi, "plastron_d_essai"), 2)
LCM.Entities.SetGauge(moi, "armure_portee", 6)
-- L'ordre dans lequel les pieces prennent les points n'est pas ce qu'on
-- verifie ici : c'est que le total pose sur la fiche se retrouve bien reparti
-- sur les pieces, sans rien perdre.
attendu("le + de la fiche se repartit sur les pieces",
    O.Usure(moi, "plastron_d_essai") + O.Usure(moi, "tshirt_d_essai"), 6)
LCM.Entities.SetGauge(moi, "armure_portee", 1)
attendu("le - repare la derniere touchee d'abord",
    O.Usure(moi, "plastron_d_essai") .. "/" .. O.Usure(moi, "tshirt_d_essai"), "0/1")
LCM.Entities.SetGauge(moi, "armure_portee", 0)
attendu("R : tout est repare", Jauge(moi), "0/" .. totalArmure)
attendu("et la sauvegarde n'en garde rien", moi.usureArmure, nil)

dire("== la fenetre Equipements montre l'usure")
LCM.Entities.SetGauge(moi, "armure_portee", 3)
LCM.UI.Menu.Trouver("equipement").onClick()
local f = LCM.UI.Vues.frames.equipement
f.barre.boutons[2]:Click()
local lignes = f.pages.equipement.blocs[1].conteneur.emplacements
-- La ligne annonce l'ETAT puis la valeur d'armure de la piece.
attendu("le t-shirt entame", lignes[1].effets:GetText(),
    string.format("État %d / %d  ·  Armure %d",
        etatT - O.Usure(moi, "tshirt_d_essai"), etatT, O.Armure(tshirt)))
attendu("le plastron aussi", lignes[2].effets:GetText(),
    string.format("État %d / %d  ·  Armure %d",
        etatP - O.Usure(moi, "plastron_d_essai"), etatP, O.Armure(plastron)))
LCM.Entities.SetGauge(moi, "armure_portee", 0)
f.pages.equipement.blocs[1].conteneur:Actualiser(moi)
attendu("neuf : son etat entier", lignes[1].effets:GetText(),
    string.format("État %d / %d  ·  Armure %d", etatT, etatT, O.Armure(tshirt)))
f:Hide()

dire("== consultation par le MJ")
LCM.Entities.SetGauge(moi, "armure_portee", 4)
local paquet = LCM.Fiches.Paquet(moi)
attendu("la fiche envoyee porte la jauge", paquet.v.armure_portee, "4/" .. totalArmure)
local recue = LCM.Fiches.Entite(paquet)
attendu("relue sans l'equipement", Jauge(recue), "4/" .. totalArmure)
attendu("une fiche recue ne s'ecrit pas", LCM.Entities.SetGauge(recue, "armure_portee", 0), false)
LCM.Entities.SetGauge(moi, "armure_portee", 0)

dire("== dans le compendium, et hors des cibles de bonus")
local valeur, cible = false, false
for _, champ in ipairs(LCM.Compendium.Champs(LCM.Compendium.Get("armures"))) do
    if champ.cle == "armure" and champ.type == "nombre" then valeur = true end
    if champ.cle == "armure_portee" then cible = true end
end
attendu("une armure se saisit dans l'editeur", valeur, true)
attendu("une jauge calculee ne recoit pas de bonus", cible, false)
local armes = false
for _, champ in ipairs(LCM.Compendium.Champs(LCM.Compendium.Get("armes"))) do
    if champ.cle == "armure" and champ.type == "nombre" then armes = true end
end
attendu("une arme n'a pas ce champ", armes, false)
if LCM.Brouillons then
    -- Le compagnon MJ est la : l'atelier enregistre l'armure d'une piece.
    -- Avec son jeu d'equilibrage : le bareme BLOQUE depuis le 3 octobre 2026
    -- et une piece d'essai sans `forge` est refusee. Ce qu'on verifie ici,
    -- c'est que l'atelier retient la VALEUR D'ARMURE, pas le cout.
    LCM.Brouillons.Enregistrer("jeux", {
        id = "essai_armure", label = "Essai (armure)", categorie = "armures",
        raretes = { { id = "libre", label = "Libre", points = 999, couleur = "FFFFFF" } },
    }, true)
    local poseCotte, pourquoiCotte = LCM.Brouillons.Enregistrer("objets",
        { id = "cotte_d_essai", label = "Cotte", categorie = "equipement", armure = "7",
          forge = "essai_armure/libre" }, true)
    attendu("l'atelier l'enregistre", poseCotte, true)
    if not poseCotte then dire("     raison : " .. tostring(pourquoiCotte)) end
    attendu("avec sa valeur", O.Get("cotte_d_essai").armure, 7)
end

O.Enlever(moi, "tshirt_d_essai")
O.Enlever(moi, "plastron_d_essai")
O.Enlever(moi, "epee_d_essai")
attendu("deshabille : 0/0", Jauge(moi), "0/0")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
