-- Icones de fiche, canal des jets, statistiques qui se lancent.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit
local moi = LCM.Entities.Self()

dire("== les icones de la campagne")
attendu("force", LCM.IconeCampagne("force"):find("icones") ~= nil, true)
attendu("un nom inconnu ne rend rien", LCM.IconeCampagne("licorne"), nil)
attendu("le champ Force en a une", LCM.IconeChamp(LCM.Schema.Field("force")) ~= nil, true)
attendu("le champ Niveau n'en a pas", LCM.IconeChamp(LCM.Schema.Field("niveau")), nil)
attendu("accents corriges", LCM.IconeCampagne("defense"):find("defense") ~= nil, true)

dire("== les icones de fiche viennent du template, pas de nulle part")
-- Les trois qui etaient devinees avant : relevees dans le template.
attendu("adresse", LCM.IconeChamp(LCM.Schema.Field("adresse")),
    "Interface\\ICONS\\ability_titankeeper_phasing")
attendu("points d'action", LCM.IconeChamp(LCM.Schema.Field("pa")),
    "Interface\\ICONS\\eps_lol_tft_ghostlyemblem")
attendu("initiative", LCM.IconeChamp(LCM.Schema.Field("initiative")),
    "Interface\\ICONS\\eps_buildershaven_waypointmoddelay")
attendu("esprit prend l'icone de l'entree, pas celle de la cellule",
    LCM.IconeChamp(LCM.Schema.Field("esprit")),
    "Interface\\ICONS\\spell_shadow_brainwash")
-- Le vol n'existe pas dans le template : il reste sur une ressource de l'addon.
attendu("le vol vient de la campagne",
    LCM.IconeChamp(LCM.Schema.Field("depl_vol")):find("ressources") ~= nil, true)
-- Les zones du corps aussi sont celles du template.
local zones = {}
for _, c in ipairs(LCM.Body.CATEGORIES) do zones[c.id] = c.icone end
attendu("la jambe", zones.jambe, "Interface\\ICONS\\dos2_rogue8")
attendu("les internes", zones.internes, "Interface\\ICONS\\spell_brokenheart")

dire("== Adresse et Esprit se lancent")
attendu("adresse est un jet", LCM.Schema.Field("adresse").kind, "roll")
attendu("de 0 a 15", LCM.Schema.Field("adresse").dice.max, 15)
attendu("esprit aussi", LCM.Schema.Field("esprit").kind, "roll")
attendu("force reste un nombre", LCM.Schema.Field("force").kind, "stat")
LCM.Entities.Set_Value(moi, "esprit", 8)
local r = LCM.Roll.Field(moi, "esprit")
attendu("le jet passe", r ~= nil, true)
attendu("il porte la valeur investie", r.valeur, 8)
attendu("et son total s'explique", LCM.Roll.Describe(r):find("Esprit") ~= nil, true)

dire("== le canal des jets")
attendu("automatique par defaut", LCM.Canal.Choix().id, "auto")
attendu("rien n'est retenu", LCM.db.settings.canalJets, nil)
attendu("cinq choix", #LCM.Canal.LISTE, 5)
__groupe({}, false)
attendu("seul, le jet part en emote", LCM.Canal.Actuel().id, "emote")
local debutChats = #__chats
local canalSolo = LCM.Canal.Dire("Esprit : 12")
attendu("l'envoi solo utilise EMOTE", canalSolo.id, "emote")
attendu("un message emote est envoye", __chats[#__chats].canal, "EMOTE")
__groupe({ "Reika-Apertus", "Nytherah-Apertus" }, false)
attendu("en groupe, le jet part en groupe", LCM.Canal.Actuel().id, "party")
LCM.Canal.Dire("Esprit : 13")
attendu("un message groupe est envoye", __chats[#__chats].canal, "PARTY")
__groupe({ "Reika-Apertus", "Nytherah-Apertus" }, true)
attendu("en raid, le jet part en raid", LCM.Canal.Actuel().id, "raid")
LCM.Canal.Dire("Esprit : 14")
attendu("un message raid est envoye", __chats[#__chats].canal, "RAID")
attendu("les trois jets automatiques sont partis", #__chats - debutChats, 3)
LCM.Canal.Choisir("raid")
attendu("choisi", LCM.Canal.Actuel().id, "raid")
attendu("retenu", LCM.db.settings.canalJets, "raid")
__groupe({ "Reika-Apertus", "Nytherah-Apertus" }, false)
attendu("raid absent : repli vers groupe", LCM.Canal.Actuel().id, "party")
__groupe({}, false)
attendu("aucun groupe : repli vers emote", LCM.Canal.Actuel().id, "emote")
LCM.Canal.Choisir("local")
attendu("Local reste un choix explicite", LCM.db.settings.canalJets, "local")
attendu("canal local disponible", LCM.Canal.Disponible(LCM.Canal.Actuel()), true)
attendu("un choix Groupe est disponible en groupe", LCM.Canal.Disponible(LCM.Canal.Get("party")), false)
__groupe({ "Reika-Apertus", "Nytherah-Apertus" })
attendu("avec un groupe, disponible", LCM.Canal.Disponible(LCM.Canal.Get("party")), true)
LCM.Canal.Choisir("auto")

dire("== un canal disparu retombe sur Local")
LCM.db.settings.canalJets = "guilde_qui_n_existe_plus"
attendu("repli", LCM.Canal.Choix().id, "auto")
LCM.db.settings.canalJets = nil

dire("== le selecteur dans la fiche")
local f = LCM.UI.Vues.Basculer("fiche")
attendu("il est la", f.canal ~= nil, true)
-- La pastille porte la LETTRE du canal, sa couleur dit le reste.
attendu("il porte la lettre du canal courant", f.canal.label:GetText(), "G")
-- Dans l'encoche du coin haut gauche, la croix dans celle de droite, meme
-- taille (4 octobre 2026 : posees sur les encoches mesurees de l'atlas, qui
-- ne sont pas en miroir exact).
local _, _, relCanal = f.canal:GetPoint(1)
local _, _, relCroix = f.fermer:GetPoint(1)
attendu("au coin haut gauche de la fenetre", relCanal, "TOPLEFT")
attendu("la croix, au coin haut droit", relCroix, "TOPRIGHT")
attendu("meme taille que la croix", f.canal:GetWidth(), f.fermer:GetWidth())
attendu("et meme taille", f.canal:GetWidth(), f.fermer:GetWidth())
f.canal:Click()
attendu("le menu s'ouvre", f.canalMenu:IsShown(), true)
f.canalMenu.onChoix("emote")
attendu("choisi", LCM.Canal.Actuel().id, "emote")
attendu("et affiche", f.canal.label:GetText(), "E")
f.canalMenu:Hide()
LCM.Canal.Choisir("auto")
f:ActualiserCanal()

dire("== les Regles n'ont pas de canal")
local regles = LCM.UI.Vues.Fenetre("regles")
attendu("rien a lancer, rien a choisir", regles.canal, nil)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
