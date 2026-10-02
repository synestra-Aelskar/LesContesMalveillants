-- Le soin : le composer, le repartir par zone, le declarer, le recevoir.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function recevoir(expediteur, sujet, donnees)
    return LCM.Reseau.Recevoir(expediteur, "1:1:1:" .. sujet .. "|" .. LCM.Reseau.Encoder(donnees))
end

__declencher("PLAYER_LOGIN")
local A, E, B = LCM.Actions, LCM.Entities, LCM.Body
local U = LCM.UI.Resolution
local moi = E.Self()
for _, id in ipairs({ "mystique", "constitution", "meca_soin", "pen_vie" }) do E.Set_Value(moi, id, 4) end
local function blessure(nom)
    for _, z in ipairs(B.State(moi, B.MaxTotal(moi))) do if z.label == nom then return z.wound end end
end
local tete = B.State(moi, B.MaxTotal(moi))[1]
B.Damage(moi, tete.id, 6)

dire("== composer un soin : on repond a chaque question")
LCM.UI.Radial.Trouver("generation_soin").onClick()
local f = LCM.UI.Composeur.frame
attendu("le composeur", f:IsShown() and f.titre:GetText(), "Générer un soin")
for _ = 1, 20 do
    if f.declarer:IsShown() then break end
    local fait = false
    for _, b in ipairs(f.boutons) do
        if b:IsShown() and b:IsEnabled() and not fait then
            if not f.composeur:EstChoisie(f.q, b.o.id) then b:Click() end
            fait = true
        end
    end
    for _, c in ipairs(f.cases) do
        if c:IsShown() and c:IsEnabled() and not fait then c:Click() fait = true end
    end
    f.suivant:Click()
end
attendu("on arrive a la fin", f.declarer:IsShown(), true)
local soin = tonumber(f.resultats[1].valeur:GetText())
attendu("le soin genere s'affiche", soin ~= nil and soin > 0, true)
f.declarer:Click()

dire("== repartir le soin")
local D = U.distribution
attendu("la fenetre de repartition", D:IsShown(), true)
attendu("les zones du template", table.concat(D.zones, ","), "Tête,Torse,Jambe,Bras,Internes")
attendu("on ne valide pas sans tout repartir", D.valider:IsEnabled(), false)
D.lignes[1].plus:Click()
attendu("un point en tete", D.parts["Tête"], 1)
D.lignes[3].max:Click()
attendu("le reste aux jambes", D.parts["Jambe"], D.montant - 1)
attendu("tout est reparti", D.valider:IsEnabled(), true)
D.lignes[3].zero:Click()
D.lignes[1].max:Click()
attendu("finalement tout en tete", D.parts["Tête"], D.montant)
D.valider:Click()

dire("== se cibler soi-meme, et recevoir")
local C = U.cibles
attendu("le choix des cibles", C:IsShown(), true)
C.joueurs.lignes[1]:Click()
C.declarer:Click()
attendu("on se recoit le soin", U.recu:IsShown() and U.recu.sous:GetText():find("Soin", 1, true) ~= nil, true)
U.recu.resoudre:Click()
attendu("le message", U.choix.titre:GetText(), "Soin reçu")
U.choix.boutons[1]:Click()
attendu("la tete guerit", blessure(tete.label), math.max(0, 6 - soin))

dire("== recu d'un allie : « Jambe » trouve « Jambes »")
B.HealAll(moi)
local jambes
for _, z in ipairs(B.State(moi, B.MaxTotal(moi))) do if z.label:find("Jambe") then jambes = z end end
B.Damage(moi, jambes.id, 3)
__groupe({ "Reika-Apertus", "Nytherah-Apertus" })
recevoir("Nytherah-Apertus", "act", { t = "s1", n = "Soin", a = "Nytherah-Apertus",
                                     v = { Soin = "2", ["Soin réparti"] = "Jambe=2" } })
U.recu.resoudre:Click()
U.choix.boutons[1]:Click()
attendu("les jambes guerissent de 2", blessure(jambes.label), 1)

dire("== annuler la repartition : rien n'est debite")
local pa = E.Gauge(moi, "pa").current
LCM.UI.Radial.Trouver("generation_soin").onClick()
for _ = 1, 20 do
    if f.declarer:IsShown() then break end
    local fait = false
    for _, b in ipairs(f.boutons) do
        if b:IsShown() and b:IsEnabled() and not fait then
            if not f.composeur:EstChoisie(f.q, b.o.id) then b:Click() end
            fait = true
        end
    end
    for _, c in ipairs(f.cases) do if c:IsShown() and c:IsEnabled() and not fait then c:Click() fait = true end end
    f.suivant:Click()
end
f.declarer:Click()
D.annuler:Click()
attendu("PA intacts", E.Gauge(moi, "pa").current, pa)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
