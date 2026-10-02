-- Les actions du radial : resolutions du compendium, composeur, declaration.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function aDit(motif)
    for i = #__sorties, 1, -1 do
        if __sansCouleur(__sorties[i]):find(motif, 1, true) then return true end
    end
    return false
end

__declencher("PLAYER_LOGIN")
local A = LCM.Actions
local E = LCM.Entities
local moi = E.Self()
E.Set_Value(moi, "force", 4)
E.Set_Value(moi, "perception", 3)
E.Set_Value(moi, "pen_tranchant", 2)
E.Set_Value(moi, "pen_feu", 4)
E.Set_Value(moi, "meca_attaque_simple", 2)

dire("== la table de correspondance")
attendu("mecanique : base", A.Stat("Mécaniques de compétence#Attaque simple:Base", moi), 70)
attendu("mecanique : par point", A.Stat("Mécaniques de compétence#Attaque simple:Par point", moi), 5)
attendu("mecanique : equipement", A.Stat("Mécaniques de compétence#Attaque simple:Equip. par point", moi), 5)
attendu("points investis", A.Stat("Répartition des expertises#attaquesimple", moi), 2)
attendu("recapitulatif", A.Stat("Recapitulatif#Attaques & Défense/Force", moi), 0)
attendu("une primaire", A.Stat("Force", moi), 4)
attendu("un nombre d'equilibrage", A.Stat("Base buff Pen", moi), 0.8)
attendu("chemin : multiplicateur de Force", A.Chemin("0.fiche.window_custom_7::custom_11::field_221.value", moi), 1.2)
attendu("chemin : case 1 des primaires", A.Chemin("0.inventory.window_custom_1::ficheContainer_window_custom_1_field_39::cell_1::1.value", moi), 4)
attendu("chemin : grille des mecaniques", A.Chemin("0.fiche.window_custom_7::custom_13::field_258.row:buff:c1", moi), 70)
attendu("chemin inconnu", A.Chemin("0.fiche.window_custom_99::x::y.value", moi), nil)
attendu("« Air » est le vent", A.ValeurType("Air", "Penetrations", moi), 0)

dire("== les formules")
local ctx = { entity = moi, vars = { a = 2, b = "Corps" } }
attendu("arithmetique", A.Evaluer("var:a * 3 + 1", ctx), 7)
attendu("accolades", A.Evaluer("{stat:Force} * 2", ctx), 8)
attendu("chemin dans une formule", A.Evaluer("[[0.fiche.window_custom_7::custom_11::field_221.value]] * 10", ctx), 12)
attendu("rien d'autre que du calcul", A.Arithmetique("os.exit()"), nil)
attendu("condition texte", A.Condition("var:b == corps", ctx), true)
attendu("condition contient", A.Condition("var:b contient orp", ctx), true)
attendu("condition nombre", A.Condition("var:a > 1 && var:a < 3", ctx), true)
attendu("une reference inconnue vaut 0", A.Evaluer("{stat:Fantome} + 1", ctx), 1)
attendu("et elle est notee", ctx.inconnues and ctx.inconnues["stat:Fantome"], true)

dire("== le bouton Attaque ouvre son composeur")
local R = LCM.UI.Radial
attendu("le bouton est lie", R.EstLiee("attaque_simple"), true)
attendu("toutes les actions sont liees", (function()
    for _, cat in ipairs(R.STRUCTURE) do
        for _, e in ipairs(cat.entrees or {}) do if not R.EstLiee(e.id) then return e.id end end
    end
    return true
end)(), true)
R.Trouver("attaque_simple").onClick()
local f = LCM.UI.Composeur.frame
attendu("fenetre ouverte", f:IsShown(), true)
attendu("titre", f.titre:GetText(), "Composer mon attaque")
attendu("premiere question", f.question:GetText():find("Type d'action", 1, true) ~= nil, true)
attendu("PA : rien d'engage sur 4", f.pa.valeur:GetText(), "0 / 4")
attendu("on ne passe pas sans repondre", f.suivant:IsEnabled(), false)

local function choisir(libelle)
    for _, b in ipairs(f.boutons) do
        if b:IsShown() and b.o and b.o.label == libelle then b:Click() return true end
    end
    for _, c in ipairs(f.cases) do
        if c:IsShown() and c.o and c.o.label == libelle then c:Click() return true end
    end
    return false
end
attendu("Corps a corps", choisir("Corps a corps"), true)
attendu("le recapitulatif le note", f.recapLignes[1]:IsShown() and f.recapLignes[1].texte:GetText():find("Corps a corps", 1, true) ~= nil, true)
f.suivant:Click()
attendu("la question suivante depend du choix", f.question:GetText():find("Poids (CaC)", 1, true) ~= nil, true)
choisir("CaC puissant")
attendu("le cout s'affiche", f.pa.valeur:GetText(), "2 / 4")
attendu("et la fatigue", f.pf.valeur:GetText():match("^3 /") ~= nil, true)
f.suivant:Click()
choisir("Rand Adresse") f.suivant:Click()
choisir("Brutale (Force)") f.suivant:Click()
attendu("les types : seuls ceux qu'on a", (function()
    local n = 0
    for _, c in ipairs(f.cases) do if c:IsShown() then n = n + 1 end end
    return n
end)(), 1)
choisir("Tranchant") f.suivant:Click()
choisir("Feu") f.suivant:Click()
attendu("pas de penetration cosmique : question sautee", f.question:GetText():find("Ciblage", 1, true) ~= nil, true)
choisir("Monocible")
attendu("degat normal au pied", f.resultats[1].titre:GetText() .. " " .. f.resultats[1].valeur:GetText(), "Dégât normal 8")
attendu("degat critique", f.resultats[2].valeur:GetText(), "12")
attendu("perce-armure", f.resultats[3]:IsShown() and f.resultats[3].valeur:GetText():find("(6 %)", 1, true) ~= nil, true)
f.suivant:Click()
attendu("ecran de fin", f.declarer:IsShown(), true)

local paAvant, pfAvant = E.Gauge(moi, "pa").current, E.Gauge(moi, "fatigue").current
local function chatDit(motif)
    for i = #__chats, 1, -1 do if __chats[i].texte:find(motif, 1, true) then return __chats[i] end end
end
__groupe({ "Reika-Apertus", "Nytherah-Apertus" })
f.declarer:Click()
attendu("fenetre fermee", f:IsShown(), false)
local C = LCM.UI.Resolution.cibles
attendu("le choix des cibles s'ouvre", C ~= nil and C:IsShown(), true)
attendu("monocible", C.mode:GetText(), "monocible")
attendu("moi d'abord, puis le groupe", C.joueurs.nombre, 2)
attendu("moi, marque", C.joueurs.lignes[1].label:GetText():find("(vous)", 1, true) ~= nil, true)
attendu("addon pas encore vu : marque", C.joueurs.lignes[2].label:GetText():find("addon non confirmé", 1, true) ~= nil, true)
local demande = false
for _, e in ipairs(__envois) do if e.message:find("ici?|", 1, true) then demande = true end end
attendu("on a demande qui a l'addon", demande, true)
LCM.Reseau.Recevoir("Nytherah-Apertus", "1:1:1:ici|" .. LCM.Reseau.Encoder({ v = "0.1.0" }))
attendu("sa reponse met la liste a jour", C.joueurs.lignes[2].label:GetText(), "Nytherah-Apertus")
-- Une presence ne se perime pas : on l'a vue, on le sait.
__avancerTemps(3600)
attendu("toujours confirmee une heure apres", LCM.Presence.Confirmee("Nytherah-Apertus"), true)
__avancerTemps(-3600)
attendu("rien de debite avant les cibles", E.Gauge(moi, "pa").current, paAvant)
attendu("rien d'annonce non plus", chatDit("déclare : Attaque") == nil, true)
attendu("sans cible, on ne declare pas", C.declarer:IsEnabled(), false)
-- Monocible : en cocher une decoche l'autre.
C.joueurs.lignes[1]:Click()
C.joueurs.lignes[2]:Click()
attendu("une seule cible a la fois", C.joueurs.lignes[1]:EstCochee(), false)
attendu("le cout reste celui du composeur", C.pa.valeur:GetText(), "2 / 4")
local n = #__envois
C.declarer:Click()
attendu("PA debites", E.Gauge(moi, "pa").current, paAvant - 2)
attendu("fatigue debitee", E.Gauge(moi, "fatigue").current, pfAvant - 3)
local jet = chatDit("Adresse :")
attendu("le jet d'Adresse est annonce au groupe", jet and jet.canal, "PARTY")
attendu("la declaration aussi", chatDit("déclare : Attaque") ~= nil, true)
attendu("l'action part a la cible", __envois[n + 1] and __envois[n + 1].cible, "Nytherah-Apertus")
attendu("en chuchotant", __envois[n + 1] and __envois[n + 1].canal, "WHISPER")
attendu("aucun morceau au-dessus de 255 octets", __plusGrosEnvoi() <= 255, true)
attendu("on voit ce qu'on a envoye", aDit("Attaque déclaré à 1 cible"), true)

dire("== annuler le choix des cibles : rien n'est debite")
local pa1 = E.Gauge(moi, "pa").current
R.Trouver("attaque_simple").onClick()
choisir("Corps a corps") f.suivant:Click() choisir("CaC leger") f.suivant:Click()
choisir("Rand Adresse") f.suivant:Click() choisir("Brutale (Force)") f.suivant:Click()
choisir("Tranchant") f.suivant:Click() choisir("Feu") f.suivant:Click() choisir("Monocible") f.suivant:Click()
f.declarer:Click()
C.annuler:Click()
attendu("PA intacts", E.Gauge(moi, "pa").current, pa1)
attendu("et on le dit", aDit("déclaration annulée. Rien n'a été débité."), true)
__groupe({})

dire("== fermer le composeur : rien n'est debite")
local pa2 = E.Gauge(moi, "pa").current
R.Trouver("attaque_simple").onClick()
choisir("Corps a corps") f.suivant:Click() choisir("CaC leger")
f:Hide()
attendu("PA intacts", E.Gauge(moi, "pa").current, pa2)
attendu("et on le dit", aDit("action annulée. Rien n'a été débité."), true)

dire("== trop cher : grise, et bloque")
E.SetGauge(moi, "pa", 0)
R.Trouver("attaque_simple").onClick()
choisir("Corps a corps") f.suivant:Click()
local leger
for _, b in ipairs(f.boutons) do if b:IsShown() and b.o.label == "CaC leger" then leger = b end end
attendu("une option hors de portee est grisee", leger:IsEnabled(), false)
f:Hide()

dire("== une etape pas encore prise en charge arrete tout, et le dit")
E.SetGauge(moi, "pa", 4)
local pa3 = E.Gauge(moi, "pa").current
local essai = { entity = moi, vars = {}, journal = {}, nom = "Essai", effets = {} }
A.Etapes({ { type = "pay", id = "p", amount = "1", tag = "#pa" }, { type = "inconnue", id = "x", label = "Mystère" },
           { type = "declare", id = "d" } }, essai, function() end)
attendu("arret annonce", aDit("Essai : l'étape « Mystère » (inconnue) n'est pas encore prise en charge. Rien n'a été débité."), true)
attendu("rien de debite", E.Gauge(moi, "pa").current, pa3)

dire("== si / sinon")
local etapes = { { type = "condition", id = "c", branches = {
    { kind = "if", condition = "var:x == a", steps = { { type = "message", id = "m1", message = "branche A" } } },
    { kind = "else", steps = { { type = "message", id = "m2", message = "branche sinon" } } } } } }
local function jouer(x)
    local c = { entity = moi, vars = { x = x }, journal = {}, nom = "essai", etapes = etapes, feuilles = {} }
    A.Etapes(etapes, c, function() end)
end
-- Un message s'affiche dans une fenetre, et attend son « OK ».
local M = LCM.UI.Resolution
jouer("a")
attendu("la condition vraie", M.choix:IsShown() and M.choix.titre:GetText(), "branche A")
M.choix.boutons[1]:Click()
attendu("OK ferme", M.choix:IsShown(), false)
jouer("b")
attendu("sinon", M.choix.titre:GetText(), "branche sinon")
M.choix.boutons[1]:Click()

dire("== une action MJ est refusee a un joueur")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
attendu("refus", A.Lancer("attaque_mj"), nil)
attendu("dit pourquoi", aDit("Attaque MJ : réservé au maître du jeu."), true)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
