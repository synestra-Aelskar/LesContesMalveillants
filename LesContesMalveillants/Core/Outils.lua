-- Les outils partages du maitre du jeu : annonces, compteurs, barres, notes.
--
-- Repris des « Outils » du Panel MJ de Necronicon (Master.lua : Barres,
-- Compteurs, Annonce, Notes). Ses Documents et Dessins ne sont pas repris : les
-- documents ont deja leur fenetre ici, et le dessin demandait une toile qu'on
-- n'a pas.
--
-- Le MJ cree un outil dans son panneau ; chaque changement part au groupe, et
-- chez le joueur une petite fenetre les montre (UI/Outils.lua). Ce fichier vit
-- dans l'addon PRINCIPAL : c'est le joueur qui recoit, et il n'a pas le
-- compagnon MJ. Creer, lui, n'est permis qu'au MJ.
--
-- Tout vit en memoire vive : un compteur de rounds ou une jauge de rituel
-- durent une scene, pas une campagne. Rien n'entre en sauvegarde.
--
-- Les messages :
--   outil    MJ -> groupe ou un joueur  { id, k, l, v, m, t }  creer ou mettre a jour
--   outil-   MJ -> groupe                { id }                 retirer
--   annonce  MJ -> groupe                { t }
--   outils?  joueur -> groupe            {}                     « renvoyez-moi tout »

local _, LCM = ...

local Outils = {}
LCM.Outils = Outils

Outils.SORTES = { compteur = "Compteur", barre = "Barre", note = "Note" }
-- Les plafonds tiennent la taille des messages raisonnable (le reseau decoupe
-- au-dela de 255 octets, mais une note de trois pages n'a rien a faire ici).
Outils.LIBELLE_MAX, Outils.TEXTE_MAX, Outils.ANNONCE_MAX = 40, 600, 200

-- Chez le MJ : ses outils, dans l'ordre de creation.
local miens, compteur = {}, 0
-- Chez le joueur : ce qui a ete recu, par identifiant, avec qui l'a envoye.
Outils.recus = {}

local function Tronquer(texte, maximum)
    texte = tostring(texte or "")
    return #texte > maximum and texte:sub(1, maximum) or texte
end

local function Canal() return LCM.Combat.CanalGroupe() end

local function Paquet(o)
    return { id = o.id, k = o.sorte, l = o.libelle, v = o.valeur, m = o.maximum, t = o.texte }
end

local function Diffuser(o, joueur)
    if joueur then return LCM.Reseau.Envoyer("outil", Paquet(o), "WHISPER", joueur) end
    local canal = Canal()
    if not canal then return false, "hors groupe : l'outil est cree, mais personne ne le voit." end
    return LCM.Reseau.Envoyer("outil", Paquet(o), canal)
end

local function Prevenir()
    if Outils.onChange then Outils.onChange() end
end

-- Verifie une valeur avant de l'accepter. Un refus dit pourquoi, et ne
-- corrige rien en douce : une barre a 12 sur 10 n'est pas ramenee a 10.
local function Verifier(sorte, libelle, valeur, maximum)
    if not Outils.SORTES[sorte] then return false, "sorte d'outil inconnue." end
    if tostring(libelle or ""):gsub("%s+", "") == "" then return false, "il faut un libellé." end
    if sorte == "note" then return true end
    if tonumber(valeur) == nil then return false, "la valeur doit être un nombre." end
    if sorte == "barre" then
        maximum = tonumber(maximum)
        if not maximum or maximum <= 0 then return false, "une barre a besoin d'un maximum au-dessus de 0." end
        if tonumber(valeur) < 0 or tonumber(valeur) > maximum then
            return false, string.format("la valeur doit rester entre 0 et %d.", maximum)
        end
    end
    return true
end

-- ===== Cote MJ =============================================================

function Outils.Liste() return miens end

function Outils.Get(id)
    for _, o in ipairs(miens) do if o.id == id then return o end end
end

-- Outils.Creer("barre", "Rituel", 0, 10) ; Outils.Creer("note", "Indice", nil, nil, "Le pont...")
-- Retourne l'outil cree, puis (ok, raison) de la diffusion.
function Outils.Creer(sorte, libelle, valeur, maximum, texte)
    if not LCM.IsMaster() then return nil, "réservé au maître du jeu." end
    local ok, raison = Verifier(sorte, libelle, valeur, maximum)
    if not ok then return nil, raison end
    compteur = compteur + 1
    local o = {
        id = "o" .. compteur, sorte = sorte,
        libelle = Tronquer(libelle, Outils.LIBELLE_MAX),
        valeur = sorte ~= "note" and tonumber(valeur) or nil,
        maximum = sorte == "barre" and tonumber(maximum) or nil,
        texte = sorte == "note" and Tronquer(texte, Outils.TEXTE_MAX) or nil,
    }
    miens[#miens + 1] = o
    Prevenir()
    return o, Diffuser(o)
end

-- Change la valeur (compteur, barre) d'un outil existant et la diffuse.
function Outils.Regler(id, valeur)
    local o = Outils.Get(id)
    if not o then return false, "outil inconnu." end
    if o.sorte == "note" then return false, "une note n'a pas de valeur." end
    local ok, raison = Verifier(o.sorte, o.libelle, valeur, o.maximum)
    if not ok then return false, raison end
    o.valeur = tonumber(valeur)
    Prevenir()
    return Diffuser(o)
end

function Outils.Ajouter(id, pas)
    local o = Outils.Get(id)
    if not o then return false, "outil inconnu." end
    return Outils.Regler(id, (o.valeur or 0) + (tonumber(pas) or 0))
end

function Outils.Retirer(id)
    for rang, o in ipairs(miens) do
        if o.id == id then
            table.remove(miens, rang)
            Prevenir()
            local canal = Canal()
            if canal then LCM.Reseau.Envoyer("outil-", { id = id }, canal) end
            return true
        end
    end
    return false, "outil inconnu."
end

-- Une annonce ne se garde pas : elle s'affiche chez chacun et s'efface.
function Outils.Annoncer(texte)
    if not LCM.IsMaster() then return false, "réservé au maître du jeu." end
    texte = Tronquer(texte, Outils.ANNONCE_MAX)
    if texte:gsub("%s+", "") == "" then return false, "l'annonce est vide." end
    local canal = Canal()
    if not canal then return false, "hors groupe : personne à qui annoncer." end
    return LCM.Reseau.Envoyer("annonce", { t = texte }, canal)
end

-- Tout renvoyer : a un joueur qui arrive, ou au groupe apres un incident.
function Outils.Renvoyer(joueur)
    for _, o in ipairs(miens) do Diffuser(o, joueur) end
    return true
end

-- ===== Cote joueur =========================================================

-- Les outils recus, dans l'ordre d'arrivee.
function Outils.Recus()
    local out = {}
    for _, o in pairs(Outils.recus) do out[#out + 1] = o end
    table.sort(out, function(a, b) return a.rang < b.rang end)
    return out
end

function Outils.Demander()
    local canal = Canal()
    if not canal then return false end
    return LCM.Reseau.Envoyer("outils?", {}, canal)
end

local arrivee = 0

LCM.WhenReady(function()
    local R = LCM.Reseau
    R.Ecouter("outil", function(expediteur, d)
        if not LCM.Fiches.DansLeGroupe(expediteur) then return end
        local sorte = Outils.SORTES[d.k] and d.k or nil
        if not sorte or not d.id then return end
        local cle = tostring(expediteur) .. "#" .. tostring(d.id)
        local o = Outils.recus[cle]
        if not o then
            arrivee = arrivee + 1
            o = { rang = arrivee }
            Outils.recus[cle] = o
        end
        o.cle, o.id, o.mj, o.sorte = cle, d.id, expediteur, sorte
        o.libelle = Tronquer(d.l, Outils.LIBELLE_MAX)
        o.valeur, o.maximum = tonumber(d.v), tonumber(d.m)
        o.texte = d.t and Tronquer(d.t, Outils.TEXTE_MAX) or nil
        Prevenir()
    end)
    R.Ecouter("outil-", function(expediteur, d)
        local cle = tostring(expediteur) .. "#" .. tostring(d.id)
        if Outils.recus[cle] then
            Outils.recus[cle] = nil
            Prevenir()
        end
    end)
    R.Ecouter("annonce", function(expediteur, d)
        if not LCM.Fiches.DansLeGroupe(expediteur) then return end
        local texte = Tronquer(d.t, Outils.ANNONCE_MAX)
        if texte == "" then return end
        -- Qui annonce est toujours dit : on ne prouve pas qu'un expediteur
        -- est MJ, on le montre.
        LCM.Info(string.format("Annonce de %s : %s", tostring(expediteur), texte))
        if Outils.onAnnonce then Outils.onAnnonce(expediteur, texte) end
    end)
    R.Ecouter("outils?", function(expediteur)
        if not LCM.IsMaster() or #miens == 0 then return end
        if not LCM.Fiches.DansLeGroupe(expediteur) then return end
        Outils.Renvoyer(expediteur)
    end)
    -- Un joueur qui arrive (ou recharge) rattrape ce qui est deja affiche.
    if not LCM.IsMaster() then Outils.Demander() end
end)
