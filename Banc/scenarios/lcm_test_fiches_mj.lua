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

dire("== le paquet d'une fiche")
local paquet = F.Paquet(moi)
attendu("il porte le nom", paquet.nom, moi.name)
attendu("et les valeurs", paquet.v.force, "7")
attendu("les jauges se disent courant/max", paquet.v.fatigue, "12/40")
attendu("les traits partent avec la fiche", paquet.t[1], "escalade_jungle")
attendu("les blessures partent avec la fiche", paquet.b.buste, 2)
attendu("l'équipement part avec la fiche", paquet.eq.arme[1], "objet_absent")
attendu("la bourse part avec la fiche", paquet.bo.ecus, 17)
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
attendu("le groupe sans moi", p.nombreAffiche, 1)
attendu("le membre", p.lignes[1].nom:GetText(), "Nytherah-Apertus")
attendu("l'entree du menu est allumee", LCM.UI.Menu.EstLiee("panneau_mj"), true)
local envoisAvant = #__envois
p.lignes[1].reedition:Click()
attendu("le panneau propose le jeton de réédition", p.lignes[1].reedition ~= nil, true)
attendu("le clic envoie un message", #__envois > envoisAvant, true)
attendu("le jeton vise le bon joueur", __envois[#__envois].cible, "Nytherah-Apertus")
attendu("et part en chuchotement", __envois[#__envois].canal, "WHISPER")
-- Le combat est un onglet du panneau depuis le 3 octobre 2026 (c'etait une
-- fenetre a part, ouverte par un bouton).
local onglets = {}
for _, b in ipairs(p.barre.boutons) do onglets[b.ongletId] = b end
attendu("quatre onglets", #p.barre.boutons, 4)
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
p.lignes[1].consulter:Click()
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
attendu("sept onglets de consultation", #consultation.barre.boutons, 7)
attendu("Fiche reprend l'icone du radial", consultation.barre.boutons[1].icone.__texture,
    LCM.UI.Menu.Trouver("fiche").icone)
consultation.barre.boutons[2]:GetScript("OnEnter")(consultation.barre.boutons[2])
attendu("le survol nomme l'onglet", GameTooltip.__text, "Santé")
consultation.barre.boutons[2]:GetScript("OnLeave")(consultation.barre.boutons[2])
attendu("Fiche est l'onglet actif", consultation.barre.boutons[1].__selectionne, true)
attendu("les autres onglets sont grisés", consultation.barre.boutons[2].__selectionne, false)
local pointBarre, relatifBarre, pointRelatifBarre, xBarre, yBarre = consultation.barre:GetPoint(1)
attendu("la barre est ancree a l'ecran", relatifBarre, UIParent)
consultation.barre.boutons[2]:Click()
attendu("Santé remplace la fiche", consultation.onglet, "sante")
attendu("la Santé lit le personnage consulté", LCM.UI.Vues.Fenetre("sante").entity, recue)
attendu("la fiche précédente est cachée", LCM.UI.Fiche.frame:IsShown(), false)
local _, relatifSante, pointRelatifSante, xSante = LCM.UI.Vues.Fenetre("sante"):GetPoint(1)
attendu("la nouvelle feuille vient contre la barre", relatifSante, consultation.barre)
attendu("elle garde un espace avec le menu", xSante, -consultation.ESPACEMENT_FEUILLE)
local _, relatifApres, _, xApres, yApres = consultation.barre:GetPoint(1)
attendu("le menu ne change pas d'ancrage", relatifApres, relatifBarre)
attendu("le menu ne bouge pas horizontalement", xApres, xBarre)
attendu("le menu ne bouge pas verticalement", yApres, yBarre)
consultation.barre.boutons[6]:Click()
attendu("Équipement remplace la Santé", consultation.onglet, "equipement")
attendu("l'équipement reste en lecture seule",
    LCM.UI.Vues.Fenetre("equipement").entity.distante, true)
consultation.barre.boutons[7]:Click()
attendu("Bourse utilise la même consultation", LCM.UI.Bourse.frame.entity, recue)
attendu("Bourse devient l'onglet actif", consultation.barre.boutons[7].__selectionne, true)
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
