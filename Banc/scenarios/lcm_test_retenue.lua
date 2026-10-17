-- La retenue (17 octobre 2026) : on frappait toujours a fond. A la fin du
-- composeur d'un coup, une jauge sous les degats permet de les baisser soi-
-- meme, normal et critique ensemble, avant de declarer.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function aDit(motif)
    for i = #__sorties, 1, -1 do
        if __sansCouleur(__sorties[i]):lower():find(motif:lower(), 1, true) then return true end
    end
    return false
end

__declencher("PLAYER_LOGIN")
__personnage()
local A = LCM.Actions
local E = LCM.Entities
local moi = E.Self()
-- Les memes valeurs que lcm_test_actions : 10 en normal, 15 en critique.
E.Set_Value(moi, "force", 4)
E.Set_Value(moi, "perception", 3)
E.Set_Value(moi, "pen_tranchant", 2)
E.Set_Value(moi, "pen_feu", 4)
E.Set_Value(moi, "meca_attaque_simple", 2)

dire("== la regle")
attendu("plein coup : rien ne change", A.Retenir(10, 100), 10)
attendu("60 % de 10", A.Retenir(10, 60), 6)
attendu("arrondi au superieur", A.Retenir(15, 55), 9)
attendu("jamais sous 1", A.Retenir(10, 0), 1)
attendu("un zero reste zero", A.Retenir(0, 50), 0)

local function Etapes(bouton)
    local etapes = {}
    for _, feuille in ipairs(LCM.ActionsBoutons.DuBouton(bouton).feuilles or {}) do
        for _, e in ipairs(feuille.etapes or {}) do etapes[#etapes + 1] = e end
    end
    return { etapes = etapes }
end
attendu("l'attaque se retient", A.Retenable(Etapes("attaque_simple")), true)
attendu("le perce-armure aussi", A.Retenable(Etapes("perce_armure")), true)
attendu("le brise-armure aussi", A.Retenable(Etapes("brise_armure")), true)
attendu("un bouclier non : il n'a pas de critique", A.Retenable(Etapes("generation_bouclier")), false)

dire("== la jauge n'apparait qu'a la fin")
local R = LCM.UI.Radial
local f
local function choisir(libelle)
    for _, b in ipairs(f.boutons) do
        if b:IsShown() and b.o and b.o.label == libelle then b:Click() return true end
    end
    for _, c in ipairs(f.cases) do
        if c:IsShown() and c.o and c.o.label == libelle then c:Click() return true end
    end
    return false
end
local function Composer()
    R.Trouver("attaque_simple").onClick()
    f = LCM.UI.Composeur.frame
    choisir("Corps a corps") f.suivant:Click() choisir("CaC puissant") f.suivant:Click()
    choisir("Rand Adresse") f.suivant:Click() choisir("Brutale (Force)") f.suivant:Click()
    choisir("Tranchant") f.suivant:Click() choisir("Feu") f.suivant:Click()
    choisir("Monocible")
end
Composer()
local hauteur = f:GetHeight()
attendu("pendant les questions : pas de jauge", f.retenue:IsShown(), false)
f.suivant:Click()
attendu("ecran de fin", f.declarer:IsShown(), true)
attendu("a la fin : la jauge", f.retenue:IsShown(), true)
attendu("la fenetre grandit pour elle", f:GetHeight(), hauteur + 26)
attendu("le corps garde sa place", select(5, f.principal:GetPoint(2)), 88 + 26)
attendu("on part du plein coup", f.retenue.libelle:GetText():find("100 %", 1, true) ~= nil, true)
attendu("curseur au bout", f.retenue.curseur.valeur, 20)
attendu("degat normal plein", f.resultats[1].valeur:GetText(), "10")

dire("== baisser son coup")
f.retenue.curseur:Aller(12)   -- 12 pas de 5 % : 60 %
attendu("le libelle suit", f.retenue.libelle:GetText():find("60 %", 1, true) ~= nil, true)
attendu("normal retenu, plein coup a cote", __sansCouleur(f.resultats[1].valeur:GetText()), "6  / 10")
attendu("critique retenu", __sansCouleur(f.resultats[2].valeur:GetText()), "9  / 15")
attendu("le perce-armure suit le coup retenu",
    __sansCouleur(f.resultats[3].valeur:GetText()):find("^1 / 1") ~= nil, true)

dire("== revenir en arriere cache la jauge, revenir la remet")
f.precedent:Click()
attendu("questions : pas de jauge", f.retenue:IsShown(), false)
attendu("la fenetre reprend sa taille", f:GetHeight(), hauteur)
f.suivant:Click()
attendu("la retenue est gardee", f.retenue.curseur.valeur, 12)

dire("== la declaration part retenue")
__groupe({ "Reika-Apertus", "Nytherah-Apertus" })
f.declarer:Click()
local C = LCM.UI.Resolution.cibles
LCM.Reseau.Recevoir("Nytherah-Apertus", "1:1:1:ici|" .. LCM.Reseau.Encoder({ v = "0.1.0" }))
C.joueurs.lignes[2]:Click()
C.declarer:Click()
attendu("Total Normal retenu", aDit("Total Normal : 6"), true)
attendu("Total Critique retenu", aDit("Total Critique : 9"), true)

dire("== une nouvelle attaque repart du plein coup")
Composer()
f.suivant:Click()
attendu("curseur au bout", f.retenue.curseur.valeur, 20)
attendu("degat plein", f.resultats[1].valeur:GetText(), "10")
f:Hide()
__groupe({})

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
