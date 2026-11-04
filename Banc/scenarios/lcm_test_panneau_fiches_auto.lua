-- La page Groupe du Panel MJ va chercher les fiches d'elle-meme (le MJ,
-- 3 novembre 2026 : « on a du mal a catch les data des fiches des gens
-- connectes » — la ligne disait « fiche pas encore consultee » tant que
-- personne n'avait clique Consulter). Et poser un etat envoie l'etat AVANT
-- de redemander la fiche : dans l'autre ordre, le joueur repondait sans lui,
-- et il fallait passer sur un autre joueur puis revenir pour le voir.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
-- Le personnage du banc s'appelle Reika : les joueurs d'essai sont d'autres.
__groupe({ "Nytherah-Apertus", "Blud-Apertus" })

local R = LCM.Reseau
local envois = {}
local envoyer = R.Envoyer
R.Envoyer = function(sujet, donnees, canal, cible, options)
    envois[#envois + 1] = { sujet = sujet, cible = cible, donnees = donnees }
    -- Rien ne part pour de vrai : au banc, un chuchotement reviendrait sur
    -- le MJ lui-meme, qui se poserait l'etat a sa place.
    if canal == "WHISPER" then return true, 1 end
    return envoyer(sujet, donnees, canal, cible, options)
end
local function demandes(cible, depuis)
    local n = 0
    for i = depuis or 1, #envois do
        if envois[i].sujet == "fiche?" and (not cible or envois[i].cible == cible) then n = n + 1 end
    end
    return n
end

dire("== ouvrir le panneau demande les fiches qui manquent")
local f = LCM.UI.PanneauMJ.Basculer()
f:Onglet("joueurs")
attendu("Nytherah est demandée", demandes("Nytherah-Apertus") >= 1, true)
attendu("Blud aussi", demandes("Blud-Apertus") >= 1, true)
attendu("pas soi-même", demandes(LCM.PlayerId()), 0)

dire("== pas en boucle")
local avant = #envois
f:Afficher()
f:Afficher()
attendu("réafficher ne redemande pas tout de suite", demandes(nil, avant + 1), 0)
__avancerTemps(31)
f:Afficher()
attendu("sans réponse, on relance après un délai", demandes("Nytherah-Apertus", avant + 1), 1)

dire("== la réponse remplit la ligne, sans ouvrir de fenêtre")
local moi = LCM.Entities.Personnage()
local paquet = LCM.Fiches.Paquet(moi)
local charge = "fiche|" .. R.Encoder(paquet)
local morceaux = R.Decouper(charge, R.UTILE - 20)
for i, m in ipairs(morceaux) do
    R.Recevoir("Nytherah-Apertus", string.format("%d:%d:%d:%s", 700, i, #morceaux, m), "WHISPER")
end
local ligne
for _, l in ipairs(f.pages.joueurs.lignes) do
    if l:IsShown() and l.joueur == "Nytherah-Apertus" then ligne = l end
end
attendu("la ligne montre le niveau", (ligne.detail:GetText():match("^niv%. %d+")) ~= nil, true)
local consultation = LCM.UI.Consultation or (LCM.MJ and LCM.MJ.Consultation)
local fenetre = consultation and consultation.fenetre
attendu("aucune consultation ouverte", fenetre == nil or not fenetre:IsShown(), true)
avant = #envois
__avancerTemps(31)
f:Afficher()
attendu("une fiche reçue ne se redemande pas", demandes("Nytherah-Apertus", avant + 1), 0)

dire("== poser un état : l'état part AVANT la demande de fiche")
local def = { id = "etat_fiches_auto", label = "Essai fiches", categorie = "etat", bonus = {} }
LCM.Etats.Add(def)
local p = f.pages.etats
avant = #envois
p:Appliquer("Nytherah-Apertus", def)
local ordre = {}
for i = avant + 1, #envois do
    if envois[i].sujet == "etat_mj" or envois[i].sujet == "fiche?" then ordre[#ordre + 1] = envois[i].sujet end
end
attendu("l'état, puis la fiche", table.concat(ordre, ","), "etat_mj,fiche?")

dire("== on ne reste abonné qu'au joueur qu'on regarde")
-- Abonne a tout le groupe, chaque changement d'un joueur renvoyait sa fiche
-- entiere : le reseau etait noye (le MJ, 4 novembre 2026).
local function desabonnements(cible, depuis)
    local n = 0
    for i = depuis or 1, #envois do
        if envois[i].sujet == "fiche-" and envois[i].cible == cible then n = n + 1 end
    end
    return n
end
local function recevoirFiche(joueur, numero)
    local ch = "fiche|" .. R.Encoder(LCM.Fiches.Paquet(moi))
    local mx = R.Decouper(ch, R.UTILE - 20)
    for i, m in ipairs(mx) do
        R.Recevoir(joueur, string.format("%d:%d:%d:%s", numero, i, #mx, m), "WHISPER")
    end
end
p.joueurActif = nil
LCM.Fiches.Oublier("Blud-Apertus")
__avancerTemps(31)
avant = #envois
f:Afficher()
attendu("la fiche de Blud est demandée", demandes("Blud-Apertus", avant + 1), 1)
recevoirFiche("Blud-Apertus", 800)
attendu("reçue sans qu'on le regarde : on se désabonne", desabonnements("Blud-Apertus", avant + 1), 1)
avant = #envois
p:ChoisirJoueur("Blud-Apertus")
recevoirFiche("Blud-Apertus", 801)
attendu("le joueur regardé reste suivi", desabonnements("Blud-Apertus", avant + 1), 0)
avant = #envois
p:ChoisirJoueur("Nytherah-Apertus")
attendu("en regarder un autre lâche l'ancien", desabonnements("Blud-Apertus", avant + 1), 1)

R.Envoyer = envoyer
dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
