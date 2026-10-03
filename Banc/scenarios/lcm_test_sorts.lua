-- Sorts du personnage : sauvegarde, lien de chat, partage.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function dernierMessage() return __sansCouleur(__sorties[#__sorties] or "") end

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit
local S = LCM.Sorts
local moi = LCM.Entities.Self()

dire("== un sort appris")
attendu("rien au depart", S.Compte(moi), 0)
attendu("et rien en sauvegarde", moi.sorts, nil)
local sort = S.Ajouter(moi, { label = "Trait de givre", description = "Un éclat de glace.",
                              jet = { min = 1, max = 20 }, champ1 = "Mystique" })
attendu("ajoute", sort ~= nil, true)
attendu("identifiant lisible", sort.id, "trait_de_givre")
attendu("compte", S.Compte(moi), 1)
attendu("retrouve", S.Get(moi, "trait_de_givre").label, "Trait de givre")

dire("== ce qu'on refuse")
attendu("sans nom", (S.Ajouter(moi, { description = "rien" })), nil)
-- Deux sorts peuvent porter le meme nom : le second prend un identifiant libre.
local homonyme = S.Ajouter(moi, { label = "Trait de givre" })
attendu("un homonyme est accepte", homonyme.id, "trait_de_givre_2")
attendu("mais un identifiant impose doit etre libre",
    (S.Ajouter(moi, { id = "trait_de_givre", label = "Autre" })), nil)
S.Supprimer(moi, "trait_de_givre_2")
local court = S.Valider({ label = "A", jet = { min = 0, max = 0 } })
attendu("un jet de 0 a 0 n'est pas un jet", court.jet, nil)
local borne = S.Valider({ label = "B", jet = { min = 20, max = 3 } })
attendu("bornes remises a l'endroit", borne.jet.min .. "-" .. borne.jet.max, "3-20")
local long = S.Valider({ label = string.rep("x", 200) })
attendu("nom tronque", #long.label, S.NOM_MAX)

dire("== le grimoire personnel les montre")
local personnel = LCM.Grimoires.Personnel()
attendu("ses sorts sont les miens", #LCM.Grimoires.Sorts(personnel, 1, moi), 1)
attendu("le compte du hub aussi", LCM.Grimoires.CompteSorts(personnel, moi), 1)
local hub = LCM.UI.Grimoires.Basculer()
attendu("la tuile le compte", hub.tuiles[1].compte:GetText():find("1 sort") ~= nil, true)
attendu("et le nomme en apercu", hub.tuiles[1].apercu:GetText():find("Trait de givre") ~= nil, true)
hub.tuiles[1]:Click()
attendu("la fenetre montre le sort", LCM.UI.Grimoire.frame.nombreAffiche, 1)
hub:Hide()

dire("== l'editeur : ecrire un sort depuis le grimoire")
local hub2 = LCM.UI.Grimoires.Fenetre()
hub2:Montrer(moi)
hub2.tuiles[1]:Click()
local livre = LCM.UI.Grimoire.frame
attendu("c'est bien le sien", livre.grimoire.personnel, true)
attendu("le bouton d'ecriture est la", livre.nouveau:IsShown(), true)
livre.nouveau:Click()
local ed = LCM.UI.SortEditeur.frame
attendu("l'editeur s'ouvre vide", ed.nom:GetText(), "")
ed.valider:Click()
attendu("sans nom : refuse et dit", ed.probleme:GetText(), "il faut un nom.")
attendu("et il reste ouvert", ed:IsShown(), true)
ed.nom:Saisir("Souffle de cendre")
ed.jetMin:Saisir("2")
ed.jetMax:Saisir("12")
ed.valider:Click()
attendu("ecrit", S.Get(moi, "souffle_de_cendre") ~= nil, true)
attendu("avec son jet", S.Get(moi, "souffle_de_cendre").jet.max, 12)
attendu("l'editeur se ferme", ed:IsShown(), false)
-- Le personnage en a deja un : on cherche la carte par son nom.
local function carte(nom)
    for _, c in ipairs(livre.cartes) do
        if c:IsShown() and c.nom:GetText() == nom then return c end
    end
end
attendu("la carte apparait", carte("Souffle de cendre") ~= nil, true)
attendu("et porte ses actions", carte("Souffle de cendre").partager:IsShown(), true)

dire("== corriger un sort")
carte("Souffle de cendre").modifier:Click()
attendu("l'editeur reprend ses valeurs", ed.nom:GetText(), "Souffle de cendre")
ed.description:Saisir("Un nuage brulant.")
ed.valider:Click()
attendu("corrige", S.Get(moi, "souffle_de_cendre").description, "Un nuage brulant.")
attendu("l'identifiant n'a pas bouge", S.Compte(moi), 2)
S.Supprimer(moi, "souffle_de_cendre")
livre:Hide()
hub2:Hide()

dire("== le lien de chat")
local lien = LCM.Lien.Sort(moi, sort)
dire("   " .. lien)
attendu("il porte le nom", lien:find("%[Trait de givre%]") ~= nil, true)
-- Recherche litterale : le royaume contient un tiret, magique pour les motifs.
attendu("il porte le proprietaire et l'identifiant",
    lien:find(LCM.Lien.TYPE .. ":" .. moi.id .. ":trait_de_givre", 1, true) ~= nil, true)
_G.__chatOuvert = true
LCM.Lien.Inserer(lien)
attendu("pose dans la zone de saisie", __dernierLien(), lien)
_G.__chatOuvert = nil

dire("== cliquer son propre lien")
__cliquerLien(LCM.Lien.TYPE .. ":" .. moi.id .. ":trait_de_givre")
attendu("l'infobulle le nomme", GameTooltip.__text, "Trait de givre")
attendu("elle donne sa plage", GameTooltip.__lines[#GameTooltip.__lines - 1]:find("1 a 20") ~= nil, true)
attendu("un lien etranger ne declenche rien", LCM.Lien.Intercepter("item:6948"), false)

dire("== l'encodage survit au texte libre")
local R = LCM.Reseau
local aller = { label = "Point-virgule ; egal = pourcent %", jet = { min = 1, max = 6 } }
local retour = R.Decoder(R.Encoder(aller))
attendu("le texte revient intact", retour.label, aller.label)
attendu("la table imbriquee aussi", retour.jet.max, "6")

dire("== le decoupage respecte la limite de 255 octets")
local gros = { label = "Sort long", description = string.rep("abcdefghij ", 36) }
local ok, morceaux = R.Envoyer("sort", gros, "WHISPER", "Autre-Royaume")
attendu("envoye", ok, true)
attendu("en plusieurs morceaux", morceaux > 1, true)
attendu("aucun message au-dessus de la limite", __plusGrosEnvoi() <= R.LIMITE, true)
dire("   " .. #__envois .. " message(s), le plus gros : " .. __plusGrosEnvoi() .. " octets")

dire("== partager un sort, et le recevoir")
-- La boucle rend les envois au destinataire : on joue les deux bouts.
__reseauBoucle(true, "Binome-Apertus")
LCM.Lien.onRecu = function(expediteur, recu) _G.__dernierRecu = { expediteur, recu } end
local avant = S.Compte(moi)
local partage = select(1, LCM.Lien.Partager(moi, "trait_de_givre", "Binome-Apertus"))
attendu("partage", partage, true)
attendu("recu", _G.__dernierRecu ~= nil, true)
attendu("de qui", _G.__dernierRecu[1], "Binome-Apertus")
attendu("quel sort", _G.__dernierRecu[2].label, "Trait de givre")
attendu("rien n'est entre dans ma sauvegarde", S.Compte(moi), avant)
attendu("plus rien n'attend un morceau", R.EnAttente(), 0)

dire("== un sort recu se regarde avant d'etre pris")
local vu = LCM.Lien.Trouver("Binome-Apertus", "trait_de_givre")
attendu("on l'a en memoire", vu ~= nil, true)
LCM.Sorts.Supprimer(moi, "trait_de_givre")
attendu("le mien est parti", S.Compte(moi), 0)
local adopte = LCM.Lien.Adopter("Binome-Apertus", "trait_de_givre")
attendu("adopte", adopte ~= nil, true)
attendu("il est a moi", S.Compte(moi), 1)
attendu("avec son jet", S.Get(moi, "trait_de_givre").jet.max, 20)

dire("== un sort illisible est refuse, sans bruit")
LCM.Reseau.Recevoir("Inconnu-Royaume", "7:1:1:sort|label=")
attendu("rien n'a ete ajoute", S.Compte(moi), 1)

dire("== supprimer nettoie la sauvegarde")
S.Supprimer(moi, "trait_de_givre")
attendu("plus de sorts", S.Compte(moi), 0)
attendu("ni de table", moi.sorts, nil)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
