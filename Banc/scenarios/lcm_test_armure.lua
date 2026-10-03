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
attendu("nu", Jauge(moi), "0/0")
O.Placer(moi, "tshirt_d_essai")
attendu("un t-shirt", Jauge(moi), "0/2")
O.Placer(moi, "plastron_d_essai")
attendu("et un plastron", Jauge(moi), "0/12")
O.Placer(moi, "epee_d_essai")
attendu("une arme n'y ajoute rien", Jauge(moi), "0/12")
attendu("rien dans les valeurs", moi.values.armure_portee, nil)
attendu("ni d'usure retenue", moi.usureArmure, nil)

dire("== une attaque : une case par piece")
local cases, inconnus = A.Zones(moi, { "#armure" })
attendu("deux pieces", #cases, 2)
attendu("dans l'ordre des emplacements", cases[1].nom .. "," .. cases[2].nom, "T-shirt,Plastron")
attendu("ce qui protege encore", cases[2].plafond, 10)
attendu("#armure n'est plus inconnu", #inconnus, 0)
local ctx = { entity = moi, journal = {} }
A.Repartir(ctx, cases, { 2, 3 }, "-")
attendu("encaisse", Jauge(moi), "5/12")
attendu("le t-shirt est epuise", O.Usure(moi, "tshirt_d_essai"), 2)
attendu("le journal le dit", ctx.journal[1], "Réparti : T-shirt -2, Plastron -3")
cases = A.Zones(moi, { "#armure" })
attendu("une piece epuisee n'absorbe plus", cases[1].plafond, 0)

dire("== chaque piece garde son usure")
O.Enlever(moi, "plastron_d_essai")
attendu("sans le plastron", Jauge(moi), "2/2")
attendu("son usure reste retenue", O.Usure(moi, "plastron_d_essai"), 3)
O.Placer(moi, "plastron_d_essai")
attendu("remis, toujours abime", Jauge(moi), "5/12")

dire("== reparer")
A.Repartir({ entity = moi, journal = {} }, A.Zones(moi, { "#armure" }), { 0, 1 }, "+")
attendu("un gain repare", O.Usure(moi, "plastron_d_essai"), 2)
LCM.Entities.SetGauge(moi, "armure_portee", 6)
attendu("le + de la fiche empile dans l'ordre", O.Usure(moi, "plastron_d_essai"), 4)
LCM.Entities.SetGauge(moi, "armure_portee", 1)
attendu("le - repare la derniere touchee d'abord", O.Usure(moi, "plastron_d_essai") .. "/" .. O.Usure(moi, "tshirt_d_essai"), "0/1")
LCM.Entities.SetGauge(moi, "armure_portee", 0)
attendu("R : tout est repare", Jauge(moi), "0/12")
attendu("et la sauvegarde n'en garde rien", moi.usureArmure, nil)

dire("== la fenetre Equipements montre l'usure")
LCM.Entities.SetGauge(moi, "armure_portee", 3)
LCM.UI.Menu.Trouver("equipement").onClick()
local f = LCM.UI.Vues.frames.equipement
f.barre.boutons[2]:Click()
local lignes = f.pages.equipement.blocs[1].conteneur.emplacements
attendu("le t-shirt epuise", lignes[1].effets:GetText(), "Armure 0 / 2")
attendu("le plastron entame", lignes[2].effets:GetText(), "Armure 9 / 10")
LCM.Entities.SetGauge(moi, "armure_portee", 0)
f.pages.equipement.blocs[1].conteneur:Actualiser(moi)
attendu("neuf : sa valeur seule", lignes[1].effets:GetText(), "Armure 2")
f:Hide()

dire("== consultation par le MJ")
LCM.Entities.SetGauge(moi, "armure_portee", 4)
local paquet = LCM.Fiches.Paquet(moi)
attendu("la fiche envoyee porte la jauge", paquet.v.armure_portee, "4/12")
local recue = LCM.Fiches.Entite(paquet)
attendu("relue sans l'equipement", Jauge(recue), "4/12")
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
    attendu("l'atelier l'enregistre", (LCM.Brouillons.Enregistrer("objets",
        { id = "cotte_d_essai", label = "Cotte", categorie = "equipement", armure = "7" }, true)), true)
    attendu("avec sa valeur", O.Get("cotte_d_essai").armure, 7)
end

O.Enlever(moi, "tshirt_d_essai")
O.Enlever(moi, "plastron_d_essai")
O.Enlever(moi, "epee_d_essai")
attendu("deshabille : 0/0", Jauge(moi), "0/0")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
