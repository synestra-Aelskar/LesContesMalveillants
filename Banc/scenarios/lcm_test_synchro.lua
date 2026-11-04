-- La synchronisation forcee (Core/Synchro.lua, 3 novembre 2026) : un bouton
-- au pied de la navigation du Panel MJ, au-dessus de « Version compacte ».
-- Le binome s'etait connecte sans rien recevoir : le bouton renvoie les
-- reglages en cours et la file d'envoi aux autres MJ, et fait redemander a
-- tout le monde ce que la connexion demande d'habitude.
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

local R = LCM.Reseau
local envois = {}
local envoyer = R.Envoyer
R.Envoyer = function(sujet, donnees, canal, cible, options)
    envois[#envois + 1] = { sujet = sujet, donnees = donnees, canal = canal, cible = cible }
    return envoyer(sujet, donnees, canal, cible, options)
end
local function compte(sujet, depuis)
    local n = 0
    for i = depuis or 1, #envois do if envois[i].sujet == sujet then n = n + 1 end end
    return n
end

dire("== le bouton, au pied de la navigation")
local p = LCM.UI.PanneauMJ.Basculer()
attendu("il existe", p.synchroniser ~= nil, true)
attendu("  il dit ce qu'il fait", p.synchroniser.label:GetText(), "Synchroniser")
local point, relatif, relPoint = p.synchroniser:GetPoint(1)
attendu("  posé au-dessus de « Version compacte »", relatif == p.versCompact and point == "BOTTOMLEFT" and relPoint == "TOPLEFT", true)
-- Habille comme les entrees de la navigation, et « Version compacte » aussi
-- (le MJ, 3 novembre 2026 : un bouton simple detonnait sous les onglets).
attendu("  habillé en onglet", p.synchroniser.cadreOnglet ~= nil, true)
attendu("« Version compacte » aussi", p.versCompact.cadreOnglet ~= nil, true)
attendu("  à la même hauteur qu'une entrée", p.versCompact:GetHeight(), p.barre.boutons[1]:GetHeight())

dire("== cliquer : renvoyer, et faire redemander")
LCM.Reglages.Definir("pv.base", 77)
local avant = #envois
p.synchroniser:Click()
attendu("le réglage en cours repart", compte("regl", avant + 1) >= 1, true)
attendu("l'annonce part", compte("synchro!", avant + 1) >= 1, true)
-- Une empreinte commune suffit : les joueurs a jour ne demandent rien.
attendu("la version de la base est proposée à tous", compte("base=", avant + 1), 1)
local liste
for i = avant + 1, #envois do if envois[i].sujet == "base=" then liste = envois[i] end end
attendu("  sur le canal commun, pas en chuchotement", liste and liste.canal ~= "WHISPER", true)
attendu("  la liste complète ne part pas", compte("base_liste", avant + 1), 0)
attendu("le panneau de transfert s'ouvre", LCM.UI.Synchro.frame:IsShown(), true)
attendu("  avec un pourcentage", LCM.UI.Synchro.frame.pourcentage:GetText():match("^%d+ %%$") ~= nil, true)
attendu("le MJ cherche ses binômes", compte("mj-sync?", avant + 1) >= 1, true)
local chercheGroupe = false
for i = avant + 1, #envois do
    if envois[i].sujet == "mj-sync?" and envois[i].canal == "PARTY" then chercheGroupe = true end
end
attendu("il les cherche aussi dans le groupe", chercheGroupe, true)
LCM.Reglages.Retirer("pv.base")

dire("== la file d'envoi repart vers les autres MJ")
LCM.Brouillons.Set("jeux", { id = "essai_synchro", label = "Essai (synchro)", categorie = "traits",
    raretes = { { id = "libre", label = "Libre", points = 999, couleur = "FFFFFF" } } })
avant = #envois
local r = LCM.Synchro.Forcer()
attendu("l'entrée de la file est renvoyée", compte("brouillon", avant + 1) >= 1, true)
attendu("  et comptée", r.envois >= 1, true)
avant = #envois
R.Recevoir("Binome-Apertus", "905:1:1:mj-sync|", "WHISPER")
__avancer(0.6)
local direct = false
for i = avant + 1, #envois do
    if envois[i].sujet == "brouillon" and envois[i].canal == "WHISPER"
        and envois[i].cible == "Binome-Apertus" then direct = true end
end
attendu("la réponse du binôme déclenche l'envoi direct", direct, true)
LCM.Brouillons.Remove("jeux", "essai_synchro")

dire("== recevoir l'annonce")
local numero = 900
local function recevoir(expediteur, sujet, donnees)
    numero = numero + 1
    R.Recevoir(expediteur, string.format("%d:1:1:%s|%s", numero, sujet, R.Encoder(donnees or {})))
end
__avancerTemps(30)
avant = #envois
recevoir("Binome-Apertus", "synchro!", {})
attendu("un MJ relance ses propres demandes", #envois > avant, true)
avant = #envois
recevoir("Binome-Apertus", "synchro!", {})
attendu("deux annonces coup sur coup : une seule relance", #envois, avant)

print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
