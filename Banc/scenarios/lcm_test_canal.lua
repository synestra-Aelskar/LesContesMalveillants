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
attendu("local par defaut", LCM.Canal.Actuel().id, "local")
attendu("rien n'est retenu", LCM.db.settings.canalJets, nil)
attendu("quatre canaux", #LCM.Canal.LISTE, 4)
LCM.Canal.Choisir("raid")
attendu("choisi", LCM.Canal.Actuel().id, "raid")
attendu("retenu", LCM.db.settings.canalJets, "raid")
LCM.Canal.Choisir("local")
attendu("revenu en local, rien de retenu", LCM.db.settings.canalJets, nil)

dire("== un canal de groupe sans groupe")
__groupe({})
LCM.Canal.Choisir("party")
attendu("indisponible", LCM.Canal.Disponible(LCM.Canal.Actuel()), false)
local avant = #__envois
local canal = LCM.Canal.Dire("Esprit : 12")
attendu("on retombe en local", canal.id, "local")
attendu("et on previent", __sansCouleur(__sorties[#__sorties - 1]):lower():find("pas de groupe") ~= nil, true)
__groupe({ "Reika-Apertus", "Nytherah-Apertus" })
attendu("avec un groupe, disponible", LCM.Canal.Disponible(LCM.Canal.Get("party")), true)
LCM.Canal.Choisir("local")

dire("== un canal disparu retombe sur Local")
LCM.db.settings.canalJets = "guilde_qui_n_existe_plus"
attendu("repli", LCM.Canal.Actuel().id, "local")
LCM.db.settings.canalJets = nil

dire("== le selecteur dans la fiche")
local f = LCM.UI.Vues.Basculer("fiche")
attendu("il est la", f.canal ~= nil, true)
-- La pastille porte la LETTRE du canal, sa couleur dit le reste.
attendu("il porte la lettre du canal", f.canal.label:GetText(), "L")
-- Dans l'en-tete, en miroir de la croix : meme taille, meme retrait du coin.
local pointCanal, _, _, xCanal, yCanal = f.canal:GetPoint(1)
local pointCroix, _, _, xCroix, yCroix = f.fermer:GetPoint(1)
attendu("ancree au coin haut gauche de la fenetre", pointCanal, "TOPLEFT")
attendu("la croix, au coin haut droit", pointCroix, "TOPRIGHT")
attendu("meme hauteur que la croix", yCanal, yCroix)
attendu("meme retrait du bord", xCanal, -xCroix)
attendu("et meme taille", f.canal:GetWidth(), f.fermer:GetWidth())
f.canal:Click()
attendu("le menu s'ouvre", f.canalMenu:IsShown(), true)
f.canalMenu.onChoix("emote")
attendu("choisi", LCM.Canal.Actuel().id, "emote")
attendu("et affiche", f.canal.label:GetText(), "E")
f.canalMenu:Hide()
LCM.Canal.Choisir("local")
f:ActualiserCanal()

dire("== les Regles n'ont pas de canal")
local regles = LCM.UI.Vues.Fenetre("regles")
attendu("rien a lancer, rien a choisir", regles.canal, nil)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
