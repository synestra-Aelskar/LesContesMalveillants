-- Points de vente et points de recolte.
--
-- Les deux sont la meme chose, et c'etait deja le cas dans Necronicon : une
-- liste d'offres, chacune avec sa quantite et son stock limite qui repousse.
-- Seule la nature change ce qu'on en dit — on ACHETE a un vendeur, on RECOLTE
-- sur un filon — et le prix, qui n'existe que chez le vendeur.
--
-- Le stock lui-meme est ailleurs (Core/Stock.lua) : c'est lui qui sait repousser
-- et se mettre d'accord avec les autres joueurs. Ici, on ne fait que donner la
-- regle de chaque offre et dire ce qu'elle rapporte.
--
-- Un point est du CONTENU : il vient des fichiers livres, pas de la sauvegarde.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

-- L'icone choisie pour une offre, ou nil : vide, ou le point d'interrogation
-- par defaut, c'est « pas d'icone ».
local function IconePropre(valeur)
    if not (valeur and tostring(valeur):match("%S")) then return nil end
    local icone = LCM.Icone(valeur)
    if tostring(icone):lower():find("inv_misc_questionmark", 1, true) then return nil end
    return icone
end

local ObjetsLaisses = {}

LCM.Points = LCM.Registre({
    nom = "point", prefixe = "Points",
    construire = function(definition, element, Erreur)
        local nature = tostring(definition.nature or "ressource")
        if nature ~= "vendeur" and nature ~= "ressource" and nature ~= "coffre" then
            Erreur(element.id .. " : nature inconnue (" .. nature .. ")")
        end
        element.nature = nature
        element.icone = definition.icone and tostring(definition.icone):match("%S")
            and LCM.Icone(definition.icone) or nil
        element.deviseDefaut = definition.deviseDefaut and tostring(definition.deviseDefaut) or nil
        -- La categorie de rangement (un vendeur dans « Port de Kul Tiras »).
        -- C'est un champ du modele, pas une liste a part : une categorie
        -- existe tant qu'un modele la porte, et voyage avec lui dans la base
        -- (21 octobre 2026).
        local categorie = definition.categorie and tostring(definition.categorie):match("^%s*(.-)%s*$")
        element.categorie = categorie ~= "" and categorie or nil
        if nature == "coffre" then
            local c = type(definition.coffre) == "table" and definition.coffre or {}
            local rayonDefaut = tonumber(LCM.Equilibrage and LCM.Equilibrage.coffres
                and LCM.Equilibrage.coffres.rayon) or 4
            local coffre = { places = math.max(1, math.floor(tonumber(c.places) or 1)),
                rayon = tonumber(c.rayon) and math.max(0.1, tonumber(c.rayon)) or rayonDefaut,
                objets = {}, verrous = math.max(0, math.floor(tonumber(c.verrous) or 0)),
                reset = c.reset == true, expertises = {}, outils = {} }
            -- Un coffre qui EST un sac lache au sol (Core/SacsAuSol.lua) dit
            -- lequel : on peut alors le ramasser en entier. Il contient ce
            -- qu'un sac contient, pas seulement des objets.
            coffre.sac = c.sac and tostring(c.sac) ~= "" and tostring(c.sac) or nil
            coffre.tente = c.tente and tostring(c.tente) ~= "" and tostring(c.tente) or nil
            -- Un objet pose seul au sol : il se ramasse d'un coup, sans s'ouvrir.
            coffre.objet = c.objet == true or nil
            -- Les memes familles pour TOUS les coffres, qu'ils soient poses ou
            -- laches au sol : c'est la regle d'accueil de LCM.Coffres.Accepte,
            -- que la fenetre du joueur, l'atelier et l'arbitrage du
            -- proprietaire lisent deja. Un coffre ordinaire n'acceptait ici
            -- qu'objets et livres : garni d'une ressource dans l'atelier, il
            -- se faisait ecarter au /reload suivant, avec tout son contenu
            -- (20 octobre 2026).
            --
            -- La finesse des devises — seules les « materielles » se
            -- transportent — reste au moment du GESTE : un chargement ne doit
            -- pas dependre de l'ordre dans lequel les fichiers arrivent.
            local familles = { objets = true, livres = true, ressources = true,
                               accessoires_camping = true, sacs = true, devises = true }
            -- Un objet supprime du compendium ne fait plus tomber le coffre
            -- entier : sa ligne est laissee de cote, et on le dit. Avant, le
            -- coffre disparaissait au /reload avec tout le reste de son
            -- contenu, sans qu'on comprenne pourquoi (20 octobre 2026). Il ne
            -- tombe que si TOUS ses objets ont disparu : il n'aurait plus rien
            -- de ce que le MJ y avait mis.
            local presents, inconnus = {}, {}
            local lignes = type(c.objets) == "table" and c.objets or {}
            for _, objet in ipairs(lignes) do
                local ref = tostring(objet.entree or "")
                local famille = ref:match("^([%w_]+)/")
                local quantite = math.max(1, math.floor(tonumber(objet.quantite) or 1))
                if presents[ref] then Erreur(element.id .. " : objet de coffre répété (" .. ref .. ")") end
                presents[ref] = true
                if not familles[famille or ""] or not LCM.Compendium.Resoudre(ref) then
                    inconnus[#inconnus + 1] = ref
                else
                    coffre.objets[#coffre.objets + 1] = { entree = ref, quantite = quantite }
                end
            end
            if #lignes > 0 and #coffre.objets == 0 then
                Erreur(element.id .. " : tous les objets du coffre sont inconnus ("
                    .. table.concat(inconnus, ", ") .. ")")
            elseif #inconnus > 0 then
                -- Une definition se relit plusieurs fois au chargement : on ne
                -- le dit qu'une fois.
                local message = string.format("coffre « %s » : %d objet(s) inconnu(s) laissé(s) de côté (%s).",
                    tostring(definition.label or element.id), #inconnus, table.concat(inconnus, ", "))
                if not ObjetsLaisses[message] then
                    ObjetsLaisses[message] = true
                    LCM.Alerte(message)
                end
            end
            for _, methode in ipairs(type(c.expertises) == "table" and c.expertises or {}) do
                local id = tostring(methode.id or "")
                local champ = LCM.Schema.Field(id)
                if id ~= LCM.Coffres.METHODE_CLEF and (not champ or not champ.jetExpertise) then
                    Erreur(element.id .. " : expertise de verrou inconnue (" .. id .. ")")
                end
                coffre.expertises[#coffre.expertises + 1] = { id = id,
                    dd = math.max(0, math.floor(tonumber(methode.dd) or 0)),
                    fatigue = math.max(0, math.floor(tonumber(methode.fatigue) or 0)),
                    usureOutils = methode.usureOutils == true,
                    reverrouillable = methode.reverrouillable == true }
            end
            -- Meme regle que les objets : un outil (ou un type d'outil) SUPPRIME
            -- laisse sa ligne de cote, on le dit, et le coffre reste. « Cassier
            -- fermé. » disparaissait du jeu parce que l'un de ses deux types
            -- d'outil n'existait plus (21 octobre 2026). Une ligne MAL FORMEE,
            -- elle, reste une erreur : ce n'est pas du contenu qui a bouge.
            local outilsLaisses = {}
            for _, outil in ipairs(type(c.outils) == "table" and c.outils or {}) do
                local ref = tostring(outil.entree or "")
                local typeOutil = tostring(outil.typeOutil or "")
                local expertise = tostring(outil.expertise or "")
                local inconnu
                if typeOutil ~= "" then
                    if ref ~= "" then
                        Erreur(element.id .. " : un outil de verrou est un objet OU un type, pas les deux ("
                            .. ref .. ", " .. typeOutil .. ")")
                    end
                    -- Absent : supprime depuis, on le laisse de cote. Present
                    -- mais d'une AUTRE liste : une saisie fausse, refusee.
                    local liste = LCM.Listes.Get(typeOutil)
                    if not liste then
                        inconnu = typeOutil
                    elseif liste.liste ~= "outils" then
                        Erreur(element.id .. " : « " .. typeOutil .. " » n'est pas un type d'outil")
                    end
                elseif ref == "" then
                    Erreur(element.id .. " : outil de verrou sans objet ni type")
                elseif not ref:match("^objets/") or not LCM.Compendium.Resoudre(ref) then
                    inconnu = ref
                end
                if expertise ~= "" then
                    local connue = false
                    for _, methode in ipairs(coffre.expertises) do
                        if methode.id == expertise then connue = true break end
                    end
                    if not connue then
                        Erreur(element.id .. " : expertise d'outil inconnue (" .. expertise .. ")")
                    end
                end
                if inconnu then
                    outilsLaisses[#outilsLaisses + 1] = inconnu
                else
                    coffre.outils[#coffre.outils + 1] = { entree = ref ~= "" and ref or nil,
                        typeOutil = typeOutil ~= "" and typeOutil or nil,
                        quantite = math.max(1, math.floor(tonumber(outil.quantite) or 1)),
                        consomme = outil.consomme == true,
                        consommeQuantite = math.max(1, math.floor(tonumber(outil.consommeQuantite) or 1)),
                        expertise = expertise ~= "" and expertise or nil }
                end
            end
            if #outilsLaisses > 0 then
                local message = string.format("coffre « %s » : %d outil(s) de verrou inconnu(s) laissé(s) de côté (%s).",
                    tostring(definition.label or element.id), #outilsLaisses, table.concat(outilsLaisses, ", "))
                if not ObjetsLaisses[message] then
                    ObjetsLaisses[message] = true
                    LCM.Alerte(message)
                end
            end
            if coffre.verrous > 0 and #coffre.expertises == 0 then
                Erreur(element.id .. " : un coffre verrouillé doit définir au moins une expertise pour l'ouvrir")
            end
            element.coffre = coffre
        end
        -- Les anciennes definitions ont une seule entree ; les nouvelles
        -- portent une liste de ressources, chacune avec ses propres regles.
        if nature == "ressource" and type(definition.recolte) == "table" then
            local r = definition.recolte
            local sources = type(r.ressources) == "table" and r.ressources or { r }
            local ressources = {}
            for _, source in ipairs(sources) do
                local mini = math.max(1, math.floor(tonumber(source.min) or 1))
                local maxi = math.max(mini, math.floor(tonumber(source.max) or mini))
                ressources[#ressources + 1] = {
                    entree = tostring(source.entree or ""),
                    min = mini, max = source.aleatoire and maxi or mini,
                    aleatoire = source.aleatoire and true or false,
                    chance = math.max(0, math.min(100, math.floor(tonumber(source.chance) or 100))),
                    regeneration = source.regeneration and true or false,
                    minutes = math.max(0, tonumber(source.minutes) or 0),
                }
            end
            local metiers = {}
            local choix = type(r.metiers) == "table" and r.metiers
                or ((r.metier and r.metier ~= "") and { { id = r.metier, bonus = true } } or {})
            local vus = {}
            for _, choixMetier in ipairs(choix) do
                local id = type(choixMetier) == "table" and choixMetier.id or choixMetier
                id = tostring(id or "")
                if id ~= "" and (id == LCM.Recolte.METIER_AUCUN or LCM.Metiers.Get(id)) and not vus[id] then
                    metiers[#metiers + 1] = { id = id,
                        bonus = id ~= LCM.Recolte.METIER_AUCUN
                            and (type(choixMetier) ~= "table" or choixMetier.bonus ~= false) }
                    vus[id] = true
                end
            end
            element.recolte = {
                ressources = ressources,
                metiers = metiers,
                -- Ces champs restent lisibles par les anciens consommateurs.
                entree = ressources[1] and ressources[1].entree or "",
                min = ressources[1] and ressources[1].min or 1,
                max = ressources[1] and ressources[1].max or 1,
                aleatoire = ressources[1] and ressources[1].aleatoire or false,
                limite = math.max(0, math.floor(tonumber(r.limite) or 1)),
                echecConsomme = r.echecConsomme == true,
                metier = metiers[1] and metiers[1].id or nil,
                dd = math.max(0, math.floor(tonumber(r.dd) or 0)),
                rayon = tonumber(r.rayon) and math.max(0.5, tonumber(r.rayon)) or nil,
            }
        end
        element.offres = {}
        local ids = {}
        local function ConstruireOffre(offre, rang)
            if type(offre) ~= "table" then Erreur(element.id .. " : offre " .. rang .. " illisible") end
            local id = tostring(offre.id or offre.entree or rang)
            if ids[id] then Erreur(element.id .. " : offre en double (" .. id .. ")") end
            ids[id] = true
            local construite = {
                id = id,
                entree = tostring(offre.entree or ""),
                label = tostring(offre.label or ""),
                -- nil sans icone propre : `Points.Icone` prend alors celle de
                -- l'entree vendue, choisie au compendium. LCM.Icone(nil) rendait
                -- le point d'interrogation, qui passait pour une icone choisie —
                -- et le constructeur l'a ensuite ENREGISTRE dans des vendeurs de
                -- la base : on le lit donc comme « pas d'icone » (16 octobre 2026).
                icone = IconePropre(offre.icone),
                quantite = math.max(1, math.floor(tonumber(offre.quantite) or 1)),
                -- Les facons de payer, au choix (Core/Prix.lua). Un point de
                -- recolte n'en a pas.
                formules = {},
                -- La cle du stock porte le point ET l'offre : deux vendeurs qui
                -- proposent la meme herbe n'ont pas le meme filon.
                cle = element.id .. "/" .. id,
                stock = {
                    limite = math.max(0, math.floor(tonumber(offre.stock and offre.stock.limite) or 0)),
                    unites = math.max(0, math.floor(tonumber(offre.stock and offre.stock.unites) or 0)),
                    minutes = math.max(0, tonumber(offre.stock and offre.stock.minutes) or 0),
                },
            }
            if construite.entree == "" and construite.label == "" then
                Erreur(element.id .. " : offre " .. rang .. " sans entree ni libelle")
            end
            if nature == "vendeur" then
                -- `formules` : une offre deja construite qu'on reenregistre.
                local facons, raison = LCM.Prix.Lire(offre.prix or offre.formules,
                    offre.devise, element.deviseDefaut)
                if not facons then Erreur(element.id .. " : « " .. id .. " » : " .. raison) end
                if #facons == 0 then
                    Erreur(element.id .. " : « " .. id .. " » est a vendre sans prix")
                end
                construite.formules = facons
            end
            return construite
        end

        -- Les anciennes definitions portaient une liste plate. Le constructeur
        -- complet range maintenant les ventes par onglet, sans casser ces
        -- points deja publies ni les consommateurs qui lisent `offres`.
        element.onglets = {}
        local onglets = type(definition.onglets) == "table" and definition.onglets or nil
        if not onglets or #onglets == 0 then
            onglets = { { id = "onglet_1", label = "Articles", offres = definition.offres or {} } }
        end
        local rangGlobal = 0
        for index, onglet in ipairs(onglets) do
            local construit = {
                id = tostring(onglet.id or ("onglet_" .. index)),
                label = tostring(onglet.label or onglet.name or ("Onglet " .. index)),
                offres = {},
            }
            for _, offre in ipairs(onglet.offres or onglet.entries or {}) do
                rangGlobal = rangGlobal + 1
                local o = ConstruireOffre(offre, rangGlobal)
                construit.offres[#construit.offres + 1] = o
                element.offres[#element.offres + 1] = o
            end
            element.onglets[#element.onglets + 1] = construit
        end
        element.rachats = {}
        for index, onglet in ipairs(definition.rachats or {}) do
            local construit = {
                id = tostring(onglet.id or ("rachat_" .. index)),
                label = tostring(onglet.label or onglet.name or ("Rachats " .. index)),
                offres = {},
            }
            for _, offre in ipairs(onglet.offres or onglet.entries or {}) do
                rangGlobal = rangGlobal + 1
                construit.offres[#construit.offres + 1] = ConstruireOffre(offre, rangGlobal)
            end
            element.rachats[#element.rachats + 1] = construit
        end
    end,
})

local Points = LCM.Points

function Points.Nature(nature)
    local out = {}
    for _, point in ipairs(Points.list) do
        if point.nature == nature then out[#out + 1] = point end
    end
    return out
end

-- Un preset (coffre, ressource, vendeur) recopie sous un nouvel identifiant.
-- Seul le modele est copie : ses exemplaires poses dans le monde restent a
-- l'original. Le stock suit l'identifiant du point (cle « point/offre ») : un
-- nouvel identifiant lui donne donc un stock neuf, et l'on efface les restants
-- recopies pour qu'aucun ne survive a la copie.
function Points.Dupliquer(point)
    local copie = LCM.Copie(point)
    copie.id = LCM.Brouillons.NouvelIdentifiant()
    copie.label = string.format("%s (copie)", tostring(point.label or ""))
    copie.arcId = nil
    local function Nettoyer(offres)
        for _, offre in ipairs(offres or {}) do offre.cle, offre.restant = nil, nil end
    end
    Nettoyer(copie.offres)
    for _, collection in ipairs({ copie.onglets or {}, copie.rachats or {} }) do
        for _, onglet in ipairs(collection) do Nettoyer(onglet.offres) end
    end
    return copie
end

-- `entree` est une REFERENCE de compendium, « famille/identifiant » : la meme
-- que celle que range l'inventaire (objets/..., ressources/..., sacs/...).
-- Ce qu'une offre donne a voir : son libelle propre, sinon celui de l'entree.
function Points.Libelle(offre)
    if offre.label ~= "" then return offre.label end
    local entree = LCM.Compendium.Resoudre(offre.entree)
    return (entree and entree.label) or offre.entree
end

function Points.Icone(offre)
    local propre = IconePropre(offre.icone)
    if propre then return propre end
    local entree = LCM.Compendium.Resoudre(offre.entree)
    return (entree and entree.icone and LCM.Icone(entree.icone)) or "Interface\\ICONS\\INV_Misc_QuestionMark"
end

function Points.Offre(pointId, offreId)
    local point = Points.Get(pointId)
    if not point then return nil end
    for _, offre in ipairs(point.offres) do
        if offre.id == tostring(offreId) then return offre, point end
    end
    return nil
end

function Points.OffreRachat(pointId, offreId)
    local point = Points.Get(pointId)
    if not point then return nil end
    for _, onglet in ipairs(point.rachats or {}) do
        for _, offre in ipairs(onglet.offres or {}) do
            if offre.id == tostring(offreId) then return offre, point end
        end
    end
    return nil
end

-- Une creation faite en jeu arrive apres l'initialisation du contenu. Ses
-- regles de stock doivent donc etre posees immediatement, et pas seulement au
-- prochain /reload.
function Points.ActualiserRegles(point)
    if not point then return end
    for _, offre in ipairs(point.offres or {}) do
        if offre.stock and offre.stock.limite > 0 then
            LCM.Stock.Declarer(offre.cle, offre.stock)
        end
        for _, facon in ipairs(offre.formules or {}) do
            for _, m in ipairs(facon) do
                if not LCM.Compendium.Resoudre(m.ref) then
                    LCM.Erreur(string.format("%s : « %s » se paie en « %s », qui n'existe pas.",
                        point.label, Points.Libelle(offre), m.ref))
                end
            end
        end
    end
end

-- ===== Prendre une offre ===================================================
-- Recolter et acheter font la meme chose : prendre au stock, puis ranger. Chez
-- un vendeur, le prix est PRELEVE dans la bourse.
--
-- L'ordre compte : on verifie d'abord qu'il peut payer, ensuite seulement on
-- entame le stock. Un filon entame pour un achat qui echoue est une ressource
-- perdue pour tout le monde.

-- `choix` : le rang de la facon de payer, chez un vendeur qui en propose
-- plusieurs (Core/Prix.lua).
function Points.Prendre(entity, pointId, offreId, choix)
    if not LCM.IsMaster() then return false, "reserve au maitre du jeu." end
    local offre, point = Points.Offre(pointId, offreId)
    if not offre then return false, "offre inconnue." end
    if type(entity) ~= "table" then return false, "aucun personnage." end

    local facon
    if #offre.formules > 0 then
        local raison
        facon, raison = LCM.Prix.Choisir(offre.formules, choix)
        if not facon then return false, raison end
        local peut, manque = LCM.Prix.Peut(entity, facon)
        if not peut then return false, manque end
    end

    local limite = LCM.Stock.Limite(offre.cle)
    if limite > 0 then
        local ok, restant = LCM.Stock.Consommer(offre.cle, 1)
        if not ok then return false, "il n'y en a plus." end
        offre.restant = restant
    end

    local range, raison = true, nil
    if offre.entree ~= "" then
        range, raison = LCM.Inventaire.Deposer(entity, offre.entree, offre.quantite)
    end
    if not range then
        -- On rend ce qu'on vient de prendre : un filon entame pour rien est une
        -- ressource perdue pour tout le monde.
        if limite > 0 then LCM.Stock.Rendre(offre.cle, 1) end
        return false, raison or "impossible de ranger."
    end

    -- Le paiement vient en dernier : a ce stade, plus rien ne peut echouer, et
    -- le joueur a bien ce pour quoi il paie.
    if facon then LCM.Prix.Payer(entity, facon) end
    return true, offre
end

-- Le versant « Achats » du constructeur : le vendeur reprend une entree du
-- sac et verse son prix. Le retrait precede le credit, de sorte qu'un objet
-- absent ne puisse jamais produire de monnaie.
-- Le vendeur peut payer de plusieurs facons : le joueur choisit (`choix`).
-- Si le paiement ne tient pas dans les sacs, l'objet revendu est rendu.
function Points.Racheter(entity, pointId, offreId, choix)
    if not LCM.IsMaster() then return false, "reserve au maitre du jeu." end
    local offre = Points.OffreRachat(pointId, offreId)
    if not offre then return false, "offre de rachat inconnue." end
    if type(entity) ~= "table" then return false, "aucun personnage." end
    if offre.entree == "" then return false, "cette offre ne designe aucun objet." end
    local facon, pourquoi = LCM.Prix.Choisir(offre.formules, choix)
    if not facon then return false, pourquoi end
    local retire, raison = LCM.Inventaire.Prendre(entity, offre.entree)
    if not retire then return false, raison or "objet absent des sacs." end
    local verse, refus = LCM.Prix.Verser(entity, facon)
    if not verse then
        LCM.Inventaire.Deposer(entity, offre.entree, 1)
        return false, refus
    end
    return true, offre
end

-- Declarer les regles de stock a la connexion : elles vivent dans le contenu,
-- pas dans la sauvegarde, donc elles se reposent a chaque session.
--
-- C'est aussi le moment de verifier les devises : le compendium n'est complet
-- qu'une fois tout charge, et une faute de frappe dans un prix doit se voir au
-- demarrage, pas a la premiere tentative d'achat en seance.
LCM.WhenReady(function()
    for _, point in ipairs(Points.list) do
        Points.ActualiserRegles(point)
    end
end)
