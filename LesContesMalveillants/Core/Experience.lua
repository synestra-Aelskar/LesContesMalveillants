-- L'experience, et la montee de niveau qu'elle amene.
--
-- Le niveau est fixe a 5 a la creation, et seul le compagnon MJ ouvre la case.
-- Monter se gagne en jeu : c'est le MJ qui donne l'experience, a la fin d'une
-- scene, et le palier se franchit tout seul quand le total y arrive.
--
-- CE QUI VIENT DU TEMPLATE, ET CE QUI N'EN VIENT PAS
--
-- Le template Necronicon n'a PAS de table d'experience de personnage. Il n'a
-- que celle des metiers (« XP METIER », `Equilibrage.metiers.paliers`), qui
-- fait progresser un metier, pas un niveau. La table des paliers de niveau est
-- donc la seule chose ici qu'on ne reprend de nulle part : elle est declaree
-- dans `Data/Equilibrage.lua` (`E.experience`), marquee comme a valider, et
-- se change sans toucher a ce fichier.
--
-- L'experience ne se retire pas. Un MJ peut se tromper de montant, pas defaire
-- une scene : s'il donne trop, il donne moins la prochaine fois.

local _, LCM = ...

local Experience = {}
LCM.Experience = Experience

local function Eq() return LCM.Equilibrage.experience end

-- L'XP vit sur l'entite, a cote de ses valeurs : c'est un acquis du
-- personnage, pas un champ de la feuille (la feuille dit ce qu'on est, pas ce
-- qu'on a traverse pour y arriver).
function Experience.Total(entity)
    return math.max(0, math.floor(tonumber(entity and entity.xp) or 0))
end

-- Le niveau qu'un total d'XP donne droit. Les paliers sont CUMULATIFS : le
-- palier n dit l'XP totale pour atteindre le niveau n.
function Experience.NiveauPour(xp)
    xp = math.max(0, math.floor(tonumber(xp) or 0))
    local niveau = Eq().niveauDepart
    for _, palier in ipairs(Eq().paliers) do
        if xp >= palier.xp then niveau = palier.niveau end
    end
    return niveau
end

-- Ou l'on en est : le niveau courant, et ce qu'il faut pour le suivant.
-- `reste` vaut nil au dernier palier connu — il n'y a plus rien a viser.
function Experience.Progression(entity)
    local xp = Experience.Total(entity)
    local niveau = Experience.NiveauPour(xp)
    local prochain
    for _, palier in ipairs(Eq().paliers) do
        if palier.xp > xp then prochain = palier break end
    end
    return {
        xp = xp, niveau = niveau,
        prochainNiveau = prochain and prochain.niveau or nil,
        prochainXp = prochain and prochain.xp or nil,
        reste = prochain and (prochain.xp - xp) or nil,
    }
end

-- Donne l'experience et fait monter le niveau si le palier est franchi.
-- Retourne l'ancien et le nouveau niveau : l'appelant sait ainsi s'il doit
-- annoncer quelque chose.
function Experience.Donner(entity, montant, raison)
    montant = math.floor(tonumber(montant) or 0)
    if not entity then return nil, "aucun personnage." end
    if montant <= 0 then return nil, "il faut un montant positif." end

    local avant = Experience.NiveauPour(Experience.Total(entity))
    entity.xp = Experience.Total(entity) + montant
    local apres = Experience.NiveauPour(entity.xp)

    -- Le niveau de la feuille suit, jamais l'inverse : c'est l'XP qui fait foi.
    -- On ne REDESCEND pas un personnage dont le niveau a ete pose a la main
    -- au-dessus de son XP (un PNJ du MJ, un personnage d'avant l'outil).
    local niveauFiche = tonumber(LCM.Entities.Get_Value(entity, "niveau")) or 0
    if apres > niveauFiche then LCM.Entities.Set_Value(entity, "niveau", apres) end

    if Experience.onGain then Experience.onGain(entity, montant, avant, apres, raison) end
    return { avant = avant, apres = apres, monte = apres > avant, xp = entity.xp }
end

-- ===== Entre le MJ et le joueur ===========================================
-- Le MJ donne, le joueur recoit. L'inverse n'existe pas : personne ne
-- s'attribue d'experience, c'est tout l'interet de la faire passer par le MJ.

local SUJET = "xp"

function Experience.Envoyer(joueur, montant, raison)
    joueur = tostring(joueur or "")
    montant = math.floor(tonumber(montant) or 0)
    if joueur == "" then return false, "a qui ?" end
    if montant <= 0 then return false, "il faut un montant positif." end
    if not LCM.IsMaster() then return false, "seul le maître du jeu donne de l'expérience." end
    LCM.Reseau.Envoyer(SUJET, { m = montant, r = raison }, "WHISPER", joueur)
    return true
end

LCM.WhenReady(function()
    LCM.Reseau.Ecouter(SUJET, function(expediteur, donnees)
        -- Meme regle que la consultation de fiche : l'expediteur doit etre dans
        -- le groupe. On ne peut pas verifier qu'il est MJ — un client modifie
        -- dirait qu'il l'est — alors on dit QUI a donne, et la triche se voit.
        if not LCM.Reseau.DansLeGroupe(expediteur) then
            LCM.Debug(string.format("experience refusee de %s : hors du groupe.", tostring(expediteur)))
            return
        end
        local moi = LCM.Entities.Self()
        if not moi then return end
        local resultat = Experience.Donner(moi, donnees.m, donnees.r)
        if not resultat then return end
        local pourquoi = tostring(donnees.r or "")
        LCM.Ok(string.format("+%d XP de %s%s.", math.floor(tonumber(donnees.m) or 0),
            tostring(expediteur), pourquoi ~= "" and (" — " .. pourquoi) or ""))
        if resultat.monte then
            LCM.Ok(string.format("|cffffd36bNiveau %d !|r Tu as des points à répartir.", resultat.apres))
        end
    end)
end)
