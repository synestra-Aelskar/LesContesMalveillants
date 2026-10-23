-- Le journal ecrit (23 octobre 2026) : sa propre variable de sauvegarde,
-- LCM_Journal, et une trace de toutes les erreurs.
local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function contient(libelle, texte, morceau)
    local ok = tostring(texte or ""):find(morceau, 1, true) ~= nil
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(texte), ok and "" or ("(attendu « " .. morceau .. " »)"))
end
local function derniere() local l = LCM.LignesJournal() return l[#l] end

dire("== avant la connexion, les lignes attendent")
LCM.Erreur("tombée avant la connexion")
attendu("pas encore de sauvegarde", LCM_Journal, nil)

__declencher("PLAYER_LOGIN")
__personnage()
dire("== a la connexion, la sauvegarde est a lui")
attendu("LCM_Journal existe", type(LCM_Journal), "table")
attendu("et ne vit pas dans LCM_DB", LCM_DB.journal, nil)
local lignes = LCM_Journal.lignes
local trouvee = false
for _, l in ipairs(lignes) do trouvee = trouvee or l:find("ombée avant la connexion", 1, true) ~= nil end
attendu("ce qui est tombe avant y est", trouvee, true)
local session = false
for _, l in ipairs(lignes) do session = session or l:find("  session  ", 1, true) ~= nil end
attendu("la session est notee", session, true)

dire("== ce qui s'ecrit")
LCM.Erreur("|cffff0000une erreur en couleur|r")
contient("une erreur", derniere(), "erreur")
contient("sans ses couleurs", derniere(), "  Une erreur en couleur")
attendu("ni code couleur", derniere():find("|c", 1, true), nil)
LCM.Alerte("une alerte")
contient("une alerte", derniere(), "alerte")
local n = #lignes
LCM.Info("une simple information")
attendu("pas les informations ordinaires", #lignes, n)
LCM.Debug("une trace de debug")
contient("le debug, meme coupe", derniere(), "trace")
LCM.Trace("une trace seule")
contient("une trace", derniere(), "une trace seule")
attendu("une trace ne va pas au chat", __sansCouleur(__sorties[#__sorties] or ""):find("trace seule", 1, true), nil)
contient("horodatee", derniere(), "20")

dire("== une repetition se compte")
n = #lignes
for _ = 1, 5 do LCM.Erreur("toujours la même") end
attendu("une seule ligne", #lignes, n + 1)
contient("comptee", derniere(), "x5")

dire("== Proteger y laisse sa trace")
LCM.Proteger("un rappel", function() error("cassé") end)
contient("l'erreur d'un rappel", derniere(), "Un rappel : ")

dire("== le trajet d'une fiche")
LCM._masterCompanion = true
__groupe({ "Nytherah-Apertus" })
LCM.Fiches.Demander("Nytherah-Apertus")
contient("la demande", derniere(), "fiche demandée à Nytherah-Apertus")
-- Le meme personnage repond (le banc n'a qu'un client).
LCM.Reseau.Recevoir("Nytherah-Apertus", "5:1:1:fiche?|", "WHISPER")
local suite = table.concat(LCM.LignesJournal(), "\n", math.max(1, #lignes - 3))
contient("la demande recue", suite, "demande de fiche reçue de Nytherah-Apertus")
contient("la reponse envoyee", suite, "fiche envoyée à Nytherah-Apertus")

dire("== la taille est bornee")
for i = 1, 3100 do LCM.Trace("ligne " .. i) end
attendu("au plus 3000 lignes", #LCM_Journal.lignes, 3000)
contient("les plus recentes restent", derniere(), "ligne 3100")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
