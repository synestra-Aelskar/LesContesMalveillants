-- Les outils partages du MJ, repris en entier des Outils de Necronicon
-- (Master.lua) le 20 octobre 2026 : barres, compteurs, annonces, notes.
--
-- Ce que la premiere reprise n'avait pas : l'APPARENCE (taille, couleurs, mode
-- d'affichage), la PORTEE (moi seul, groupe, raid, joueurs choisis), la
-- BIBLIOTHEQUE (garder un modele d'une scene a l'autre), et un vrai sous-menu
-- dans l'onglet Outils du Panel MJ.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function dernierMessage() return __sansCouleur(__sorties[#__sorties] or "") end

__declencher("PLAYER_LOGIN")
__personnage()
local MOI = LCM.PlayerId()
__groupe({ MOI, "Nytherah-Apertus" })
__declencher("GROUP_ROSTER_UPDATE")

local O, B = LCM.Outils, LCM.OutilsBiblio
local UI = LCM.UI

-- Le dernier envoi d'un sujet, recolle : un outil complet part en plusieurs
-- morceaux de 255 octets.
local function DernierEnvoi(sujet)
    for i = #__envois, 1, -1 do
        local e = __envois[i]
        local id, rang, total, corps = tostring(e.message or ""):match("^(%d+):(%d+):(%d+):(.*)$")
        if corps and rang == "1" and corps:sub(1, #sujet + 1) == sujet .. "|" then
            local morceaux = { corps:sub(#sujet + 2) }
            for j = i + 1, #__envois do
                local id2, rang2, _, suite = tostring(__envois[j].message or ""):match("^(%d+):(%d+):(%d+):(.*)$")
                if id2 == id and tonumber(rang2) and tonumber(rang2) > 1 then
                    morceaux[tonumber(rang2)] = suite
                end
            end
            if #morceaux == tonumber(total) then
                return e, LCM.Reseau.Decoder(table.concat(morceaux))
            end
            return e, nil
        end
    end
end

dire("== ce qu'une sorte porte est decrit une seule fois")
attendu("quatre sortes au sous-menu", #O.ORDRE, 4)
attendu("une barre a dix reglages", #O.Champs("barre"), 10)
attendu("une annonce en a neuf", #O.Champs("annonce"), 9)
attendu("un champ connait sa borne", O.Champ("barre", "largeur").min, 140)
attendu("et son defaut", O.Champ("barre", "couleur").defaut, "43C56B")
local neuve = O.Defauts("barre")
attendu("un outil neuf nait a ses defauts", neuve.maximum .. "/" .. neuve.couleurFond, "100/1B1F24")
attendu("une couleur se lit en trois nombres",
    string.format("%.2f", (O.Teinte("FF8000"))), "1.00")

dire("== creer : ce qui est refuse, et pourquoi")
attendu("sans libellé : refus", (O.Creer("barre", { libelle = "   " })), nil)
attendu("  et on dit lequel",
    tostring(select(2, O.Creer("barre", { libelle = "" }))):find("Libellé", 1, true) ~= nil, true)
attendu("valeur au-dessus du maximum : refus",
    tostring(select(2, O.Creer("barre", { libelle = "Rituel", maximum = 10, valeur = 12 })))
        :find("entre 0 et 10", 1, true) ~= nil, true)
attendu("maximum sous le minimum : refus",
    tostring(select(2, O.Creer("barre", { libelle = "Rituel", minimum = 5, maximum = 5 })))
        :find("dépasser", 1, true) ~= nil, true)
attendu("largeur hors bornes : refus",
    tostring(select(2, O.Creer("barre", { libelle = "Rituel", largeur = 2000 })))
        :find("800 au plus", 1, true) ~= nil, true)
attendu("couleur illisible : refus",
    tostring(select(2, O.Creer("barre", { libelle = "Rituel", couleur = "vert" })))
        :find("RRVVBB", 1, true) ~= nil, true)
attendu("sorte inconnue : refus", (O.Creer("dessin", { libelle = "X" })), nil)
attendu("rien n'a ete cree", #O.Liste(), 0)

dire("== une barre, son apparence, et qui la voit")
local barre = O.Creer("barre", { libelle = "Rituel du Sceau", maximum = 10, valeur = 3,
    couleur = "C84B3C", couleurFond = "201008", largeur = 420, hauteur = 52,
    affichage = "pourcentage", pas = 2 })
attendu("creee", barre ~= nil and barre.libelle, "Rituel du Sceau")
attendu("  elle n'est pas encore montree", barre.visible, false)
attendu("  et sa portee de naissance est « moi seul »", barre.portee, "local")
-- Creer ne diffuse rien : on regle d'abord, on montre ensuite.
attendu("  rien n'est parti", DernierEnvoi("outil"), nil)
attendu("  et personne ne l'a recue", #O.Recus(), 0)

dire("== « Moi seul » : le MJ la voit, le reseau ne bouge pas")
attendu("affichee", (O.Afficher(barre.id, "local")), true)
attendu("  elle est a l'ecran du MJ", #O.Recus(), 1)
attendu("  sous son nom", O.Recus()[1].mj, MOI)
attendu("  rien n'est parti", DernierEnvoi("outil"), nil)
local cadre = UI.Outils.cadres[O.Recus()[1].cle]
attendu("sa fenetre est la", cadre ~= nil and cadre:IsShown(), true)
attendu("  a la taille voulue", cadre:GetWidth() .. "x" .. cadre:GetHeight(), "420x52")
attendu("  et en pourcentage", cadre.valeur:GetText(), "30%")
attendu("  remplie du tiers", string.format("%.2f", cadre.part), "0.30")

dire("== le pas, et le refus au bord")
attendu("+ un pas", (O.Ajouter(barre.id)), true)
attendu("  la valeur monte de deux", O.Get(barre.id).valeur, 5)
attendu("  la fenetre suit", cadre.valeur:GetText(), "50%")
attendu("− un pas", (O.Ajouter(barre.id, -1)), true)
attendu("  et on peut descendre d'un", O.Get(barre.id).valeur, 4)
local okHaut, pourquoiHaut = O.Definir(barre.id, "valeur", 11)
attendu("au-dela du maximum : refus", okHaut, false)
attendu("  dit en toutes lettres", tostring(pourquoiHaut):find("entre 0 et 10", 1, true) ~= nil, true)
attendu("  et la valeur n'a pas bouge", O.Get(barre.id).valeur, 4)

dire("== « Groupe » : elle part, et le MJ la garde sous les yeux")
attendu("montree au groupe", (O.Afficher(barre.id, "groupe")), true)
local envoi, paquet = DernierEnvoi("outil")
attendu("un envoi est parti", envoi ~= nil, true)
attendu("  sur le canal du groupe", envoi and envoi.canal, "PARTY")
attendu("  avec son libellé", paquet and paquet.l, "Rituel du Sceau")
attendu("  sa couleur", paquet and paquet.c, "C84B3C")
attendu("  sa largeur", paquet and tostring(paquet.w), "420")
-- Ce qui vaut son defaut ne voyage pas : le receveur le remettra.
attendu("  et pas son minimum, qui vaut son defaut", paquet and paquet.n, nil)
attendu("aucun message au-dessus de 255 octets", __plusGrosEnvoi() <= 255, true)
attendu("le MJ la voit toujours", #O.Recus(), 1)

dire("== ce qu'un joueur en recoit")
-- On rejoue l'arrivee du message chez quelqu'un d'autre : le paquet du MJ,
-- recu de « Nytherah », doit redonner la meme barre.
local charge = "1:1:1:outil|" .. LCM.Reseau.Encoder(O.Paquet(O.Get(barre.id)))
LCM.Reseau.Recevoir("Nytherah-Apertus", charge)
attendu("deux outils a l'ecran (le sien, le mien)", #O.Recus(), 2)
local sien
for _, o in ipairs(O.Recus()) do if o.mj == "Nytherah-Apertus" then sien = o end end
attendu("celui de Nytherah est la", sien ~= nil, true)
attendu("  avec sa couleur", sien and sien.couleur, "C84B3C")
attendu("  sa hauteur", sien and sien.hauteur, 52)
attendu("  son mode d'affichage", sien and sien.affichage, "pourcentage")
attendu("  et le minimum remis a son defaut", sien and sien.minimum, 0)
local cadreSien = sien and UI.Outils.cadres[sien.cle]
attendu("sa fenetre est a part", cadreSien ~= nil and cadreSien ~= cadre, true)
attendu("  et elle dit qui partage", (function()
    if not cadreSien then return false end
    GameTooltip:ClearLines()
    cadreSien:GetScript("OnEnter")(cadreSien)
    for _, ligne in ipairs(GameTooltip.__lines or {}) do
        if tostring(ligne):find("Nytherah", 1, true) then return true end
    end
    return false
end)(), true)
O.Oublier("Nytherah-Apertus", barre.id)
attendu("retire, sa fenetre se ferme", cadreSien:IsShown(), false)

dire("== la place d'une fenetre est gardee, par sorte et libelle")
attendu("aucune place au depart", O.Place(O.Recus()[1]), nil)
O.NoterPlace(O.Recus()[1], { point = "CENTER", relPoint = "CENTER", x = 120, y = -40 })
attendu("notee", O.Place(O.Recus()[1]).x, 120)
-- La cle ne tient pas a l'identifiant de scene : « o3 » ne veut rien dire
-- d'une seance a l'autre.
attendu("la clé est la sorte et le libellé", O.ClePlace(O.Recus()[1]), "barre/Rituel du Sceau")

dire("== « Joueurs choisis » : un chuchotement par nom")
local avant = #__envois
attendu("ciblee", (O.Afficher(barre.id, "joueurs", { "Nytherah-Apertus" })), true)
local vers = {}
for i = avant + 1, #__envois do vers[#vers + 1] = tostring(__envois[i].cible or "?") end
attendu("un envoi, a elle", table.concat(vers, ","), "Nytherah-Apertus")
attendu("  en chuchotement", __envois[#__envois].canal, "WHISPER")
O.Cibler(barre.id, "joueurs", {})
attendu("sans personne de choisi : refus", (O.Afficher(barre.id)), false)
attendu("  et la barre n'est plus dite montree", O.Get(barre.id).visible, false)
O.Afficher(barre.id, "groupe")

dire("== masquer, puis retirer")
attendu("masquee", (O.Masquer(barre.id)), true)
attendu("  elle quitte l'ecran du MJ", #O.Recus(), 0)
attendu("  et un retrait est parti", (select(2, DernierEnvoi("outil-")) or {}).id, barre.id)
attendu("  la fenetre est fermee", cadre:IsShown(), false)
attendu("elle reste posee sur la table", #O.Liste("barre"), 1)
attendu("retiree", (O.Retirer(barre.id)), true)
attendu("  plus rien", #O.Liste(), 0)

dire("== un compteur et une note")
local compteur = O.Creer("compteur", { libelle = "Rounds", valeur = 0, couleur = "6AC8FF", police = 24 })
attendu("compteur cree", compteur ~= nil, true)
O.Afficher(compteur.id, "local")
local cc = UI.Outils.cadres[O.Recus()[1].cle]
attendu("son nombre est a l'ecran", cc.nombre:GetText(), "0")
attendu("  et pas de jauge", cc.jaugeFond:IsShown(), false)
O.Ajouter(compteur.id, 3)
attendu("il compte", cc.nombre:GetText(), "3")
local note = O.Creer("note", { libelle = "Indice", texte = "Le pont s'effondre au troisième round.",
    alignement = "centre", largeur = 300, hauteur = 200 })
attendu("note creee", note ~= nil, true)
O.Afficher(note.id, "local")
local cn
for _, o in ipairs(O.Recus()) do if o.sorte == "note" then cn = UI.Outils.cadres[o.cle] end end
attendu("son texte est a l'ecran", cn and cn.texte:GetText(), "Le pont s'effondre au troisième round.")
attendu("  a la taille voulue", cn and (cn:GetWidth() .. "x" .. cn:GetHeight()), "300x200")
-- L'alignement voyage avec la note : c'est ce que le joueur doit recevoir, le
-- reste est l'affaire de la police.
attendu("  et son alignement est arrive", cn and cn.outil and cn.outil.alignement, "centre")
attendu("une note n'a pas de valeur", (O.Ajouter(note.id, 1)), false)

dire("== l'annonce : titre, icone, couleurs, et elle s'efface")
attendu("une annonce vide : refus", (O.Annoncer({ texte = "  " })), false)
attendu("envoyee", (O.Annoncer({ libelle = "Le Sceau", texte = "Le plafond tremble !",
    icone = "inv_misc_gem_01", couleurFond = "2A0C0C", policeTitre = 26, largeur = 500 })), true)
local a = UI.Outils.annonce
attendu("elle s'affiche en grand", a ~= nil and a:IsShown(), true)
attendu("  son titre", a.titre:GetText(), "Le Sceau")
attendu("  son texte", a.texte:GetText(), "Le plafond tremble !")
attendu("  sa largeur", a:GetWidth(), 500)
attendu("  son icone", a.icone:IsShown(), true)
local _, paquetAnnonce = DernierEnvoi("annonce")
attendu("le paquet porte le titre", paquetAnnonce and paquetAnnonce.l, "Le Sceau")
attendu("  et l'icone", paquetAnnonce and paquetAnnonce.ic, "inv_misc_gem_01")
__avancer(7)
attendu("elle s'efface", a:IsShown(), false)

dire("== la bibliotheque : garder, poser, oublier")
attendu("vide au depart", #B.Liste(), 0)
local modele = B.Garder({ sorte = "barre", libelle = "Rituel du Sceau", maximum = 10,
    valeur = 0, couleur = "C84B3C" })
attendu("gardee", modele ~= nil and modele.libelle, "Rituel du Sceau")
attendu("  une barre en bibliotheque", #B.Liste("barre"), 1)
attendu("  et rien dans les compteurs", #B.Liste("compteur"), 0)
-- Garder deux fois le meme libelle REMPLACE : on corrige un modele, on n'en
-- accumule pas trois versions.
local modele2 = B.Garder({ sorte = "barre", libelle = "Rituel du Sceau", maximum = 20, valeur = 0 })
attendu("le meme libelle remplace", #B.Liste("barre"), 1)
attendu("  avec la correction", B.Liste("barre")[1].maximum, 20)
attendu("  et le meme identifiant", modele2.id, modele.id)
attendu("un modele illisible : refus", (B.Garder({ sorte = "barre", libelle = "" })), nil)
local posee = B.Poser(modele.id)
attendu("posee sur la table", posee ~= nil and posee.libelle, "Rituel du Sceau")
attendu("  avec les reglages du modele", posee and posee.maximum, 20)
attendu("  mais pas encore montree", posee and posee.visible, false)
attendu("  et la bibliotheque la garde", #B.Liste("barre"), 1)
attendu("poser et montrer d'un geste", (B.Montrer(modele.id, "local")) ~= nil, true)
attendu("oubliee", (B.Oublier(modele.id)), true)
attendu("  la bibliotheque est vide", #B.Liste(), 0)
attendu("  mais ce qui etait pose reste", O.Get(posee.id) ~= nil, true)
attendu("un modele inconnu : refus", (B.Poser("m999")), nil)
-- La bibliotheque est du MJ, et elle seule entre en sauvegarde.
attendu("elle vit dans la base du MJ", type(LCM_MJ_DB.outils), "table")

dire("== le sous-menu du Panel MJ")
local p = UI.PanneauMJ.Basculer()
local function onglet(id)
    for _, b in ipairs(p.barre.boutons) do if b.ongletId == id then b:Click() end end
    return p.pages[id]
end
local page = onglet("outils")
attendu("la page est la", page ~= nil and page:IsShown(), true)
local sous = {}
for _, b in ipairs(page.barre.boutons) do sous[#sous + 1] = b.ongletId end
attendu("quatre sous-onglets", table.concat(sous, ","), "barre,compteur,annonce,note")
attendu("on ouvre sur les barres", page.sorte, "barre")
attendu("  et seule leur page se voit",
    page.sous.barre:IsShown() and not page.sous.note:IsShown(), true)
attendu("elle liste ce qui est pose", page.sous.barre.nombreTable, 2)
attendu("  et la bibliotheque, vide", page.sous.barre.nombreBiblio, 0)

dire("== regler depuis le sous-menu, et montrer")
local function sousOnglet(id)
    for _, b in ipairs(page.barre.boutons) do if b.ongletId == id then b:Click() end end
    return page.sous[id]
end
local sc = sousOnglet("compteur")
attendu("la page des compteurs", page.sorte, "compteur")
attendu("  un compteur pose", sc.nombreTable, 1)
sc.lignesTable[1]:Click()
attendu("  choisi", sc.outilId, compteur.id)
attendu("  son editeur est la", sc.editeur:IsShown(), true)
local champLibelle, champCouleur
for _, ligne in ipairs(sc.lignes) do
    if ligne.champ.cle == "libelle" then champLibelle = ligne end
    if ligne.champ.cle == "couleur" then champCouleur = ligne end
end
attendu("  et le libellé s'y lit", champLibelle.saisie:GetText(), "Rounds")
champLibelle.saisie:Saisir("Tours")
champLibelle.saisie:GetScript("OnEnterPressed")(champLibelle.saisie)
attendu("renommé", O.Get(compteur.id).libelle, "Tours")
champCouleur.saisie:Saisir("zzz")
champCouleur.saisie:GetScript("OnEnterPressed")(champCouleur.saisie)
attendu("une couleur illisible est refusee", dernierMessage():find("RRVVBB", 1, true) ~= nil, true)
attendu("  et l'ancienne reste", O.Get(compteur.id).couleur, "6AC8FF")
sc.plus:Click()
attendu("+ depuis le panneau", O.Get(compteur.id).valeur, 4)
sc.garder:Click()
attendu("garde en bibliotheque", #B.Liste("compteur"), 1)
attendu("  et la liste le montre", sc.nombreBiblio, 1)
sc.afficher:Click()
attendu("montre", O.Get(compteur.id).visible, true)
sc.masquer:Click()
attendu("masque", O.Get(compteur.id).visible, false)
local idCompteur = compteur.id
sc.retirer:Click()
attendu("retire", O.Get(idCompteur), nil)
attendu("  et plus rien de choisi", sc.outilId, nil)
sc.lignesBiblio[1].poser:Click()
attendu("un modele se repose d'un clic", sc.nombreTable, 1)
attendu("  avec son libellé", O.Liste("compteur")[1].libelle, "Tours")

dire("== l'annonce depuis le sous-menu")
local sa = sousOnglet("annonce")
attendu("une annonce ne se pose pas sur la table", sa.posable, false)
attendu("  elle n'a donc pas de liste posee", sa.lignesTable and #sa.lignesTable or 0, 0)
local champTexte
for _, ligne in ipairs(sa.lignes) do if ligne.champ.cle == "texte" then champTexte = ligne end end
champTexte.saisie:SetText("Les cloches sonnent.")
champTexte.saisie.saisie:GetScript("OnEditFocusLost")(champTexte.saisie.saisie)
attendu("le brouillon retient le texte", sa.brouillon.texte, "Les cloches sonnent.")
sa.annoncer:Click()
attendu("annoncee", UI.Outils.annonce.texte:GetText(), "Les cloches sonnent.")
sa.garder:Click()
attendu("et gardee en bibliotheque", #B.Liste("annonce"), 1)
sa.neuve:Click()
attendu("vider rend un brouillon neuf", sa.brouillon.texte, "")
sa.lignesBiblio[1].poser:Click()
attendu("un modele se recharge", sa.brouillon.texte, "Les cloches sonnent.")

dire("== un joueur ne cree rien, et n'annonce rien")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
attendu("creer : refuse", (O.Creer("compteur", { libelle = "Triche" })), nil)
attendu("annoncer : refuse", (O.Annoncer("Triche")), false)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== on n'ecoute que son groupe")
local avantRecus = #O.Recus()
__groupe({})
LCM.Reseau.Recevoir("Inconnu-Apertus", "1:1:1:outil|id=o9;k=compteur;l=Faux;v=1")
attendu("un inconnu n'affiche rien", #O.Recus(), avantRecus)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
