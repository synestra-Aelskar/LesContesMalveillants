-- Consultation des fiches par le MJ : demande, reponse, panneau.
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
local F = LCM.Fiches
local moi = LCM.Entities.Self()
LCM.Entities.Set_Value(moi, "force", 7)
LCM.Entities.Set_Value(moi, "niveau", 5)
LCM.Entities.SetGauge(moi, "fatigue", 12, 40)
moi.traits = { "escalade_jungle" }
moi.body = { buste = 2 }
moi.apprentissages = { apprentissage = { "lecon_absente" } }
moi.equipement = { arme = { "objet_absent" } }
moi.usureArmure = { objet_absent = 1 }
moi.bourse = { ecus = 17 }
moi.xp = 23
-- Un sac porte, avec quelque chose dedans : depuis que la Bourse est une
-- colonne de l'inventaire, c'est cette fenetre que la tranche de consultation
-- ouvre, et elle doit montrer ce que le joueur porte.
LCM.Inventaire.Poser(moi, "sacs", 1, "gros_sac")
LCM.Inventaire.Ranger(moi, "sacs", 1, 1, "objets/dague_d_assassin_du_culte", 1)

dire("== le paquet d'une fiche")
local paquet = F.Paquet(moi)
attendu("il porte le nom", paquet.nom, moi.name)
attendu("et les valeurs", paquet.v.force, "7")
attendu("les jauges se disent courant/max", paquet.v.fatigue, "12/40")
attendu("les traits partent avec la fiche", paquet.t[1], "escalade_jungle")
attendu("les blessures partent avec la fiche", paquet.b.buste, 2)
attendu("l'équipement part avec la fiche", paquet.eq.arme[1], "objet_absent")
attendu("la bourse part avec la fiche", paquet.bo.ecus, 17)
-- L'inventaire voyage en UNE chaine compacte : l'encodeur generique en
-- faisait 71 morceaux, et la fiche repart a chaque changement.
attendu("l'inventaire part en une chaîne", paquet.inv,
    "sacs,1,sac,gros_sac,|1,objets/dague_d_assassin_du_culte,1")
-- Aller-retour de la chaine compacte : chaque genre d'emplacement doit se
-- relire tel quel, et un champ vide ne doit pas decaler les suivants.
local varie = {
    sacs = { [1] = { sac = "gros_sac", cases = { [2] = { ref = "ressources/eau", quantite = 3 } } } },
    ceintures = { [1] = { ceinture = true } },
    cristaux_usage = { [1] = { cristaux = true } },
    devises = { [1] = { devise = "ecus", solde = 12 } },
}
local relu = F.DecoderInventaire(F.CoderInventaire(varie))
attendu("relu : le sac", relu.sacs[1].sac, "gros_sac")
attendu("relu : la quantité dans la case", relu.sacs[1].cases[2].quantite, 3)
attendu("relu : la ceinture est un booléen", relu.ceintures[1].ceinture, true)
attendu("relu : la poche à cristaux aussi", relu.cristaux_usage[1].cristaux, true)
attendu("relu : la devise", relu.devises[1].devise, "ecus")
attendu("relu : son solde", relu.devises[1].solde, 12)
attendu("un inventaire vide ne s'écrit pas", F.CoderInventaire({}), nil)
attendu("et rien ne se relit en rien", F.DecoderInventaire(nil), nil)
-- Ce qui ne doit PAS partir : le MJ consulte une fiche, il ne fouille pas.
LCM.Sorts.Ajouter(moi, { label = "Secret" })
attendu("les sorts personnels restent chez moi", paquet.v.sorts, nil)
local refait = F.Entite(paquet)
attendu("relue : le nom", refait.name, moi.name)
attendu("relue : la force", refait.values.force, 7)
attendu("relue : la jauge", refait.values.fatigue.current .. "/" .. refait.values.fatigue.max, "12/40")
attendu("relue : le trait", refait.traits[1], "escalade_jungle")
attendu("relue : la blessure", refait.body.buste, 2)
attendu("relue : l'apprentissage", refait.apprentissages.apprentissage[1], "lecon_absente")
attendu("relue : l'équipement", refait.equipement.arme[1], "objet_absent")
attendu("relue : l'usure", refait.usureArmure.objet_absent, 1)
attendu("relue : la bourse", refait.bourse.ecus, 17)
attendu("relue : l'expérience", refait.xp, 23)
attendu("relue : le sac porté", refait.inventaire.sacs[1].sac, "gros_sac")
attendu("relue : son contenu", refait.inventaire.sacs[1].cases[1].ref, "objets/dague_d_assassin_du_culte")
attendu("elle se sait distante", refait.distante, true)

dire("== seul le MJ demande")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
local ok, raison = F.Demander("Nytherah-Apertus")
attendu("un joueur se fait refuser", ok, false)
attendu("et on lui dit pourquoi", raison, "reserve au maitre du jeu.")
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true
attendu("se demander sa propre fiche n'a pas de sens", (F.Demander(LCM.PlayerId())), false)

dire("== on ne repond pas a quelqu'un hors du groupe")
__groupe({})
attendu("hors groupe", F.DansLeGroupe("Nytherah-Apertus"), false)
__groupe({ "Reika-Apertus", "Nytherah-Apertus" })
attendu("dans le groupe", F.DansLeGroupe("Nytherah-Apertus"), true)

dire("== le panneau MJ")
local p = LCM.UI.PanneauMJ.Basculer()
attendu("ouvert", p:IsShown(), true)
-- Le MJ est dans sa propre liste depuis qu'il peut se donner de l'XP : sa
-- fiche se lit en memoire plutot que demandee au reseau (un WHISPER a
-- soi-meme est refuse par le protocole).
attendu("le groupe, moi compris", p.nombreAffiche, 2)
attendu("le membre", p.lignes[1].nom:GetText(), "Nytherah-Apertus")
attendu("l'entree du menu est allumee", LCM.UI.Menu.EstLiee("panneau_mj"), true)
-- Reedition et Consulter ont quitte la ligne pour le detail du personnage
-- choisi (2 novembre 2026) : sur la ligne, ils mangeaient la place du nom.
local pageGroupe = p.pages.joueurs
p.lignes[1]:Click()
attendu("un clic choisit le joueur", p.pages.etats.joueurActif, "Nytherah-Apertus")
attendu("le detail le nomme", pageGroupe.nomChoisi:GetText(), "Nytherah-Apertus")
attendu("le detail propose la réédition", pageGroupe.reedition:IsShown(), true)
local envoisAvant = #__envois
pageGroupe.reedition:Click()
attendu("le clic envoie un message", #__envois > envoisAvant, true)
attendu("le jeton vise le bon joueur", __envois[#__envois].cible, "Nytherah-Apertus")
attendu("et part en chuchotement", __envois[#__envois].canal, "WHISPER")
-- Consulter et Reedition restent toujours affiches (le MJ, 2 novembre 2026) :
-- sur soi, c'est la creation qui refuse, et elle dit pourquoi.
p.lignes[2]:Click()
attendu("la réédition reste affichée", pageGroupe.reedition:IsShown(), true)
envoisAvant = #__envois
pageGroupe.reedition:Click()
attendu("  mais rien ne part vers soi", #__envois, envoisAvant)

dire("== le regain dans le détail")
-- Tout ce que la fenetre Regain offrait, sur le personnage choisi.
local rg = pageGroupe.regain
local moiP = LCM.Entities.Personnage()
LCM.Entities.SetGauge(moiP, "fatigue", 3, 40)
pageGroupe:AfficherDetail()
attendu("la fatigue actuelle est lue", rg.valeurs.fatigue:GetText(), "3 / 40")
rg.valider:Click()
attendu("sans ressource cochée, rien ne bouge", LCM.Entities.Gauge(moiP, "fatigue").current, 3)
rg.cases.fatigue:Click()
rg.valider:Click()
attendu("sans mode, rien ne bouge", LCM.Entities.Gauge(moiP, "fatigue").current, 3)
rg.modes.max:Click()
rg.valider:Click()
attendu("Max remplit", LCM.Entities.Gauge(moiP, "fatigue").current, 40)
attendu("  et l'affichage suit", rg.valeurs.fatigue:GetText(), "40 / 40")
rg.modes.exact:Click()
rg.montant:SetText("-5")
rg.valider:Click()
attendu("un chiffre négatif retire", LCM.Entities.Gauge(moiP, "fatigue").current, 35)
rg.tout:Click()
local toutes = true
for _, def in ipairs(LCM.Regain.RESSOURCES) do if not rg.cases[def.cle]:EstCochee() then toutes = false end end
attendu("« Tout » coche les huit", toutes, true)
rg.tout:Click()
attendu("  et re-cliquer décoche", next(rg.ressources), nil)
p.lignes[1]:Click()
rg.cases.pa:Click()
rg.modes.min:Click()
envoisAvant = #__envois
rg.valider:Click()
attendu("sur un joueur distant, le regain part", __envois[#__envois].cible, "Nytherah-Apertus")
attendu("  en chuchotement", __envois[#__envois].canal, "WHISPER")
-- Une colonne de navigation remplace la rangee de huit onglets. Joueurs et
-- Etats ne font plus qu'une page ; les quatre outils partages y sont des
-- sous-entrees. Sept pages, onze entrees.
local onglets = {}
for _, b in ipairs(p.barre.boutons) do onglets[b.ongletId] = b end
-- 12 depuis le 3 novembre 2026 : le terminal « Réseau », dans sa propre
-- section « Débug ».
attendu("les entrées de la navigation", #p.barre.boutons, 12)
attendu("pas d'entrée États à part", onglets.etats, nil)
-- « Compendium » remplace la page Contenus (2 novembre 2026) : une porte, pas
-- une page. On reste sur la page ou l'on etait.
local pageAvant = p.onglet
onglets.compendium:Click()
attendu("Compendium ouvre le compendium", LCM.UI.Compendium.Fenetre():IsShown(), true)
attendu("  et le panel reste sur sa page", p.onglet, pageAvant)
LCM.UI.Compendium.Fenetre():Hide()
p:Onglet("etats")
local pageEtats = p.pages.etats
attendu("« etats » mène à la page Groupe", p.onglet == "joueurs" and pageEtats:IsVisible(), true)
attendu("le panneau propose des états à glisser", #LCM.Etats.list > 0, true)
attendu("le joueur est une cible de dépôt", pageEtats.lignesJoueurs[1].joueur, "Nytherah-Apertus")
pageEtats.duree:SetText("2")
local definitionEtat = pageEtats.lignesEtats[1].definition
pageEtats.lignesJoueurs[1].glisserDepose({ categorie = "etats", element = definitionEtat })
-- Depuis le 3 novembre 2026, la demande de fiche part APRES l'etat (le joueur
-- repondait sans lui) : le dernier message n'est plus l'etat, on le cherche.
local envoiEtat
for i = #__envois, 1, -1 do
    if tostring(__envois[i].message):match("^%d+:%d+:%d+:etat_mj|") then envoiEtat = __envois[i] break end
end
attendu("le glisser envoie l'état au joueur", envoiEtat and envoiEtat.cible, "Nytherah-Apertus")
attendu("l'état est envoyé en privé", envoiEtat and envoiEtat.canal, "WHISPER")
attendu("  puis la fiche est redemandée", tostring(__envois[#__envois].message):match(":fiche%?|") ~= nil, true)
local corpsEtat = LCM.Reseau.Decoder(
    envoiEtat.message:match("^%d+:%d+:%d+:etat_mj|(.*)$") or "")
attendu("la durée choisie accompagne l'état", corpsEtat.r, "2")

dire("== à la pelle : les cochés")
-- Le geste a proteger (le MJ, 2 novembre 2026) : un etat, plusieurs joueurs.
local etatsAvant = #__envois
pageGroupe.depot.glisserDepose({ categorie = "etats", element = definitionEtat })
attendu("sans coché, rien ne part", #__envois, etatsAvant)
pageGroupe.tousBouton:Click()
attendu("tout cocher coche le groupe", #pageGroupe:Coches(), 2)
local moiPerso = LCM.Entities.Personnage()
LCM.Etats.Enlever(moiPerso, definitionEtat.id)
moiPerso.etatsTemporaires = nil
pageEtats.duree:SetText("")
pageGroupe.depot.glisserDepose({ categorie = "etats", element = definitionEtat })
attendu("la zone envoie au joueur distant", __envois[#__envois].cible, "Nytherah-Apertus")
attendu("et pose chez soi", LCM.Etats.Porte(moiPerso, definitionEtat.id), true)
LCM.Etats.Enlever(moiPerso, definitionEtat.id)
etatsAvant = #__envois
pageEtats.lignesEtats[1]:Click("RightButton")
attendu("clic droit : aux cochés aussi", #__envois > etatsAvant
    and LCM.Etats.Porte(moiPerso, definitionEtat.id), true)
LCM.Etats.Enlever(moiPerso, definitionEtat.id)
pageGroupe.tousBouton:Click()
attendu("re-cliquer décoche tout", #pageGroupe:Coches(), 0)
pageGroupe.lignes[1].case:Click()
pageGroupe.xpBouton:Click()
attendu("l'XP reprend les cochés", pageGroupe.xpPanneau.selection["Nytherah-Apertus"], true)
pageGroupe.xpPanneau:Hide()

dire("== le catalogue : recherche, types")
LCM.Listes.Add({ id = "type_panel_poison", label = "Poisons témoins", liste = "type_etats", conteneur = "etat" })
LCM.Etats.Add({ id = "panel_venin", label = "Vénin témoin", categorie = "etat", type = "type_panel_poison", bonus = {} })
LCM.Etats.Add({ id = "panel_brulure", label = "Brûlure témoin", categorie = "etat", bonus = {} })
local function visibles()
    local out = {}
    for _, l in ipairs(pageEtats.lignesEtats) do if l:IsShown() then out[l.definition.id] = true end end
    return out
end
local function entete(texte)
    for _, h in ipairs(pageEtats.entetesEtats) do
        if h:IsShown() and h.texte:GetText() == texte then return true end
    end
    return false
end
pageEtats:Afficher()
attendu("classé : le type a son en-tête", entete(LCM.UI.Majuscules("Poisons témoins")), true)
pageEtats.recherche:Saisir("venin")
attendu("sans accent, « venin » trouve Vénin", visibles().panel_venin, true)
attendu("  et pas Brûlure", visibles().panel_brulure, nil)
pageEtats.recherche:Saisir("poisons")
attendu("la recherche lit le type", visibles().panel_venin, true)
pageEtats.recherche:Saisir("")
pageEtats.filtreChoix.choisir("t:type_panel_poison")
attendu("filtre par type : il y est", visibles().panel_venin, true)
attendu("  les autres non", visibles().panel_brulure, nil)
pageEtats.filtreChoix.choisir("t:")
attendu("« Sans type » montre les non rangés", visibles().panel_brulure, true)
attendu("  et plus le typé", visibles().panel_venin, nil)
pageEtats.filtreChoix.choisir("tous")
LCM.Etats.Retirer("panel_venin")
LCM.Etats.Retirer("panel_brulure")
LCM.Listes.Retirer("type_panel_poison")
pageEtats:Afficher()

onglets.combat:Click()
attendu("l'onglet Combat montre le combat", p.onglet == "combat" and p.pages.combat:IsShown(), true)
attendu("et cache les joueurs", p.pages.joueurs:IsShown(), false)
attendu("le combat est bien dedans", LCM.UI.CombatMJ.frame.lancer ~= nil, true)
LCM.UI.CombatMJ.Basculer()
attendu("Basculer depuis l'onglet Combat ferme le panneau", p:IsShown(), false)
LCM.UI.CombatMJ.Basculer()
attendu("et le rouvre sur le combat", p:IsShown() and p.onglet == "combat", true)
onglets.joueurs:Click()

dire("== demander, recevoir")
-- La boucle rend l'envoi a son expediteur : on joue les deux bouts.
__reseauBoucle(true, "Nytherah-Apertus")
attendu("rien de recu avant", F.Recue("Nytherah-Apertus"), nil)
-- Consulter vit dans le detail du joueur choisi (2 novembre 2026).
p.lignes[1]:Click()
p.pages.joueurs.consulter:Click()
__avancer(LCM.Reseau.FileEnvoi() * LCM.Reseau.CADENCE + 1)
local recue = F.Recue("Nytherah-Apertus")
attendu("la fiche arrive", recue ~= nil, true)
attendu("avec ses valeurs", recue.values.force, 7)
attendu("avec ses traits", recue.traits[1], "escalade_jungle")
attendu("avec son équipement", recue.equipement.arme[1], "objet_absent")
attendu("avec sa bourse", recue.bourse.ecus, 17)
attendu("le joueur consulte en est prevenu",
    (function()
        for i = #__sorties, 1, -1 do
            if __sansCouleur(__sorties[i]):find("a consulte ta fiche") then return true end
        end
        return false
    end)(), true)
attendu("la fenetre de fiche s'ouvre dessus", LCM.UI.Fiche.frame.entity.name, recue.name)
local consultation = LCM.UI.ConsultationMJ
attendu("la consultation garde le joueur suivi", consultation.joueur, "Nytherah-Apertus")
LCM.Entities.Set_Value(moi, "force", 9)
recue = F.Recue("Nytherah-Apertus")
attendu("une modification pousse une fiche actualisee", recue.values.force, 9)
attendu("la consultation ouverte est actualisee", consultation.entity.values.force, 9)
attendu("la fenetre existante affiche la nouvelle copie", LCM.UI.Fiche.frame.entity, recue)
-- La tranche recopie la navigation du joueur : les six fenetres de
-- « Personnage », puis l'Equipement et les Inventaires.
attendu("huit onglets de consultation", #consultation.barre.boutons, 8)
local tranche = {}
for i, b in ipairs(consultation.barre.boutons) do tranche[i] = b.consultationId end
attendu("dans l'ordre du menu du joueur", table.concat(tranche, ","),
    "fiche,sante,expertise,penetrations_resistances,statistiques,apprentissage,equipement,inventaires")
for _, b in ipairs(consultation.barre.boutons) do
    local entree = LCM.UI.Menu.Trouver(b.consultationId)
    attendu("  « " .. b.consultationLabel .. " » porte le libellé du menu",
        entree and entree.label, b.consultationLabel)
end
attendu("Fiche reprend l'icone du radial", consultation.barre.boutons[1].icone.__texture,
    LCM.UI.Menu.Trouver("fiche").icone)
consultation.barre.boutons[2]:GetScript("OnEnter")(consultation.barre.boutons[2])
attendu("le survol nomme l'onglet", LCM.UI.Infobulle().titre:GetText(), "Santé")
consultation.barre.boutons[2]:GetScript("OnLeave")(consultation.barre.boutons[2])
attendu("Fiche est l'onglet actif", consultation.barre.boutons[1].__selectionne, true)
attendu("les autres onglets sont grisés", consultation.barre.boutons[2].__selectionne, false)
-- L'ancrage a ete INVERSE : c'est la feuille qui se pose a l'ecran, et la
-- barre d'onglets qui se raccroche a son bord droit. Avant, la barre tenait
-- l'ecran et la feuille pendait a sa gauche — une feuille redimensionnee
-- poussait alors la barre hors de vue.
local pointBarre, relatifBarre, pointRelatifBarre, xBarre, yBarre = consultation.barre:GetPoint(1)
attendu("la barre se raccroche a la feuille", relatifBarre, LCM.UI.Fiche.frame)
attendu("  par sa gauche, contre le bord droit", pointBarre .. "/" .. pointRelatifBarre, "LEFT/RIGHT")
attendu("  avec l'espacement voulu", xBarre, consultation.ESPACEMENT_FEUILLE)
consultation.barre.boutons[2]:Click()
attendu("Santé remplace la fiche", consultation.onglet, "sante")
attendu("la Santé lit le personnage consulté", LCM.UI.Vues.Fenetre("sante").entity, recue)
attendu("la fiche précédente est cachée", LCM.UI.Fiche.frame:IsShown(), false)
local _, relatifSante = LCM.UI.Vues.Fenetre("sante"):GetPoint(1)
attendu("la nouvelle feuille se pose a l'ecran", relatifSante, UIParent)
local _, relatifApres, _, xApres, yApres = consultation.barre:GetPoint(1)
attendu("et la barre la suit", relatifApres, LCM.UI.Vues.Fenetre("sante"))
attendu("  en gardant le meme espacement", xApres, consultation.ESPACEMENT_FEUILLE)
attendu("le menu ne bouge pas horizontalement", xApres, xBarre)
attendu("le menu ne bouge pas verticalement", yApres, yBarre)
consultation.barre.boutons[7]:Click()
attendu("Équipement remplace la Santé", consultation.onglet, "equipement")
attendu("l'équipement reste en lecture seule",
    LCM.UI.Vues.Fenetre("equipement").entity.distante, true)
consultation.barre.boutons[8]:Click()
attendu("Inventaires utilise la même consultation", LCM.UI.Inventaires.cible, recue)
attendu("Inventaires devient l'onglet actif", consultation.barre.boutons[8].__selectionne, true)
attendu("  la fenêtre est celle de l'inventaire", consultation.fenetre, LCM.UI.Inventaires.frame)
-- Ce qu'on voit : le sac du joueur consulte, et non le sien.
attendu("  elle montre le sac du joueur",
    LCM.Inventaire.Emplacement(LCM.UI.Inventaires.cible, "sacs", 1).sac, "gros_sac")
-- Et ce qu'on ne peut pas faire : une copie recue ne se range pas.
attendu("  aucun geste ne s'y arme", LCM.UI.Inventaires.Modifiable(), false)
attendu("  glisser ne demarre pas",
    (LCM.UI.Glisser.DansLeVide({ origine = { case = 1 } })), false)
LCM.UI.Inventaires.frame:Hide()
attendu("refermée, elle ne vise plus personne", LCM.UI.Inventaires.cible, nil)
attendu("  et redevient la sienne", LCM.UI.Inventaires.Modifiable(), true)
consultation.barre.boutons[8]:Click()
p:Afficher()
-- Depuis le 3 octobre 2026, la ligne dit ce que la fiche apprend (niveau,
-- PV) plutot que « fiche reçue ».
local detail = p.lignes[1].detail:GetText()
attendu("le panneau montre son niveau", detail:find("niv%. %d") ~= nil, true)
attendu("et ses PV", detail:find("PV %-?%d+ / %d+") ~= nil, true)

dire("== une fiche recue ne s'enregistre pas")
attendu("elle n'est pas dans les entites", LCM.Entities.Get(recue.id) == recue, false)
attendu("et la liste des fiches connues", #F.Connues(), 1)
F.Oublier("Nytherah-Apertus")
attendu("oubliee", F.Recue("Nytherah-Apertus"), nil)

dire("== un joueur ne peut pas demander la fiche d'un autre")
-- Le message n'existe que dans un sens : il n'y a aucun sujet pour ca.
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
attendu("aucun moyen de demander", (F.Demander("Nytherah-Apertus")), false)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== le joueur reçoit son jeton de réédition")
while LCM.Creation.ADesJetons(moi) do LCM.Creation.RetirerJeton(moi) end
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
__reseauBoucle(true, "Nytherah-Apertus")
-- Le message est produit par le même transport que le bouton du panneau ; la
-- boucle le rend comme s'il arrivait du MJ distant.
LCM.Reseau.Envoyer("edition+", {}, "WHISPER", LCM.PlayerId())
attendu("le jeton est posé sur le personnage", LCM.Creation.ADesJetons(moi), true)
attendu("le joueur peut maintenant rééditer", (LCM.Creation.PeutEditer(moi)), true)
attendu("le message indique comment faire", dernierMessage():find("/lcm editer") ~= nil, true)
__reseauBoucle(false)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== rien ne reste a moitie arrive")
attendu("aucun message incomplet", LCM.Reseau.EnAttente(), 0)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
