-- Le constructeur de buff / debuff, et la dissipation.
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
local function chatDit(motif)
    for i = #__chats, 1, -1 do if __chats[i].texte:find(motif, 1, true) then return __chats[i] end end
end

__declencher("PLAYER_LOGIN")
local A, E, T, F = LCM.Actions, LCM.Entities, LCM.EtatsTemporaires, LCM.Formules
local U = LCM.UI.Resolution
local moi = E.Self()
for _, id in ipairs({ "force", "mystique", "esprit", "meca_buff", "meca_debuff", "meca_dissipation", "pen_feu" }) do
    E.Set_Value(moi, id, 4)
end
E.SetGauge(moi, "pa", 10)

local K
local function choisir(libelle)
    for _, b in ipairs(K.options) do
        if b:IsShown() and b.o.label == libelle then b:Click() return true end
    end
    return false
end
local function famille(libelle)
    for _, e in ipairs(K.entetes) do if e:IsShown() and e.libelle == libelle then return e end end
end
local function ligne(champ)
    for _, l in ipairs(K.lignes) do if l:IsShown() and l.champ == champ then return l end end
end

dire("== construire un buff")
LCM.UI.Radial.Trouver("generation_buff").onClick()
K = LCM.UI.Constructeur.frame
attendu("la fenetre", K:IsShown() and K.titre:GetText(), "Construire un buff")
attendu("rien a depenser sans choix", K.constructeur:Reserve(), 0)
attendu("on ne declare pas sans points", K.declarer:IsEnabled(), false)
choisir("Force") choisir("Esprit") choisir("Niveau 2") choisir("Feu") choisir("Monocible") choisir("Sans stack")
local reserve = K.constructeur:Reserve()
attendu("la reserve suit les choix", reserve > 0, true)
attendu("elle s'affiche", K.reserve:GetText():find("/ " .. reserve, 1, true) ~= nil, true)
attendu("les familles sont repliees", ligne("force"), nil)
famille("Stat 5"):Click()
attendu("une famille s'ouvre", ligne("force") ~= nil, true)
ligne("force").plus:Click()
attendu("un point en Force", K.constructeur.points.force, 1)
attendu("l'apercu le dit", K.effetsApercu:GetText(), "Force +1")
famille("Cout 3"):Click()
attendu("le Feu choisi coute moins (0,7)", K.constructeur:Cout("pen_feu"), 3 * 0.7)
attendu("l'Eau, non", K.constructeur:Cout("pen_eau"), 3)
-- On ne depasse pas la reserve.
for _ = 1, 50 do ligne("force").plus:Click() end
attendu("jamais plus que la reserve", K.constructeur:Depense() <= reserve, true)
while K.constructeur.points.force and K.constructeur.points.force > 1 do ligne("force").moins:Click() end
K.nom:SetText("Vigueur")
K.declarer:Click()
local C = U.cibles
attendu("le choix des cibles", C:IsShown(), true)
C.joueurs.lignes[1]:Click()
local force = F.Primaire(moi, "force")
C.declarer:Click()
local R = U.effet
attendu("on recoit le buff", R:IsShown() and R.titre:GetText(), "Buff reçu")
R.boutons[1]:Click()
attendu("l'etat est pose", T.Liste(moi)[1] and T.Liste(moi)[1].nom, "Vigueur")
attendu("la Force monte", F.Primaire(moi, "force"), force + 1)
attendu("l'annonce", chatDit("lance un buff : Vigueur") ~= nil, true)

dire("== un debuff construit retire")
LCM.UI.Radial.Trouver("generation_debuff").onClick()
attendu("construire un debuff", K.titre:GetText(), "Construire un débuff")
choisir("Force") choisir("Esprit") choisir("Niveau 6") choisir("Monocible") choisir("Sans stack")
famille("Stat 5"):Click()
ligne("force").plus:Click()
attendu("l'apercu est negatif", K.effetsApercu:GetText(), "Force -1")
K.nom:SetText("Faiblesse")
K.declarer:Click()
C.joueurs.lignes[1]:Click()
C.declarer:Click()
attendu("a resister", R.titre:GetText(), "Débuff — résistance")
R.dernier:Click()
attendu("la Force baisse d'autant", F.Primaire(moi, "force"), force)

dire("== annuler le constructeur : rien n'est debite")
local pa = E.Gauge(moi, "pa").current
LCM.UI.Radial.Trouver("generation_buff").onClick()
K:Hide()
attendu("PA intacts", E.Gauge(moi, "pa").current, pa)

dire("== la dissipation : ses propres etats")
-- Les buffs ont vide les PA : sans ressources, « Dissiper » resterait grise.
E.SetGauge(moi, "pa", 10)
E.SetGauge(moi, "fatigue", 40, 40)
T.Poser(moi, { nom = "Malédiction", id = "m1", jet = { competence = "Esprit", valeur = 0 }, rounds = 3 })
LCM.UI.Radial.Trouver("dissipation").onClick()
local D = U.dissipation
attendu("la fenetre", D:IsShown(), true)
attendu("ses etats", D.casesEtats[1]:IsShown(), true)
local idx
for i, c in ipairs(D.casesEtats) do if c:IsShown() and c.etat.nom == "Malédiction" then idx = i end end
attendu("la malediction est listee", idx ~= nil, true)
attendu("pas sans competence ni niveau", D.dissiper:IsEnabled(), false)
D.casesEtats[idx]:Click()
D.competences[1]:Click()
D.niveaux[1]:Click()
attendu("une chance s'affiche", D.casesEtats[idx].label:GetText():find("100 %", 1, true) ~= nil, true)
attendu("le cout : 1 PA, 2 + 1 + 1 PF", D.cout:GetText():find("PA : 1", 1, true) ~= nil and D.cout:GetText():find("PF : 4", 1, true) ~= nil, true)
pa = E.Gauge(moi, "pa").current
D.dissiper:Click()
local reste = false
for _, e in ipairs(T.Liste(moi)) do if e.nom == "Malédiction" then reste = true end end
attendu("la malediction est dissipee", reste, false)
attendu("les PA sont payes", E.Gauge(moi, "pa").current, pa - 1)
attendu("le resultat est annonce", chatDit("Malédiction : ") ~= nil, true)

dire("== la dissipation : les etats d'un autre, demandes")
__groupe({ "Reika-Apertus", "Nytherah-Apertus" })
LCM.UI.Radial.Trouver("dissipation").onClick()
local nyt
for _, b in ipairs(D.boutonsCibles) do if b:IsShown() and b.cible.id == "Nytherah-Apertus" then nyt = b end end
local n = #__envois
nyt:Click()
attendu("on demande ses etats", __envois[n + 1] and __envois[n + 1].message:find("etats?|", 1, true) ~= nil, true)
attendu("en attendant", D.tEtats:GetText():find("demandés", 1, true) ~= nil, true)
recevoir("Nytherah-Apertus", "etats", { nb = 1, i1 = "z9", n1 = "Poison", c1 = "Adresse", s1 = 0, r1 = 2 })
attendu("ils arrivent", D.casesEtats[1]:IsShown() and D.casesEtats[1].etat.nom, "Poison")
D.casesEtats[1]:Click()
D.competences[1]:Click()
D.niveaux[1]:Click()
attendu("Esprit contre un etat d'Adresse : inadapte", D.casesEtats[1].label:GetText():find("%%", 1) ~= nil, true)
n = #__envois
D.dissiper:Click()
local envoi
for i = n + 1, #__envois do if __envois[i].message:find("dissipe|", 1, true) then envoi = __envois[i] end end
attendu("le retrait part au porteur", envoi and envoi.cible, "Nytherah-Apertus")
attendu("le jet inadapte est annonce", chatDit("[Rand Esprit inadapté]") ~= nil, true)

dire("== un etat de soi dissipe par un autre")
local function porte(nom)
    for _, e in ipairs(T.Liste(moi)) do if e.nom == nom then return true end end
    return false
end
T.Poser(moi, { nom = "Brûlure", id = "b1", rounds = 2 })
recevoir("Etranger-Apertus", "dissipe", { id = "b1" })
attendu("un etranger au groupe ne retire rien", porte("Brûlure"), true)
recevoir("Nytherah-Apertus", "dissipe", { id = "b1", nom = "Brûlure" })
attendu("un membre du groupe, si", porte("Brûlure"), false)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
