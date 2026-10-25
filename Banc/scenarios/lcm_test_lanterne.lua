-- La lanterne et ses cristaux, repris d'OmegaSurvive (22 octobre 2026).
--
-- Ce que ce scenario tient :
--   * les deux categories du compendium et leurs registres, SANS contenu de
--     base (retire le 23 octobre 2026) ;
--   * rien n'existe sans etre possede : la lanterne s'equipe sur la ceinture
--     depuis les sacs, les cristaux viennent des sacs ; changer de cristal
--     en pose un neuf et ejecte l'ancien ; vide, il reste terne jusqu'au retrait ;
--   * ce que la construction refuse, et pourquoi ;
--   * l'ecoulement : multiplicateur x variateur, la charge gardee par
--     cristal, la decharge ;
--   * les auras du serveur et la pause du MJ par phrase ;
--   * le bouton Objets > Outils du menu radial et sa fenetre.
--
-- Le contenu d'essai est TEMOIN (« temoin_* ») : les entrees de base peuvent
-- etre corrigees par le MJ en seance, un test ne s'appuie pas dessus pour
-- ses calculs (CLAUDE.md, « un test ne se pose jamais sur du contenu qui vit »).

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
local function chat(motif)
    for i = #__chats, 1, -1 do if __chats[i].texte:find(motif, 1, true) then return __chats[i] end end
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local C, Ls, Cs, L, B = LCM.Compendium, LCM.Lanternes, LCM.Cristaux, LCM.Lanterne, LCM.Brouillons

dire("== les deux categories")
attendu("Lanternes existe", C.Get("lanternes") ~= nil, true)
attendu("Cristaux existe", C.Get("cristaux") ~= nil, true)
attendu("famille des lanternes resolue", C.FAMILLES.lanternes, "Lanternes")
attendu("famille des cristaux resolue", C.FAMILLES.cristaux, "Cristaux")
attendu("le MJ peut en creer", C.Editable(C.Get("lanternes")), true)

-- La 0.2.6 livrait la base de Survive (3 lanternes, 4 cristaux). Le MJ l'a
-- retiree le 23 octobre 2026 : ce qui n'est pas cree dans le compendium
-- n'existe pas. Les entrees de base ne doivent donc plus etre la.
dire("== aucun contenu par defaut")
attendu("plus de lanterne d'aspecta livree", Ls.Get("aspecta"), nil)
attendu("plus de cristal d'ancien temps livre", Cs.Get("ancient"), nil)

dire("== ce qui est refuse")
local ok, err = pcall(Ls.Construire, { id = "x", label = "X", multiplicateur = 0 })
attendu("un multiplicateur nul", ok, false)
contient("     raison", err, "au-dessus de zéro")
-- La « Vérification inventaire » (un objet du jeu par son ID) est retiree le
-- 23 octobre 2026 : ses champs sont ignores, pas refuses.
ok = pcall(Cs.Construire, { id = "x", label = "X", duree = 10, verifInventaire = true })
attendu("une ancienne verification d'inventaire est ignoree", ok, true)
-- Les regles d'aura et les phrases sont a la LANTERNE seule (meme jour) : un
-- cristal est un combustible, on ne l'allume pas.
local cristalAncien = Cs.Construire({ id = "x", label = "X", duree = 10, canaux = "alerte",
    phrasesPause = "stop", aurasPosees = "allumer : 1" })
attendu("un cristal ne garde pas de phrases", cristalAncien.phrasesPause, nil)
attendu("ni de regles d'aura", cristalAncien.aurasPosees, nil)
ok, err = pcall(Ls.Construire, { id = "x", label = "X", multiplicateur = 1, aurasPosees = "quand je veux : 123" })
attendu("une condition inconnue", ok, false)
contient("     raison", err, "allumer, eteindre, vide, pause, reprise")
ok, err = pcall(Ls.Construire, { id = "x", label = "X", multiplicateur = 1, phrasesPause = "stop" })
attendu("des phrases sans canal", ok, false)
contient("     raison", err, "sans canal")
ok, err = pcall(Ls.Construire, { id = "x", label = "X", multiplicateur = 1, canaux = "murmure" })
attendu("un canal inconnu", ok, false)
contient("     raison", err, "canal inconnu")
ok = pcall(Ls.Construire, { id = "x", label = "X", multiplicateur = 1, canaux = "alerte, Raid",
    aurasPosees = "Allumer : 1234\npause : .cast 55 : silence" })
attendu("des regles bien ecrites passent", ok, true)

dire("== creee depuis le compendium")
ok, err = B.Enregistrer("lanternes", { id = "temoin_editeur", label = "Lanterne d'atelier", multiplicateur = 3 }, true)
attendu("le MJ l'enregistre", ok, true)
attendu("elle est jouable aussitot", Ls.Get("temoin_editeur") and Ls.Get("temoin_editeur").multiplicateur, 3)
ok, err = B.Enregistrer("cristaux", { id = "temoin_mauvais", label = "Mauvais", duree = -1 }, true)
attendu("un cristal faux est refuse a l'enregistrement", ok, false)

-- Le contenu temoin des calculs.
Ls.Add({ id = "temoin_simple", label = "Témoin x1", multiplicateur = 1,
    aurasPosees = "allumer : 1234", aurasRetirees = "eteindre : 1234\nvide : 1234" })
Ls.Add({ id = "temoin_double", label = "Témoin x2", multiplicateur = 2 })
Cs.Add({ id = "temoin_long", label = "Long", duree = 100 })       -- 6000 s
Cs.Add({ id = "temoin_court", label = "Court", duree = 5 })       -- 300 s
Cs.Add({ id = "temoin_mj", label = "Pour la pause", duree = 100 })
-- Les phrases du MJ sont a la lanterne (23 octobre 2026).
Ls.Add({ id = "temoin_controle", label = "Sous contrôle", multiplicateur = 1, canaux = "alerte",
    phrasesPause = "Le temps s'arrête\nTout s'éteint : eteindre", phrasesReprise = "Le temps reprend" })


-- Rien n'existe sans etre possede (23 octobre 2026) : la lanterne s'equipe
-- sur la ceinture depuis les sacs, les cristaux viennent des sacs.
dire("== n'existe que ce qu'on porte")
local I, moi = LCM.Inventaire, LCM.Entities.Self()
L.Reinitialiser()
attendu("rien dans les sacs, aucune lanterne proposee", #L.LanternesPortees(), 0)
attendu("ni aucun cristal", #L.CristauxPortes(), 0)
-- Le joueur ne VOIT pas une lanterne qu'il n'a pas : la ceinture ne la
-- propose pas. Le refus d'EquiperLanterne n'est qu'un garde-fou pour un appel
-- par le code.
ok, err = L.EquiperLanterne("temoin_simple")
attendu("garde-fou : une lanterne absente des sacs ne s'equipe pas", ok, false)
contient("     raison", err, "aucun de tes sacs")
-- Un sac temoin : la ceinture nue n'a que trois cases, il en faut plus.
LCM.Sacs.Add({ id = "temoin_sac", label = "Sac témoin", places = 12, icone = "inv_misc_bag_30" })
local pose, pourquoiSac = I.Poser(moi, "sacs", 1, "temoin_sac", true)
attendu("le sac temoin est porte" .. (pose and "" or (" (" .. tostring(pourquoiSac) .. ")")), pose, true)
for _, ref in ipairs({ "lanternes/temoin_simple", "lanternes/temoin_double", "cristaux/temoin_long",
                       "cristaux/temoin_court", "cristaux/temoin_mj" }) do
    local range, pourquoi = I.Deposer(moi, ref, 1)
    attendu("on range " .. ref .. (range and "" or (" (" .. tostring(pourquoi) .. ")")), range, true)
end
attendu("les deux lanternes des sacs sont proposees", #L.LanternesPortees(), 2)
attendu("et les trois cristaux", #L.CristauxPortes(), 3)

dire("== allumer")
ok, err = L.Allumer()
attendu("sans lanterne ni cristal, refuse", ok, false)
contient("     raison", err, "lanterne et un cristal")
attendu("equiper la lanterne", L.EquiperLanterne("temoin_simple"), true)
attendu("elle est choisie d'office", L.LanterneChoisie() and L.LanterneChoisie().id, "temoin_simple")
attendu("elle quitte le sac", I.Chercher(moi, "lanternes/temoin_simple"), nil)
attendu("elle prend une place de la ceinture", select(2, L.PlacesCeinture(moi)), 1)
attendu("choisir le cristal", L.ChoisirCristal("temoin_long"), true)
attendu("un cristal neuf arrive plein", L.Charge(), 6000)
-- Le cristal pose vit dans la lanterne, avec SA charge (23 octobre 2026).
attendu("le cristal pose quitte les sacs", I.Chercher(moi, "cristaux/temoin_long"), nil)
attendu("sa charge est sur lui", L.CristalPose(moi).charge, 6000)
local avant = #__chats
attendu("allumer", L.Allumer(), true)
attendu("elle est allumee", L.Allumee(), true)
attendu("l'aura est posee par le serveur", chat(".aura 1234") ~= nil, true)
attendu("l'emote part en /me", chat("allume sa lanterne.") and chat("allume sa lanterne.").canal, "EMOTE")

dire("== l'ecoulement")
__avancerTemps(600)
L.Synchroniser()
attendu("600 s a x1", L.Charge(), 5400)
attendu("variateur x2", L.DefinirVariateur(2), true)
__avancerTemps(100)
L.Synchroniser()
attendu("100 s a x2", L.Charge(), 5200)
attendu("eclairage restant", L.Restant(), 2600)
attendu("un variateur hors liste est refuse", (L.DefinirVariateur(7)), false)
L.DefinirVariateur(1)
attendu("le variateur par defaut ne s'ecrit pas", L.Etat().variateur, nil)

-- Chaque cristal garde SA charge, sur son exemplaire, et les entames vont
-- dans « Cristaux en cours d'usage » (le MJ, 23 octobre 2026).
dire("== chaque cristal garde sa charge")
local function Poche() return I.Emplacement(moi, "cristaux_usage", 1) end
local function PileDe(ref)
    for _, p in ipairs(I.Piles(moi, ref)) do return p.pile, p.categorie end
end
local function OptionsDe(prefixe)
    local out = {}
    for _, o in ipairs(L.CristauxPortes()) do
        if o.label:sub(1, #prefixe) == prefixe then out[#out + 1] = o end
    end
    return out
end
-- Le Core peut toujours y ranger ; c'est la fenetre qui la cache tant
-- qu'elle est vide (voir « la poche vide se cache »).
attendu("le Core peut toujours ranger dans la poche", Poche() ~= nil, true)
attendu("poser le court", L.ChoisirCristal("temoin_court"), true)
attendu("le court arrive plein", L.Charge(), 300)
local long, ou = PileDe("cristaux/temoin_long")
attendu("le long entame part dans la poche", ou, "cristaux_usage")
attendu("avec sa charge", long and long.exemplaires[1].charge, 5200)
attendu("il s'affiche avec son pourcentage", L.LibelleCristal(long.exemplaires[1]), "Long (86 %)")
attendu("et se propose ainsi", OptionsDe("Long")[1] and OptionsDe("Long")[1].label, "Long (86 %)")
local idLong = "entame:" .. long.exemplaires[1].id
__avancerTemps(100)
L.Synchroniser()
attendu("reposer le long", L.ChoisirCristal(idLong), true)
attendu("il revient a sa charge", L.Charge(), 5200)
local court = PileDe("cristaux/temoin_court")
attendu("le court entame est dans la poche", court and court.exemplaires[1].charge, 200)

dire("== les entames s'empilent dans la poche, chacun sa charge")
I.Deposer(moi, "cristaux/temoin_court", 1)
local plein, ouPlein
for _, p in ipairs(I.Piles(moi, "cristaux/temoin_court")) do
    if not I.Entame(p.pile) then plein, ouPlein = p.pile, p.categorie end
end
attendu("un cristal plein va dans les sacs", ouPlein, "sacs")
attendu("sans pourcentage", L.Pourcent(plein.exemplaires and plein.exemplaires[1]), nil)
attendu("poser le court plein", L.ChoisirCristal("temoin_court"), true)
__avancerTemps(50)
L.Synchroniser()
attendu("reposer le long", L.ChoisirCristal(idLong), true)
-- Le MJ, 23 octobre 2026 : seuls s'empilent les entames au MEME pourcentage
-- (ici 83 % et 66 %) ; les autres vont a la suite, une ligne chacun.
local function EntamesCourt()
    local out = {}
    for _, p in ipairs(I.Piles(moi, "cristaux/temoin_court")) do
        if I.Entame(p.pile) then out[#out + 1] = p end
    end
    return out
end
local lignesCourt = EntamesCourt()
attendu("83 % et 66 % : deux lignes", #lignesCourt, 2)
attendu("chacun garde sa charge",
    lignesCourt[1].pile.exemplaires[1].charge + lignesCourt[2].pile.exemplaires[1].charge, 450)
local n, pourquoi = I.PeutEmpiler(moi, "cristaux_usage", 1, lignesCourt[2].case,
    "cristaux_usage", 1, lignesCourt[1].case)
attendu("on ne les empile pas a la main non plus", n, nil)
contient("     raison", pourquoi, "même charge")
local courts = OptionsDe("Court")
attendu("ils se proposent un par un", #courts, 2)
attendu("le plus charge d'abord", courts[1] and courts[1].label, "Court (83 %)")
attendu("puis l'autre", courts[2] and courts[2].label, "Court (66 %)")
attendu("poser celui a 200", L.ChoisirCristal(courts[2].id), true)
attendu("il revient a 200", L.Charge(), 200)
attendu("il ne reste que celui a 83 %", #EntamesCourt(), 1)

dire("== au meme pourcentage, ils s'empilent")
local x1 = LCM.Exemplaires.Nouveau("cristaux/temoin_court")
x1.charge = 100   -- 33 %
local x2 = LCM.Exemplaires.Nouveau("cristaux/temoin_court")
x2.charge = 101   -- 33 % aussi
attendu("deux a 33 % arrivent", (I.Deposer(moi, "cristaux/temoin_court", 2, { x1, x2 })), true)
local a33
for _, p in ipairs(EntamesCourt()) do
    if L.Pourcent(p.pile.exemplaires[1]) == 33 then a33 = p.pile end
end
attendu("ils tiennent une seule ligne", a33 and a33.quantite, 2)
attendu("chacun garde sa charge exacte", a33 and (a33.exemplaires[1].charge + a33.exemplaires[2].charge), 201)
attendu("a cote de celui a 83 %", #EntamesCourt(), 2)

dire("== la poche n'accepte que des entames, les sacs jamais un entame")
local libre = I.Cases(Poche())
ok, err = I.Ranger(moi, "cristaux_usage", 1, libre, "cristaux/temoin_mj", 1)
attendu("un cristal plein est refuse dans la poche", ok, false)
contient("     raison", err, "entamés")
ok, err = I.Ranger(moi, "cristaux_usage", 1, libre, "objets/rien", 1)
attendu("un objet aussi", ok, false)
local entame = I.Case(Poche(), 1)
ok, err = I.Ranger(moi, "sacs", 1, 12, entame.ref, 1, { LCM.Copie(entame.exemplaires[1]) })
attendu("un entame est refuse dans un sac", ok, false)
contient("     raison", err, "Cristaux en cours d'usage")

dire("== changer de lanterne")
attendu("equiper l'autre", L.EquiperLanterne("temoin_double"), true)
attendu("l'ancienne retourne au sac", I.Chercher(moi, "lanternes/temoin_simple") ~= nil, true)
attendu("la nouvelle en sort", I.Chercher(moi, "lanternes/temoin_double"), nil)
attendu("toujours une seule place prise", select(2, L.PlacesCeinture(moi)), 1)
-- Changer de lanterne l'eteint : celle qu'on tenait allumee est rangee.
attendu("l'echange l'a eteinte", L.Allumee(), false)

dire("== la decharge")
L.Allumer()
__avancerTemps(150)
L.Synchroniser()
attendu("a x2, 200 de charge tiennent 100 s", L.Charge(), 0)
attendu("elle s'eteint", L.Allumee(), false)
attendu("le cristal epuise reste visible et vide", L.CristalPose(moi).charge, 0)
contient("on le dit", __sansCouleur(__sorties[#__sorties] or ""), "épuisé")
ok, err = L.Allumer()
attendu("sans cristal, elle refuse de s'allumer", ok, false)
contient("     raison", err, "cristal")

-- « Recharger » devient « Changer de cristal » (le MJ, 23 octobre 2026) :
-- recharger remplissait le cristal sur place, et sa charge restante etait
-- perdue. Changer en pose un NEUF du meme modele et ejecte l'ancien.
dire("== changer de cristal")
local function Combien(ref)
    local n = 0
    for _, p in ipairs(I.Piles(moi, ref)) do n = n + (tonumber(p.pile.quantite) or 1) end
    return n
end
local function CourtsEntames()
    local n = 0
    for _, o in ipairs(L.CristauxPortes()) do
        if o.exemplaire and o.cristal.id == "temoin_court" then n = n + 1 end
    end
    return n
end
-- Le cristal epuise reste pose ; la lanterne retient aussi son modele :
-- changer en pose un neuf du meme.
ok, err = L.ChangerCristal()
attendu("sans neuf du meme modele, refuse", ok, false)
contient("     raison", err, "aucun Court plein")
I.Deposer(moi, "cristaux/temoin_court", 1)
local entamesAvant = CourtsEntames()
attendu("changer", (L.ChangerCristal()), true)
attendu("le neuf est plein", L.Charge(), 300)
attendu("le neuf a quitte les sacs", Combien("cristaux/temoin_court") - entamesAvant, 0)
attendu("l'ancien, vide, disparait", CourtsEntames(), entamesAvant)
attendu("la lanterne reste eteinte", L.Allumee(), false)
attendu("l'emote de recharge", chat("change le réactif") ~= nil, true)

dire("== changer ejecte l'entame dans les Cristaux")
L.Allumer()
__avancerTemps(60)   -- 120 de charge a x2 : il en reste 180, 60 %
L.Synchroniser()
I.Deposer(moi, "cristaux/temoin_court", 1)
attendu("changer", (L.ChangerCristal()), true)
attendu("le neuf est plein", L.Charge(), 300)
attendu("changer l'a eteinte", L.Allumee(), false)
attendu("l'ancien n'est pas jete", CourtsEntames(), entamesAvant + 1)
local ejecte
for _, o in ipairs(L.CristauxPortes()) do
    if o.exemplaire and o.exemplaire.charge == 180 then ejecte = o end
end
attendu("il revient dans la liste avec sa charge", ejecte and ejecte.label, "Court (60 %)")
local _, ouEjecte = PileDe("cristaux/temoin_court")
attendu("range dans la poche", (function()
    for _, p in ipairs(I.Piles(moi, "cristaux/temoin_court")) do
        if I.Entame(p.pile) then return p.categorie end
    end
end)(), "cristaux_usage")

-- Le MJ, 23 octobre 2026 : un cristal vide ne s'entasse pas dans la poche.
dire("== un cristal vide reste terne jusqu'au retrait")
Cs.Add({ id = "temoin_vide", label = "Vite vide", duree = 10 })
I.Deposer(moi, "cristaux/temoin_vide", 1)
L.ChoisirCristal("temoin_vide")
L.Allumer()
__avancerTemps(400)   -- 600 s de charge, a x2
L.Synchroniser()
attendu("il est vide", L.Charge(), 0)
-- Il reste visible dans la lanterne, sans retourner dans les sacs.
attendu("il reste terne dans la lanterne", L.CristalPose(moi).charge, 0)
attendu("il n'est nulle part", Combien("cristaux/temoin_vide"), 0)

-- Comme un objet : sa charge voyage avec son exemplaire.
dire("== un entame garde sa charge en voyage")
local pileLong = PileDe("cristaux/temoin_long")
local chargeLong = pileLong.exemplaires[1].charge
local pris, exemplaire = I.Prendre(moi, "cristaux/temoin_long")
attendu("il sort de la poche", pris, true)
attendu("avec sa charge", exemplaire and exemplaire.charge, chargeLong)
attendu("il revient", (I.Deposer(moi, "cristaux/temoin_long", 1, { exemplaire })), true)
local revenu, ouRevenu = PileDe("cristaux/temoin_long")
attendu("dans la poche", ouRevenu, "cristaux_usage")
attendu("intact", revenu and revenu.exemplaires[1].charge, chargeLong)

dire("== la poche dans la fenetre Inventaires")
LCM.UI.Menu.Trouver("inventaires").onClick()
local fi = LCM.UI.Inventaires.frame
local cartePoche
for _, c in ipairs(fi.cartes) do if c:IsShown() and c.onglet == "cristaux_usage" then cartePoche = c end end
attendu("elle a sa carte", cartePoche ~= nil, true)
-- Sans limite : elle dit combien elle tient, pas « 2/3 ».
-- 2 -> 4 le 23 octobre 2026 : une pile par POURCENTAGE, plus par modele.
-- Long 86 %, Court 83 %, Court 33 % (x2) et le Court 60 % ejecte par
-- « Changer de cristal » : quatre lignes.
attendu("a son nom et son compte", cartePoche and cartePoche.nom:GetText(), "Cristaux en cours d'usage (4)")
-- Le meme separateur que les autres sections (le MJ, 23 octobre 2026).
local bandeauPoche = fi.bandeaux.cristaux_usage
attendu("son bandeau est montre", bandeauPoche and bandeauPoche:IsShown(), true)
attendu("il porte son nom", bandeauPoche and bandeauPoche.titre:GetText(), "Cristaux")
attendu("et ce qu'elle tient", bandeauPoche and bandeauPoche.compte:GetText(), "4")
attendu("juste au-dessus de sa carte",
    select(5, bandeauPoche:GetPoint(1)) > select(5, cartePoche:GetPoint(1)), true)
cartePoche:Click("LeftButton")
local montre = false
for _, l in ipairs(fi.lignes) do
    if l:IsShown() and tostring(l.nom:GetText()):find("Long", 1, true) then
        montre = tostring(l.nom:GetText()):find("86 %", 1, true) ~= nil
    end
end
attendu("le cristal entame s'y lit avec sa charge", montre, true)
LCM.UI.Menu.Trouver("inventaires").onClick()

dire("== la pause du MJ")
I.Deposer(moi, "lanternes/temoin_controle", 1)
L.EquiperLanterne("temoin_controle")
L.ChoisirCristal("temoin_mj")
L.Allumer()
local charge = L.Charge()
__declencher("CHAT_MSG_RAID", "le temps s'arrete !")
attendu("le raid n'est pas un canal de cette lanterne", L.EnPauseMJ(), false)
__declencher("CHAT_MSG_RAID_WARNING", "Le temps s'arrête")
attendu("l'alerte du MJ met en pause", L.EnPauseMJ(), true)
attendu("elle reste allumee", L.Allumee(), true)
__avancerTemps(500)
L.Synchroniser()
attendu("le temps ne s'ecoule plus", L.Charge(), charge)
L.Eteindre()
attendu("on peut l'eteindre en pause", L.Allumee(), false)
__declencher("CHAT_MSG_RAID_WARNING", "le temps reprend")
attendu("la reprise leve la pause", L.EnPauseMJ(), false)
attendu("et rend l'etat choisi pendant la pause", L.Allumee(), false)
L.Allumer()
__declencher("CHAT_MSG_RAID_WARNING", "Tout s'éteint")
attendu("« : eteindre » met en pause", L.EnPauseMJ(), true)
attendu("et eteint", L.Allumee(), false)
__declencher("CHAT_MSG_RAID_WARNING", "Le temps reprend")
attendu("qui reste eteinte a la reprise", L.Allumee(), false)

dire("== les emotes")
attendu("/me en minuscule", L.FormaterEmote("Éteint sa lanterne.", "EMOTE"), "éteint sa lanterne.")
attendu("/s entre asterisques", L.FormaterEmote("éteint sa lanterne.", "SAY"), "*Éteint sa lanterne.*")
L.DefinirEmote("on", "souffle sur la mèche.")
attendu("une emote reecrite", L.Emote("on"), "souffle sur la mèche.")
L.DefinirEmote("on", "allume sa lanterne.")
attendu("revenue au defaut, elle s'oublie", L.Etat().emotes, nil)

dire("== retirer la lanterne")
attendu("un cristal est pose", L.CristalPose(moi) ~= nil, true)
attendu("retirer", L.RetirerLanterne(), true)
attendu("elle retourne au sac", I.Chercher(moi, "lanternes/temoin_controle") ~= nil, true)
attendu("son cristal aussi, avec sa charge", L.CristalPose(moi), nil)
attendu("il est dans les sacs", I.Chercher(moi, "cristaux/temoin_mj") ~= nil, true)
attendu("plus de lanterne qui eclaire", L.LanterneChoisie(), nil)

-- La ceinture porte-outils dessinee (Objets > Outils du menu radial) et le
-- panneau repris de Survive ont ete retires le 25 octobre 2026. La lanterne
-- se sert maintenant depuis « Mes Outils », et sa vue epuree s'ouvre par son
-- « Voir » : lcm_test_mes_outils les tient. Ici, on passe par Core/Lanternes.
-- L'equipement depuis la fiche est tenu par lcm_test_fiche_lanterne.
dire("== equiper, poser un cristal, allumer")
local M = LCM.UI.Menu
attendu("plus de bouton Outils dans Objets", M.Trouver("outils_portes"), nil)
ok, err = LCM.UI.Lanterne.Basculer()
attendu("sans lanterne equipee, sa vue refuse de s'ouvrir", ok, false)
contient("     raison", err, "Équipements › Outils")
attendu("plus d'objet « Lanterne » generique", LCM.Objets.Get("outil_lanterne"), nil)
attendu("la lanterne s'equipe", (L.EquiperLanterne("temoin_simple")), true)
attendu("equipee", L.IdEquipe(moi), "temoin_simple")
attendu("la lanterne equipee eclaire", L.LanterneChoisie() and L.LanterneChoisie().id, "temoin_simple")
attendu("des cristaux sont dans les sacs", #L.CristauxPortes() > 0, true)
local premier = L.CristauxPortes()[1]
L.ChoisirCristal(premier.id)
attendu("le cristal choisi est pose", L.CristalPose(moi) ~= nil, true)
L.Allumer()
attendu("et allume", L.Allumee(), true)

dire("== sans cristal dans les sacs")
L.ChoisirCristal(false)
attendu("retirer le cristal l'eteint", L.Allumee(), false)
for _, c in ipairs(Cs.list) do
    while I.Prendre(moi, "cristaux/" .. c.id) do end
end
attendu("plus aucun cristal porte", #L.CristauxPortes(), 0)

-- Le MJ, 23 octobre 2026 : la poche n'apparait que lorsqu'elle tient un
-- cristal. Videe, elle disparait de la fenetre, et de la sauvegarde.
dire("== la poche vide se cache")
attendu("la poche ne s'ecrit plus", moi.inventaire and moi.inventaire.cristaux_usage, nil)
LCM.UI.Menu.Trouver("inventaires").onClick()
local carteVide
for _, c in ipairs(LCM.UI.Inventaires.frame.cartes) do
    if c:IsShown() and c.onglet == "cristaux_usage" then carteVide = c end
end
attendu("elle n'a plus de carte", carteVide, nil)
attendu("ni de bandeau", LCM.UI.Inventaires.frame.bandeaux.cristaux_usage:IsShown(), false)
LCM.UI.Menu.Trouver("inventaires").onClick()

dire("== retirer rend la lanterne")
attendu("retirer", (L.RetirerLanterne()), true)
attendu("retiree", L.IdEquipe(moi), nil)
attendu("au sac", I.Chercher(moi, "lanternes/temoin_simple") ~= nil, true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
