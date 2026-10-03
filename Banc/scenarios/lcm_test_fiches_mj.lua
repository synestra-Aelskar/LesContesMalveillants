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
local F = LCM.Fiches
local moi = LCM.Entities.Self()
LCM.Entities.Set_Value(moi, "force", 7)
LCM.Entities.Set_Value(moi, "niveau", 5)
LCM.Entities.SetGauge(moi, "fatigue", 12, 40)

dire("== le paquet d'une fiche")
local paquet = F.Paquet(moi)
attendu("il porte le nom", paquet.nom, moi.name)
attendu("et les valeurs", paquet.v.force, "7")
attendu("les jauges se disent courant/max", paquet.v.fatigue, "12/40")
-- Ce qui ne doit PAS partir : le MJ consulte une fiche, il ne fouille pas.
LCM.Sorts.Ajouter(moi, { label = "Secret" })
attendu("les sorts personnels restent chez moi", paquet.v.sorts, nil)
local refait = F.Entite(paquet)
attendu("relue : le nom", refait.name, moi.name)
attendu("relue : la force", refait.values.force, 7)
attendu("relue : la jauge", refait.values.fatigue.current .. "/" .. refait.values.fatigue.max, "12/40")
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
local recue = F.Recue("Nytherah-Apertus")
attendu("la fiche arrive", recue ~= nil, true)
attendu("avec ses valeurs", recue.values.force, 7)
attendu("le joueur consulte en est prevenu",
    (function()
        for i = #__sorties, 1, -1 do
            if __sansCouleur(__sorties[i]):find("a consulte ta fiche") then return true end
        end
        return false
    end)(), true)
attendu("la fenetre de fiche s'ouvre dessus", LCM.UI.Fiche.frame.entity.name, recue.name)
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

dire("== rien ne reste a moitie arrive")
attendu("aucun message incomplet", LCM.Reseau.EnAttente(), 0)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
