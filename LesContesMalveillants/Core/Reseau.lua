-- Le reseau : parler aux autres joueurs.
--
-- UN SEUL point de passage, et une seule raison : les messages d'addon de WoW
-- sont limites a 255 OCTETS. C'est ce qui cassait les invitations de combat
-- dans Necronicon — le message partait, personne ne le recevait, et rien ne le
-- disait. Ici, tout ce qui sort est decoupe et renumerote, tout ce qui entre
-- est recolle, et un morceau manquant se voit.
--
-- Rien d'autre ne doit appeler SendAddonMessage directement.

local _, LCM = ...

local Reseau = {}
LCM.Reseau = Reseau

Reseau.PREFIXE = "LCM1"
-- 255 est la limite dure. L'en-tete (<id>:<n>:<total>:) tient dans 16 octets ;
-- on garde une marge, un octet perdu coute moins cher qu'un message perdu.
Reseau.LIMITE = 255
Reseau.UTILE = 230

local handlers = {}
local recus = {}
local compteur = 0

-- ===== Mise en texte =======================================================
-- Un sort porte du texte libre : il faut que « ; » et « = » puissent s'y
-- trouver sans casser le decodage.

local function Echapper(v)
    return (tostring(v):gsub("[%%;=\n\r]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function Desechapper(v)
    return (tostring(v):gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end))
end

-- Une table plate de valeurs simples. Les tables imbriquees se disent par un
-- point : jet.min devient « jet.min ».
function Reseau.Encoder(donnees)
    local morceaux = {}
    local function poser(prefixe, table_)
        local cles = {}
        for cle in pairs(table_) do cles[#cles + 1] = tostring(cle) end
        -- Trie : deux encodages du meme contenu doivent se ressembler, sinon
        -- rien n'est comparable au banc.
        table.sort(cles)
        for _, cle in ipairs(cles) do
            local valeur = table_[cle]
            if type(valeur) == "table" then
                poser(prefixe .. cle .. ".", valeur)
            elseif valeur ~= nil then
                morceaux[#morceaux + 1] = Echapper(prefixe .. cle) .. "=" .. Echapper(valeur)
            end
        end
    end
    poser("", donnees or {})
    return table.concat(morceaux, ";")
end

function Reseau.Decoder(texte)
    local donnees = {}
    for morceau in tostring(texte or ""):gmatch("[^;]+") do
        local cle, valeur = morceau:match("^(.-)=(.*)$")
        if cle then
            cle, valeur = Desechapper(cle), Desechapper(valeur)
            local parent, feuille = cle:match("^(.-)%.(.+)$")
            if parent then
                donnees[parent] = type(donnees[parent]) == "table" and donnees[parent] or {}
                donnees[parent][feuille] = valeur
            else
                donnees[cle] = valeur
            end
        end
    end
    return donnees
end

-- ===== Envoi ===============================================================

local function Decouper(texte, taille)
    local morceaux = {}
    local index = 1
    while index <= #texte do
        morceaux[#morceaux + 1] = texte:sub(index, index + taille - 1)
        index = index + taille
    end
    if #morceaux == 0 then morceaux[1] = "" end
    return morceaux
end
Reseau.Decouper = Decouper

local function Expedier(message, canal, cible)
    local envoyer = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    if not envoyer then return false end
    if #message > Reseau.LIMITE then
        -- Ne doit jamais arriver : si ca arrive, on le dit plutot que de
        -- laisser le message disparaitre en silence.
        LCM.Erreur(string.format("message de %d octets, au-dessus de la limite de %d.",
            #message, Reseau.LIMITE))
        return false
    end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(Reseau.PREFIXE, message, canal, cible)
    else
        envoyer(Reseau.PREFIXE, message, canal, cible)
    end
    return true
end

-- Reseau.Envoyer("sort", { ... }, "WHISPER", "Nytherah-Apertus")
function Reseau.Envoyer(sujet, donnees, canal, cible)
    canal = canal or "RAID"
    local charge = tostring(sujet) .. "|" .. Reseau.Encoder(donnees)
    compteur = (compteur % 999) + 1
    local id = tostring(compteur)

    -- La place qui reste pour le contenu, une fois l'en-tete pose. On calcule
    -- l'en-tete le plus long possible, pas le premier.
    local morceaux = Decouper(charge, Reseau.UTILE)
    local entete = #id + #tostring(#morceaux) * 2 + 3
    if Reseau.UTILE + entete > Reseau.LIMITE then
        morceaux = Decouper(charge, Reseau.LIMITE - entete)
    end

    for rang, morceau in ipairs(morceaux) do
        local message = string.format("%s:%d:%d:%s", id, rang, #morceaux, morceau)
        if not Expedier(message, canal, cible) then return false end
    end
    return true, #morceaux
end

-- ===== Reception ===========================================================

function Reseau.Ecouter(sujet, handler)
    if type(handler) ~= "function" then return end
    handlers[tostring(sujet)] = handler
end

-- Rendue publique pour le banc : jouer un message recu sans passer par WoW.
function Reseau.Recevoir(expediteur, message)
    local id, rang, total, morceau = tostring(message or ""):match("^(%d+):(%d+):(%d+):(.*)$")
    if not id then return false end
    rang, total = tonumber(rang), tonumber(total)

    local cle = tostring(expediteur) .. "#" .. id
    local assemblage = recus[cle]
    if not assemblage or assemblage.total ~= total then
        assemblage = { total = total, morceaux = {}, recus = 0 }
        recus[cle] = assemblage
    end
    if assemblage.morceaux[rang] == nil then
        assemblage.morceaux[rang] = morceau
        assemblage.recus = assemblage.recus + 1
    end
    if assemblage.recus < total then return true end

    recus[cle] = nil
    local charge = table.concat(assemblage.morceaux)
    local sujet, corps = charge:match("^(.-)|(.*)$")
    if not sujet then return false end
    local handler = handlers[sujet]
    if not handler then return false end
    local ok, erreur = pcall(handler, expediteur, Reseau.Decoder(corps))
    if not ok then LCM.Erreur(string.format("message « %s » : %s", sujet, tostring(erreur))) end
    return true
end

-- Combien de messages attendent encore un morceau : de quoi diagnostiquer un
-- envoi tombe en route.
function Reseau.EnAttente()
    local nombre = 0
    for _ in pairs(recus) do nombre = nombre + 1 end
    return nombre
end

LCM.On("CHAT_MSG_ADDON", function(prefixe, message, _, expediteur)
    if prefixe ~= Reseau.PREFIXE then return end
    if expediteur == LCM.PlayerId() then return end
    Reseau.Recevoir(expediteur, message)
end)

LCM.WhenReady(function()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(Reseau.PREFIXE)
    end
end)
