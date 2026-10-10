-- Les bannieres : les themes, leur rendu, et l'atelier (10 octobre 2026).
--
-- Tout vient du module Zone Gate d'Omega Hub, images comprises. Ce qu'on
-- verifie ici, ce sont les deux coutures de la reprise : le theme tient-il le
-- coup a l'aller-retour reseau (le decodeur rend TOUT en texte), et l'atelier
-- montre-t-il bien un reglage par champ declare ?

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local B, L = LCM.Bannieres, LCM.Lieux

dire("== le catalogue est au complet, et les images sont livrees")
attendu("quarante-deux compositions, plus « aucune »", #B.COMPOSITIONS, 43)
attendu("dix-neuf polices", #B.ORDRE_POLICES, 19)
-- Une composition qui n'a pas son image s'afficherait vide, sans la moindre
-- erreur : on verifie les fichiers, pas seulement la table.
local manquantes = {}
for _, c in ipairs(B.COMPOSITIONS) do
    local chemin = B.Image(c.id)
    if chemin then
        local relatif = chemin:gsub("^Interface\\AddOns\\", "")
        if not __fichierExiste(relatif) then manquantes[#manquantes + 1] = c.id end
    end
end
attendu("aucune image manquante", #manquantes, 0)
attendu("« aucune » n'a pas d'image", B.Image("aucune"), nil)
local policesManquantes = 0
for _, id in ipairs(B.ORDRE_POLICES) do
    local chemin = B.POLICES[id].chemin
    if chemin and chemin:find("LesContesMalveillants", 1, true) then
        local relatif = chemin:gsub("^Interface\\AddOns\\", "")
        if not __fichierExiste(relatif) then policesManquantes = policesManquantes + 1 end
    end
end
attendu("aucune police manquante", policesManquantes, 0)

dire("== un theme se cree a partir du rendu d'origine")
LCM.db.themes = {}
local theme = B.Creer("Marches Grises")
attendu("il existe", theme ~= nil, true)
attendu("il est a moi", theme.auteur, "Reika-Apertus")
attendu("et il part du défaut", theme.composition, "aucune")
attendu("un thème sans nom n'est pas sans nom", B.Creer("").nom, "Nouveau thème")

dire("== chaque nature de champ se règle, et refuse ce qui n'est pas elle")
attendu("une composition", B.Definir(theme.id, "composition", "forest_autumn"), true)
attendu("  elle est prise", B.Get(theme.id).composition, "forest_autumn")
attendu("une composition inconnue est refusée",
    (B.Definir(theme.id, "composition", "nimportequoi")), false)
attendu("une police", B.Definir(theme.id, "police", "cinzel"), true)
attendu("un nombre", B.Definir(theme.id, "taille", "36"), true)
attendu("  il est pris", B.Get(theme.id).taille, 36)
attendu("  et borné", B.Definir(theme.id, "taille", "999") and B.Get(theme.id).taille, 64)
attendu("un nombre qui n'en est pas est refusé", (B.Definir(theme.id, "taille", "gros")), false)
attendu("un oui/non", B.Definir(theme.id, "majuscules", true), true)
attendu("une couleur", B.Definir(theme.id, "couleurTitre", { 1, 0.5, 0 }), true)
attendu("  elle est prise", string.format("%.2f", B.Get(theme.id).couleurTitre[2]), "0.50")
attendu("une couleur qui n'en est pas est refusée",
    (B.Definir(theme.id, "couleurTitre", "orange")), false)
attendu("un champ inconnu est refusé", (B.Definir(theme.id, "fumisterie", 1)), false)

dire("== le texte suit le style du thème")
attendu("en majuscules", B.StyleTexte("Les Marches", B.Get(theme.id)), "LES MARCHES")
B.Definir(theme.id, "espacement", true)
attendu("et espacé", B.StyleTexte("Gué", B.Get(theme.id)), "G U É")
B.Definir(theme.id, "espacement", false)
B.Definir(theme.id, "majuscules", false)
attendu("l'accent reste un seul caractère", B.StyleTexte("Gué", B.DEFAUT), "Gué")

dire("== le seuil l'emporte sur le lieu, le lieu sur le défaut")
LCM.db.lieux = {}
__position(0, 0, 0)
local lieu = L.Creer("Les Marches Grises")
local seuil = L.CreerSeuil(lieu.id, "Porte du Nord", "porte")
__position(0, 10, 0)
L.PoserBorne(seuil.id)
attendu("sans rien, le rendu d'origine", B.Resoudre(seuil, lieu), B.DEFAUT)
attendu("on pose le thème sur le lieu", L.ThemeDuLieu(lieu.id, theme.id), true)
attendu("  le seuil en hérite", B.Resoudre(seuil, lieu).id, theme.id)
local autre = B.Creer("Porte tonnante")
attendu("on pose un autre sur le seuil", L.ThemeDuSeuil(seuil.id, autre.id), true)
attendu("  c'est lui qui gagne", B.Resoudre(seuil, lieu).id, autre.id)
attendu("on le retire", L.ThemeDuSeuil(seuil.id, ""), true)
attendu("  et on retombe sur le lieu", B.Resoudre(seuil, lieu).id, theme.id)

dire("== un thème traverse le réseau sans rien perdre")
-- Le decodeur rend TOUT en texte : une couleur relue sans conversion serait
-- une chaine, et la banniere planterait en l'appliquant.
__groupe({ "Autre-Apertus" })
B.Definir(theme.id, "couleurFond", { 0.1, 0.2, 0.3, 0.75 })
B.Definir(theme.id, "contour", true)
B.Definir(theme.id, "apparition", "1.25")
local depart = #__envois
B.Diffuser(theme.id)
__avancer(2)
local messages = {}
for i = depart + 1, #__envois do messages[#messages + 1] = __envois[i].message end
attendu("il est parti", #messages > 0, true)

local idTheme = theme.id
LCM.db.themes = {}
for _, m in ipairs(messages) do LCM.Reseau.Recevoir("Autre-Apertus", m) end
local recu = B.Get(idTheme)
attendu("il est revenu", recu ~= nil, true)
attendu("il est à l'autre", recu.auteur, "Autre-Apertus")
attendu("son nom", recu.nom, "Marches Grises")
attendu("sa composition", recu.composition, "forest_autumn")
attendu("sa police", recu.police, "cinzel")
attendu("sa taille est un NOMBRE", type(recu.taille), "number")
attendu("  et c'est la bonne", recu.taille, 64)
attendu("son oui/non est un BOOLÉEN", type(recu.contour), "boolean")
attendu("  et il est vrai", recu.contour, true)
attendu("sa couleur est une TABLE", type(recu.couleurFond), "table")
attendu("  avec son opacité", string.format("%.2f", recu.couleurFond[4]), "0.75")
attendu("une couleur sans opacité n'en invente pas", recu.couleurTitre[4], nil)
attendu("sa durée", string.format("%.2f", recu.apparition), "1.25")
attendu("le modifier est refusé", (B.Definir(idTheme, "taille", 20)), false)

dire("== la bannière se compose, avec et sans image")
local afficheur = LCM.UI.Banniere.Creer(UIParent, nil, false)
afficheur:Composer("Les Marches Grises", "Porte du Nord", B.DEFAUT)
local hauteurNue = afficheur:GetHeight()
attendu("sans composition, elle est basse", hauteurNue >= 90, true)
afficheur:Composer("Les Marches Grises", "Porte du Nord", recu)
attendu("avec une composition, elle est plus haute", afficheur:GetHeight() >= 150, true)
attendu("et l'image est posée", afficheur.image ~= nil, true)

dire("== et elle s'anime, du début à la fin")
afficheur.theme = recu
local total = afficheur:Chercher(0)
attendu("au départ, transparente", string.format("%.2f", afficheur:GetAlpha()), "0.00")
afficheur:Chercher(total / 2)
attendu("au milieu, pleine", string.format("%.2f", afficheur:GetAlpha()), "1.00")
afficheur:Chercher(total + 1)
attendu("à la fin, effacée", string.format("%.2f", afficheur:GetAlpha()), "0.00")
attendu("la durée est celle du thème",
    string.format("%.2f", total),
    string.format("%.2f", recu.apparition + recu.maintien + recu.disparition))

dire("== franchir un seuil montre la bannière de son thème")
LCM.db.themes = {}
LCM.db.lieux = {}
__position(0, 0, 0)
lieu = L.Creer("Les Marches Grises")
seuil = L.CreerSeuil(lieu.id, "Porte du Nord", "porte")
__position(0, 10, 0)
L.PoserBorne(seuil.id)
local mien = B.Creer("Tonnerre")
B.Definir(mien.id, "composition", "volcano")
L.ThemeDuLieu(lieu.id, mien.id)
L.Rearmer()
__position(5, 5, 0) L.Tick()
__position(-5, 5, 0) L.Tick()
local vraie = LCM.UI.Banniere.Fenetre()
attendu("la bannière est à l'écran", vraie:IsShown(), true)
attendu("et elle porte le thème du lieu", vraie.theme and vraie.theme.id, mien.id)

dire("== l'atelier montre un réglage par champ déclaré")
local A = LCM.UI.BannieresMJ
A.theme = mien.id
local af = A.Fenetre()
af:Montrer()
attendu("ouvert", af:IsShown(), true)
attendu("une rangée par champ", #af.rangees, #B.CHAMPS)
attendu("le nom est repris", af.nom:GetText(), "Tonnerre")
local textes = table.concat(__textes(af), " | ")
attendu("le formulaire nomme ses réglages",
    textes:find("Composition", 1, true) ~= nil, true)
attendu("l'aperçu est composé", af.apercu.theme and af.apercu.theme.id, mien.id)

-- Un theme recu se lit, il ne se modifie pas : les contrôles s'effacent.
A.theme = nil
af:Afficher()
attendu("sans thème choisi, pas de formulaire", af.rangees[1]:IsShown(), false)
af:Hide()

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
