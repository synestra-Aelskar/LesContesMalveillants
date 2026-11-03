-- La fleche des difficultes, sur le panneau MJ compact (le MJ, 3 novembre
-- 2026 : « avoir les difficultes faciles a ouvrir a tout moment »). Un clic
-- deplie les DD le long du bord ; on glisse la fleche autour du cadre. Sur
-- un cote : 3 colonnes ; en haut ou en bas : 3 lignes.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__groupe({ "Blud-Apertus", "Nytherah-Apertus" })
__declencher("PLAYER_LOGIN")
__personnage()
local D = LCM.Difficultes
-- Douze difficultes TEMOINS : celles de la campagne bougent a chaque seance.
-- Douze, pas sept : a 3 x 3 une bande compacte est presque carree, et le
-- test ne verrait pas si elle s'allonge bien le long du cadre.
for _, d in ipairs(D.Liste()) do D.Retirer(d.valeur) end
for i = 1, 12 do D.Definir(3 * i, math.min(math.ceil(i / 2), #D.Couleurs())) end
attendu("douze difficultés témoins", #D.Liste(), 12)
LCM.EnsureDatabase()
LCM.db.flecheDifficultes = nil

local Ecran = LCM.UI.PanneauMJ
local c = Ecran.Compact()
c:Montrer("joueurs")
local f, p = c.flecheDifficultes, c.difficultesRapides

dire("== la flèche, à gauche par défaut")
attendu("elle existe", f ~= nil and f:IsShown(), true)
attendu("  à gauche", f.cote, "gauche")
local point, relatif, relPoint = f:GetPoint(1)
attendu("  collée au bord gauche du cadre", point == "RIGHT" and relatif == c and relPoint == "TOPLEFT", true)
attendu("  verticale", f:GetHeight() > f:GetWidth(), true)
attendu("  elle montre vers le dehors", f.sens, "gauche")
attendu("le panneau est fermé", p:IsShown(), false)

dire("== un clic ouvre, à gauche : 3 colonnes")
f:Click()
attendu("ouvert", p:IsShown(), true)
-- Centre sur la fleche (le MJ, 3 novembre 2026 : « le centre du truc doit
-- etre la fleche »).
local pt, rel, relPt = p:GetPoint(1)
attendu("  centré sur la flèche, à sa gauche", pt == "RIGHT" and rel == f and relPt == "LEFT", true)
attendu("  3 colonnes", p.colonnes, 3)
attendu("  et les lignes qu'il faut", p.lignes, 4)
attendu("  la flèche se retourne vers le cadre", f.sens, "droite")
local k = p.cases[1]
attendu("la première case montre son DD", k.valeur:GetText(), "3")
attendu("  des chiffres seulement : pas de nom", k.nom, nil)
attendu("sur un côté, la bande est plus haute que large", p:GetHeight() > p:GetWidth(), true)
attendu("  dans sa couleur", k.difficulte.nom ~= nil, true)
attendu("la quatrième passe à la ligne", p.cases[4].colonne .. "," .. p.cases[4].ligne, "0,1")

dire("== glissée en haut : 3 lignes")
f:Deposer("haut", 0.3)
attendu("la flèche est en haut", f.cote, "haut")
point, relatif, relPoint = f:GetPoint(1)
attendu("  collée au bord du haut", point == "BOTTOM" and relPoint == "TOPLEFT", true)
attendu("  horizontale", f:GetWidth() > f:GetHeight(), true)
pt, rel, relPt = p:GetPoint(1)
attendu("le panneau s'ouvre au-dessus, centré sur elle", pt == "BOTTOM" and rel == f and relPt == "TOP", true)
attendu("  3 lignes", p.lignes, 3)
attendu("  les colonnes qu'il faut", p.colonnes, 4)
attendu("la quatrième passe à la colonne suivante", p.cases[4].colonne .. "," .. p.cases[4].ligne, "1,0")
attendu("en haut, la bande est plus large que haute", p:GetWidth() > p:GetHeight(), true)
attendu("la place est retenue", LCM.db.flecheDifficultes and LCM.db.flecheDifficultes.cote, "haut")

dire("== à droite, en bas")
f:Deposer("droite", 0.5)
attendu("à droite : le panneau à droite", select(1, p:GetPoint(1)), "LEFT")
attendu("  3 colonnes", p.colonnes, 3)
f:Deposer("bas", 0.5)
attendu("en bas : le panneau dessous", select(1, p:GetPoint(1)), "TOP")
attendu("  3 lignes", p.lignes, 3)

dire("== la souris choisit le bord le plus proche")
-- Un cadre de 0 a 480 de large, de 0 a 380 de haut.
local function bord(x, y) return (Ecran.BordLePlusProche(x, y, 0, 480, 380, 0)) end
attendu("près du bord gauche", bord(5, 200), "gauche")
attendu("dehors, à droite", bord(600, 190), "droite")
attendu("au-dessus", bord(240, 450), "haut")
attendu("en dessous", bord(240, -40), "bas")
local _, pos = Ecran.BordLePlusProche(-30, 380, 0, 480, 380, 0)
attendu("pas dans le coin : la place est bornée", pos, 0.08)

dire("== revenue à sa place par défaut : la préférence s'efface")
f:Deposer("gauche", 0.5)
attendu("rien en sauvegarde", LCM.db.flecheDifficultes, nil)
f:Click()
attendu("un second clic referme", p:IsShown(), false)
attendu("  et la flèche remontre le dehors", f.sens, "gauche")

dire("== le glisser suit dès l'appui")
f:Click()
attendu("ouvert avant le geste", p:IsShown(), true)
__curseur = { 100, 100 }
__souris = __souris or {}
__souris.LeftButton = true
f:GetScript("OnMouseDown")(f, "LeftButton")
__curseur = { 102, 101 }
__avancer(0.1)
attendu("sous le seuil : pas encore un glisser", f.aBouge, false)
__curseur = { 160, 100 }
__avancer(0.1)
attendu("au-delà : ça glisse", f.aBouge, true)
attendu("  le panneau se cache pendant le geste", p:IsShown(), false)
__souris.LeftButton = false
__avancer(0.1)
attendu("lâché : le panneau revient", p:IsShown(), true)
f:Click()
attendu("  et le clic du lâcher n'ouvre ni ne ferme rien", p:IsShown(), true)
f:Click()

dire("== cliquer une difficulté : une épreuve en MP aux joueurs cochés")
-- Le MJ : « tu coches Blud, tu cliques 15, tu choisis l'expertise, et ca
-- lui part en MP ». Les PF (fatigue) sont fixes par le MJ, dans un encart ;
-- le « NF » calcule du premier essai a ete retire.
if not p:IsShown() then f:Click() end
attendu("le message, avec la fatigue", Ecran.MessageEpreuve(3, "Crochetage", 5), "DD - 3 [Crochetage] - Fatigue : 5 PF")
attendu("  sans PF, il n'en parle pas", Ecran.MessageEpreuve(36, "Vue"), "DD - 36 [Vue]")
attendu("  0 PF non plus", Ecran.MessageEpreuve(36, "Vue", 0), "DD - 36 [Vue]")
attendu("plus de NF", Ecran.NoFatigue, nil)
local groupe = Ecran.Fenetre().pages.joueurs
-- Personne de coche : TOUT le groupe (le MJ, 3 novembre 2026), sauf soi.
groupe.selection = {}
local avant = #__chats
p.cases[1]:Click()
local choix = p.choixEpreuve
attendu("le micro-panneau s'ouvre aussi sans coche", choix ~= nil and choix:IsShown(), true)
attendu("  avec l'encart des PF", p.encartPF ~= nil and p.encartPF:IsShown(), true)
attendu("  vide par défaut", p.encartPF.saisie:GetText(), "")
attendu("  assez grand pour se lire", p.encartPF:GetHeight() >= 30, true)
-- Les categories en accordeon, FERMEES a l'ouverture (le MJ, 3 novembre 2026).
local function lignesVisibles()
    local n = 0
    for _, l in ipairs(choix.lignes) do if l:IsShown() then n = n + 1 end end
    return n
end
attendu("le choix est en accordéon", choix.accordeon, true)
attendu("  tout fermé à l'ouverture", lignesVisibles(), 0)
local entetes = 0
for _, t in ipairs(choix.entetes) do if t:IsShown() then entetes = entetes + 1 end end
attendu("  une catégorie par en-tête (statistiques + domaines d'expertise)", entetes >= 2, true)
local function toutOuvrir()
    for _, t in ipairs(choix.entetes) do if t:IsShown() and not t.ouvert then t:Click() end end
end
toutOuvrir()
attendu("ouvertes : les entrées se voient", lignesVisibles() > 6, true)
local epais, fins = 0, 0
for _, f in ipairs(choix.filets) do
    if f:IsShown() then if f:GetHeight() >= 2 then epais = epais + 1 else fins = fins + 1 end end
end
attendu("  un gros filet entre deux catégories", epais, entetes - 1)
attendu("  un petit entre deux entrées", fins > 0, true)
for _, l in ipairs(choix.lignes) do if l:IsShown() and l.choix == "vue" then l:Click() break end end
local tous = {}
for i = avant + 1, #__chats do tous[#tous + 1] = __chats[i].cible end
table.sort(tous)
attendu("personne de coché : tout le groupe, sauf moi", table.concat(tous, ","), "Blud-Apertus,Nytherah-Apertus")
avant = #__chats
groupe.selection["Blud-Apertus"] = true
groupe.selection["Nytherah-Apertus"] = true
p.cases[1]:Click()
attendu("le micro-panneau s'ouvre", choix ~= nil and choix:IsShown(), true)
p.encartPF.saisie:Saisir("5")
toutOuvrir()
local vus = {}
for _, l in ipairs(choix.lignes) do if l:IsShown() and l.choix then vus[l.choix] = true end end
attendu("  il propose les statistiques", vus.force == true and vus.adresse == true, true)
attendu("  et les expertises", vus.crochetage == true and vus.vue == true, true)
local secondaire = false
for _, pool in ipairs(LCM.Equilibrage.secondaires) do if vus[pool.id] then secondaire = true end end
attendu("  pas les points secondaires (vitalité, fatigue, PA...)", secondaire, false)
attendu("  plus de « Autre… »", vus.__autre, nil)
for _, l in ipairs(choix.lignes) do if l:IsShown() and l.choix == "crochetage" then l:Click() break end end
local recus = {}
for i = avant + 1, #__chats do
    local m = __chats[i]
    if m.canal == "WHISPER" then recus[#recus + 1] = m.cible .. "=" .. m.texte end
end
table.sort(recus)
attendu("un MP à chacun", table.concat(recus, " | "),
    "Blud-Apertus=DD - 3 [Crochetage] - Fatigue : 5 PF | Nytherah-Apertus=DD - 3 [Crochetage] - Fatigue : 5 PF")
attendu("l'encart se ferme avec la liste", p.encartPF:IsShown(), false)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
