-- Reception d'un livre sans l'addon MJ installe.
local function attendu(nom, obtenu, voulu)
    if tostring(obtenu) ~= tostring(voulu) then
        error(nom .. " : " .. tostring(obtenu) .. " (attendu " .. tostring(voulu) .. ")")
    end
    print("  ok  " .. nom)
end

__declencher("PLAYER_LOGIN")
__personnage()
attendu("sans compagnon MJ", LCM.IsMaster(), false)
local definition = { id = "livre_recu_temoin", label = "Journal reçu",
    format = "note", pages = { { titre = "Recto", texte = "Bonjour." },
        { titre = "Verso", texte = "À bientôt." } } }
local paquet = { i = "point_livre", n = "Point témoin", p = "", u = {
    { entree = "livres/livre_recu_temoin", min = 1, max = 1, definition = definition } } }
LCM.Recolte.Lire(LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquet)))
attendu("definition importee", LCM.Livres.Get(definition.id).label, "Journal reçu")
attendu("livre consultable", LCM.UI.Livres.Ouvrir("livres/" .. definition.id), true)
attendu("deux faces", #LCM.UI.Livres.frame.feuillets, 2)
attendu("livre conserve en sauvegarde", LCM.db.livresRecus[definition.id].label, "Journal reçu")
print("TOUT PASSE")
