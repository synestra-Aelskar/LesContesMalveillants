-- Un joueur sans compagnon MJ recoit une definition publique par le ping.
__declencher("PLAYER_LOGIN")
__personnage()
LCM.BasculerModeJoueur(true)   -- un joueur, meme avec le compagnon MJ charge au banc

local function attendu(ok, texte)
    if not ok then error(texte) end
    print("  ok  " .. texte)
end

local source = LCM.SourcePublique["objets/arc_court"]
attendu(source and source.definition, "une entree du Sheet est dans la source publique")
local def = LCM.Copie(source.definition)
def.id = "test_ping_public"
def.label = "Objet reçu du MJ"
local cle = "objets/" .. def.id
local revision = "revision_test"
local serialiser = LCM.Lien.Serialiser
local versions = {}
for k, entree in pairs(LCM.SourcePublique) do versions[k] = entree.revision end
versions[cle] = revision
local numero = 500
local function recevoir(sujet, donnees)
    numero = numero + 1
    LCM.Reseau.Recevoir("Maître-Apertus", string.format("%d:1:1:%s|%s", numero,
        sujet, LCM.Reseau.Encoder(donnees)))
end

attendu(LCM.Objets.Get(def.id) == nil, "l'entree distante est absente au depart")
recevoir("base_liste", { corps = serialiser(versions) })
recevoir("base_entree", { cle = cle, revision = revision, corps = serialiser(def) })
recevoir("base_fin", {})
attendu(LCM.Objets.Get(def.id) ~= nil, "l'entree distante est publiee")
attendu(LCM.db.basePublique[cle].revision == revision, "elle est gardee pour le prochain chargement")

-- Une definition privee, meme presente dans un message forge, ne doit pas
-- etre publiee ni conservee par l'addon joueur.
local privee = LCM.Copie(def)
privee.id = "test_ping_prive"
privee.distributionMJ = true
local clePrivee = "objets/" .. privee.id
versions[clePrivee] = "revision_privee"
recevoir("base_liste", { corps = serialiser(versions) })
recevoir("base_entree", { cle = clePrivee, revision = "revision_privee",
    corps = serialiser(privee) })
recevoir("base_fin", {})
attendu(LCM.Objets.Get(privee.id) == nil, "une entree MJ reste absente")
attendu(LCM.db.basePublique[clePrivee] == nil, "une entree MJ n'est pas sauvegardee")

print("TOUT PASSE")
