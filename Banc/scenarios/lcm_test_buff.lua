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
__personnage()   -- ce scenario joue un personnage : il le dit
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
-- Elle s'ouvre REPLIEE depuis le 3 octobre 2026 : on ne deroule quatre-vingts
-- champs que si on compose vraiment. Tout ce qui suit a besoin du depliage.
attendu("repliee a l'ouverture", K.replie, true)
attendu("et le bouton le propose", K.basculer.label:GetText(), "Configurer")
K.basculer:Click()
attendu("depliee", K.replie, false)
attendu("le bouton propose de refermer", K.basculer.label:GetText(), "Réduire")
attendu("rien a depenser sans choix", K.constructeur:Reserve(), 0)
attendu("on ne declare pas sans points", K.declarer:IsEnabled(), false)
choisir("Force") choisir("Esprit") choisir("Niveau 2") choisir("Feu") choisir("Monocible") choisir("Sans stack")
local reserve = K.constructeur:Reserve()
attendu("la reserve suit les choix", reserve > 0, true)
attendu("elle s'affiche", K.reserve:GetText():find("/ " .. reserve, 1, true) ~= nil, true)
attendu("les familles sont repliees", ligne("force"), nil)
-- 3 octobre 2026 : les familles portent le nom de la FICHE (onglet + section)
-- et non plus leur prix (« Cout 3 »), qui ne disait pas ce qu'on achetait.
local noms = {}
for _, e in ipairs(K.entetes) do if e:IsShown() then noms[#noms + 1] = e.libelle end end
attendu("groupees par sens", noms[1] and noms[1]:find("Cout") == nil, true)
attendu("penetrations et resistances se distinguent",
    (table.concat(noms, "|"):find("Pénétrations — Élémentaires", 1, true) ~= nil)
    and (table.concat(noms, "|"):find("Résistances — Élémentaires", 1, true) ~= nil), true)
-- La jumelle de l'autre mode n'est plus proposee : on voyait DEUX « Durée »
-- et DEUX « Puissance » en construisant un buff.
local dureesVisibles = 0
for _, fam in ipairs(K.constructeur.familles) do
    for _, ch in ipairs(fam.champs) do
        if ch.id == "duree_buff" or ch.id == "duree_debuff" then dureesVisibles = dureesVisibles + 1 end
    end
end
attendu("une seule duree", dureesVisibles, 1)

-- 3 octobre 2026 : on choisit D'ABORD ou l'effet atterrit dans la fenetre
-- Sante — Etat, Maladie ou Intangible. Sans ce choix tout tombait dans
-- « Etats », et une maladie se lisait au milieu des immobilisations.
attendu("trois natures proposees", #K.conteneurs, 3)
attendu("« Etat » par defaut", K.constructeur.conteneur, "etat")
local function nature(id)
    for _, b in ipairs(K.conteneurs) do if b.conteneurId == id then return b end end
end
attendu("les trois sont la",
    nature("etat") ~= nil and nature("maladie") ~= nil and nature("intangible") ~= nil, true)
nature("maladie"):Click()
attendu("on choisit Maladie", K.constructeur.conteneur, "maladie")

-- L'habillage repris de Necronicon (3 octobre 2026).
attendu("la description a une vraie boite", K.desc:GetHeight() > 60, true)
attendu("l'icone se choisit au clic", type(K.iconeBouton:GetScript("OnClick")), "function")
attendu("les reserves sont deux carres", K.carrePA ~= nil and K.carrePF ~= nil, true)
attendu("PA et PF sont colles", (select(2, K.carrePF:GetPoint(1))), K.carrePA)

-- La rangee du haut tient en trois bandes qui ne se recouvrent pas :
-- bibliotheque + « Configurer », puis les carres PA/PF, puis la liste de choix.
-- « Configurer » etait une ligne plus bas et tombait sur « Déclarer » quand la
-- fenetre etait repliee (son etat de depart) ; les carres, eux, etaient poses
-- DANS la zone de choix et recouvraient sa premiere rangee (5 octobre 2026).
local function bas(region)
    local _, _, _, _, y = region:GetPoint(1)
    return y - region:GetHeight()
end
-- K.biblio est ancre a son libelle (decalage 0) : c'est le libelle qui porte
-- l'ordonnee de la rangee.
local _, _, _, _, yBiblio = K.biblioLibelle:GetPoint(1)
local _, _, _, _, yBascule = K.basculer:GetPoint(1)
attendu("« Configurer » est sur la rangee de la bibliotheque", yBascule, yBiblio)
local _, _, _, _, yCarre = K.carrePA:GetPoint(1)
local _, _, _, _, yChoix = K.choix:GetPoint(1)
attendu("les carres passent sous la bibliotheque", yCarre <= bas(K.basculer), true)
attendu("et s'arretent avant la liste de choix", bas(K.carrePA) >= yChoix, true)
attendu("ils restent dans la largeur de la liste",
    K.carrePA:GetWidth() + K.carrePF:GetWidth() < K:GetWidth() / 2, true)
-- Une option payante porte son prix en carres, plus entre parentheses.
local payante
for _, b in ipairs(K.options) do
    if b:IsShown() and (b.o.pa ~= 0 or b.o.pf ~= 0) then payante = b break end
end
if payante then
    attendu("le prix n'est plus dans le libelle", payante.label:GetText():find("PA") == nil, true)
    attendu("il est dans un carre", payante.pa:IsShown() or payante.pf:IsShown(), true)
end
famille("Statistiques"):Click()
attendu("une famille s'ouvre", ligne("force") ~= nil, true)
ligne("force").plus:Click()
attendu("un point en Force", K.constructeur.points.force, 1)
attendu("l'apercu le dit", K.effetsApercu:GetText(), "Force +1")
famille("Pénétrations — Élémentaires"):Click()
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
K.basculer:Click()
choisir("Force") choisir("Esprit") choisir("Niveau 6") choisir("Monocible") choisir("Sans stack")
famille("Statistiques"):Click()
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

dire("== l'effet atterrit dans le volet choisi")
-- Le personnage porte deja ce que le scenario lui a pose : on compte des
-- ECARTS, pas des totaux.
local T = LCM.EtatsTemporaires
local function compte(volet) return #T.Liste(moi, volet) end
local m0, e0, i0, tout0 = compte("maladie"), compte("etat"), compte("intangible"), #T.Liste(moi)
T.Poser(moi, { nom = "Fièvre", conteneur = "maladie", bonus = {}, rounds = 3 })
T.Poser(moi, { nom = "Immobilisé", bonus = {}, rounds = 2 })
attendu("la maladie va dans Maladies", compte("maladie") - m0, 1)
attendu("et pas dans Etats", compte("etat") - e0, 1)
attendu("rien en Intangible", compte("intangible") - i0, 0)
attendu("la liste entiere les a tous", #T.Liste(moi) - tout0, 2)
local trouveeM, trouveeE = false, false
for _, e in ipairs(T.Liste(moi, "maladie")) do if e.nom == "Fièvre" then trouveeM = true end end
for _, e in ipairs(T.Liste(moi, "etat")) do if e.nom == "Immobilisé" then trouveeE = true end end
attendu("la fievre est bien rangee en maladie", trouveeM, true)
attendu("un etat sans nature compte comme Etat", trouveeE, true)

dire("== la bibliotheque : enregistrer et recharger")
LCM.UI.Radial.Trouver("generation_buff").onClick()
K = LCM.UI.Constructeur.frame
K.basculer:Click()
choisir("Force") choisir("Esprit") choisir("Niveau 2") choisir("Monocible") choisir("Sans stack")
nature("intangible"):Click()
famille("Statistiques"):Click()
ligne("force").plus:Click()
ligne("force").plus:Click()
K.nom:SetText("Vigueur")
K.desc:SetText("Le souffle qui ne manque pas.")
-- Ce que la reserve a laisse passer : on ne decide pas a sa place.
local pointsAvant = K.constructeur.points.force
attendu("au moins un point place", (pointsAvant or 0) >= 1, true)
attendu("enregistre", select(1, K.constructeur:Enregistrer("Vigueur", "Le souffle qui ne manque pas.", nil)), true)

local modeles = LCM.Actions.ModelesPour(K.constructeur)
attendu("un modele en bibliotheque", #modeles, 1)
attendu("sous son nom", modeles[1].nom, "Vigueur")
attendu("il retient la nature", modeles[1].conteneur, "intangible")
attendu("et les points", modeles[1].points.force, pointsAvant)
attendu("un buff n'est pas range avec les debuffs", modeles[1].debuff, false)

-- Enregistrer deux fois le meme nom corrige, n'empile pas.
K.constructeur:Enregistrer("Vigueur", "Autre texte.", nil)
attendu("toujours un seul", #LCM.Actions.ModelesPour(K.constructeur), 1)
attendu("et c'est la nouvelle version", LCM.Actions.ModelesPour(K.constructeur)[1].description, "Autre texte.")

-- Recharger sur un constructeur neuf.
K:Hide()
LCM.UI.Radial.Trouver("generation_buff").onClick()
K = LCM.UI.Constructeur.frame
K.basculer:Click()
attendu("rien de place au depart", K.constructeur.points.force, nil)
attendu("rechargé", select(1, K.constructeur:Charger(LCM.Actions.ModelesPour(K.constructeur)[1])), true)
attendu("les points sont revenus", K.constructeur.points.force, pointsAvant)
attendu("la nature aussi", K.constructeur.conteneur, "intangible")
attendu("et les reponses du composeur", K.constructeur.composeur.reponses ~= nil, true)
K:Hide()

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
