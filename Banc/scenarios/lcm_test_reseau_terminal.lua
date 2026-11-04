-- Le terminal du reseau, onglet « Réseau » du Panel MJ (le MJ, 3 novembre
-- 2026 : « un lecteur de reseau qui catch toutes les communications [...]
-- simule un terminal de commande [...] qui provoque, quoi, et a quelle
-- heure, heure locale »).
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
__groupe({ "Nytherah-Apertus" })
local R = LCM.Reseau
R.ViderJournal()

dire("== l'onglet")
local f = LCM.UI.PanneauMJ.Basculer()
local entree
for _, b in ipairs(f.barre.boutons) do if b.ongletId == "reseau" then entree = b end end
attendu("« Réseau » est dans la navigation", entree ~= nil, true)
entree:Click()
local page = f.pages.reseau
attendu("la page s'ouvre", page:IsVisible(), true)
-- Ouvrir le panneau a deja parle (il va chercher les fiches du groupe) : on
-- repart d'un journal vide pour lire l'ecran au repos.
R.ViderJournal()
page:Afficher()
attendu("vide, il le dit", __sansCouleur(page.texte:GetText()):find("en écoute", 1, true) ~= nil, true)

dire("== une ligne par message envoyé : heure, source, quoi")
R.Envoyer("base_liste", { corps = "x" }, "WHISPER", "Nytherah-Apertus")
__avancer(1)
local texte = __sansCouleur(page.texte:GetText())
local ligne = texte:match("[^\n]*base publique[^\n]*")
attendu("la ligne existe", ligne ~= nil, true)
attendu("  l'heure locale, entre crochets", ligne and ligne:match("^%[%d%d:%d%d:%d%d%]") ~= nil, true)
attendu("  la source : le compendium", ligne and ligne:find("[Compendium]", 1, true) ~= nil, true)
attendu("  vers qui", ligne and ligne:find("moi → Nytherah", 1, true) ~= nil, true)
attendu("  et son état", ligne and ligne:find("parti", 1, true) ~= nil, true)

dire("== une ligne par message reçu : la source, c'est le joueur")
R.Recevoir("Nytherah-Apertus", "5:1:1:fiche-|", "WHISPER")
__avancer(1)
texte = __sansCouleur(page.texte:GetText())
ligne = texte:match("[^\n]*%[Nytherah%][^\n]*")
attendu("le joueur est la source", ligne ~= nil, true)
attendu("  et le quoi est dit", ligne and ligne:find("fiche du personnage", 1, true) ~= nil, true)

dire("== un refus du jeu se voit, puis le départ")
__refuserEnvois(1)
R.Envoyer("etat_mj", { i = "x" }, "WHISPER", "Nytherah-Apertus")
__avancer(0.6)
texte = __sansCouleur(page.texte:GetText())
attendu("freiné, à l'écran", texte:find("freiné", 1, true) ~= nil, true)
__avancer(3)
texte = __sansCouleur(page.texte:GetText())
ligne = texte:match("[^\n]*état imposé[^\n]*")
attendu("  puis parti, sur la même ligne", ligne and ligne:find("parti", 1, true) ~= nil, true)
page.problemes:Click()
__avancer(1)
texte = __sansCouleur(page.texte:GetText())
attendu("« Problèmes » garde la ligne qui a été freinée", texte:find("état imposé", 1, true) ~= nil, true)
attendu("  et cache le reste", texte:find("base publique", 1, true), nil)
page.problemes:Click()

dire("== Crossings : une seule ligne pour un état en morceaux")
local avant = #R.Journal()
R.EnvoyerBrut("LCMCrossings", { "Z|7|1|3|aa", "Z|7|2|3|bb", "Z|7|3|3|cc" }, "WHISPER", "Nytherah-Apertus")
attendu("une ligne, pas trois", #R.Journal() - avant, 1)
attendu("  nommée", R.Journal()[#R.Journal()].sujet, "Crossings : état des zones")
for i = 1, 3 do
    __declencher("CHAT_MSG_ADDON", "LCMCrossings", string.format("Z|9|%d|3|x", i), "WHISPER", "Nytherah-Apertus")
end
local recus = 0
for i = avant + 2, #R.Journal() do
    if R.Journal()[i].sens == "reception" and R.Journal()[i].sujet == "Crossings : état des zones" then recus = recus + 1 end
end
attendu("en réception aussi, une ligne", recus, 1)

dire("== figer, effacer")
page.pause:Click()
local fige = page.texte:GetText()
R.Envoyer("ici", {}, "WHISPER", "Nytherah-Apertus")
__avancer(1)
attendu("figé : l'écran ne bouge plus", page.texte:GetText(), fige)
page.pause:Click()
__avancer(1)
attendu("repris : la ligne arrivée entre-temps est là", __sansCouleur(page.texte:GetText()):find("présence", 1, true) ~= nil, true)
page.effacer:Click()
attendu("effacé", #R.Journal(), 0)

dire("== le journal reste en mémoire et borné")
for i = 1, R.JOURNAL_MAX + 20 do R.Recevoir("Nytherah-Apertus", string.format("%d:1:1:ici|", 100 + i), "WHISPER") end
attendu("jamais plus de JOURNAL_MAX lignes", #R.Journal(), R.JOURNAL_MAX)
page:Afficher()
attendu("le journal est découpé en blocs courts", #page.blocs > 1, true)
attendu("le dernier bloc contient le message récent",
    __sansCouleur(page.blocs[#page.blocs]:GetText()):find("présence", 1, true) ~= nil, true)
attendu("le bas du défilement correspond au contenu mesuré",
    page.zone.decalage, math.max(0, page.zone.hauteurContenu - page.zone:GetHeight()))
attendu("rien en sauvegarde", LCM.db.reseau == nil and (LCM_MJ_DB == nil or LCM_MJ_DB.reseau == nil), true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
