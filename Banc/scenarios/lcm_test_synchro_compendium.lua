-- La synchronisation forcee, depuis le COMPENDIUM (le MJ, 3 novembre 2026 :
-- « parfois les data mettent du temps a arriver »). Le geste est celui du
-- Panel MJ (Core/Synchro.lua) ; ce qui est neuf, c'est le FLUX visible : le
-- bouton suit la file d'envoi etalee jusqu'au bout, et ne se reclique pas
-- pendant ce temps.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__groupe({ "Binome-Apertus", "Joueur-Apertus" })
__declencher("PLAYER_LOGIN")
__personnage()

local R, S = LCM.Reseau, LCM.Synchro
local F = LCM.UI.Compendium
LCM.UI.Menu.Trouver("systeme_aelskar").onClick()
local f = F.frame

dire("== le bouton, dans la rangée d'actions du MJ")
attendu("il existe", f.synchroniser ~= nil, true)
attendu("  visible chez le MJ", f.synchroniser:IsShown(), true)
attendu("  il dit ce qu'il fait", f.synchroniser.label:GetText(), "Synchroniser")
attendu("aucune synchro encore", S.Progression(), nil)

dire("== cliquer : le flux se montre")
-- De quoi remplir la file au-dela d'une rafale : une liste de base qui pese
-- plusieurs morceaux suffit d'ordinaire, mais on ne se pose pas sur le
-- contenu de la campagne — on charge la file nous-memes.
R.Envoyer("essai_flux", { corps = string.rep("x", 6000) }, "RAID", nil, { etale = true })
local enFile = R.FileEnvoi()
attendu("la file est chargée avant le clic", enFile > 0, true)
f.synchroniser:Click()
local p = S.Progression()
attendu("une synchro est suivie", p ~= nil, true)
attendu("  pas finie : la file coule encore", p and p.fini, false)
attendu("  le total compte ce qui attend", p and p.total >= enFile, true)
attendu("le bouton montre le flux", (f.synchroniser.label:GetText():match("^Synchro %d+/%d+$")) ~= nil, true)
attendu("  et ne se reclique pas", f.synchroniser:IsEnabled(), false)

dire("== un second clic pendant le flux ne relance rien")
local avant = R.Expedies() + R.FileEnvoi()
f:Synchroniser()
attendu("rien de plus en file", R.Expedies() + R.FileEnvoi(), avant)

dire("== la file se vide, puis le calme")
__avancer(60)
attendu("la file est vide", R.FileEnvoi(), 0)
p = S.Progression()
attendu("  mais pas encore « finie » : une réclamation peut arriver", p.fini, false)
attendu("  tout est compté comme envoyé", p.envoyes, p.total)
__avancerTemps(S.CALME + 1)
__avancer(0.5)
attendu("finie après le calme", S.Progression().fini, true)
attendu("le bouton redevient lui-même", f.synchroniser.label:GetText(), "Synchroniser")
attendu("  et recliquable", f.synchroniser:IsEnabled(), true)
attendu("le message dit la fin", (f.message:GetText():match("^Synchronisation terminée")) ~= nil, true)

dire("== seul, personne à joindre")
__groupe({})
local canal = LCM.Presence.Canal
LCM.Presence.Canal = function() return nil end
f.synchroniser:Click()
attendu("pas de flux à suivre", S.Progression(), nil)
attendu("le message le dit", f.message:GetText(), "Synchronisation : personne à joindre.")
LCM.Presence.Canal = canal

dire("== chez un joueur, pas de bouton")
local estMJ = LCM.IsMaster
LCM.IsMaster = function() return false end
f:Rafraichir()
attendu("caché", f.synchroniser:IsShown(), false)
LCM.IsMaster = estMJ

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
