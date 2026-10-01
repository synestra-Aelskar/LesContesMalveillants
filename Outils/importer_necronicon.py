"""Import du compendium Necronicon « Systeme d'Aelskar » dans l'addon.

Lit le plugin Necronicon_System_Les_contes_Malveillants_MJ (data.lua, bloc
NECROPACK du compendium « aelskar »), convertit chaque entree vers le format
des registres de l'addon, et ecrit trois fichiers generes :

    LesContesMalveillants/Data/Genere/Compendium_Contenu.lua
    LesContesMalveillants/Data/Genere/Compendium_Resolutions.lua
    LesContesMalveillants/Data/Genere/Compendium_PNJ.lua
    LesContesMalveillants/Data/Genere/Necronicon_Grimoires.lua

Ce sont des fichiers distincts de ceux de l'export des brouillons
(Traits.lua, Races.lua, Objets.lua) : l'un ne reecrit jamais l'autre.

    python3 Outils/importer_necronicon.py [--pack data.lua] [--sauvegardes DOSSIER]

Avec --sauvegardes (le dossier SavedVariables d'un compte WoW, lu sans y
toucher), le compendium vient de la sauvegarde du plugin, plus recente que le
pack, et l'outil y reprend aussi les PNJ vivants, les grimoires, et les
entrees d'un ancien compendium qui ne survivent que par leurs copies.

L'outil ne devine rien : une statistique qu'il ne sait pas placer, une
reference qu'il ne sait pas resoudre, un doublon, tout est annonce a la fin.
Il n'ecrit QUE dans Data/Genere ; il ne touche jamais aux SavedVariables.
"""
import base64
import json
import os
import re
import sys
import zlib

ICI = os.path.dirname(os.path.abspath(__file__))
DEPOT = os.path.dirname(ICI)
GENERE = os.path.join(DEPOT, 'LesContesMalveillants', 'Data', 'Genere')
DEFAUT = '/mnt/e/Games/Epsilon/_retail_/Interface/AddOns/Necronicon_System_Les_contes_Malveillants_MJ/data.lua'
SAUVEGARDES = '/mnt/e/Games/Epsilon/_retail_/WTF/Account/AKRX/SavedVariables'

RAPPORT = []


def signaler(message):
    RAPPORT.append(message)


# ===== Lecture du bloc NECROPACK ===========================================
# Inverse exact de packEncode (necro_pack_gen.js) : base64, deflate brut, puis
# la serialisation maison de Necronicon (Z, B, N, S, T ... E).

def deserialiser(buf):
    pos = [0]

    def lire():
        t = chr(buf[pos[0]])
        pos[0] += 1
        if t == 'Z':
            return None
        if t == 'B':
            v = chr(buf[pos[0]]) == '1'
            pos[0] += 1
            return v
        if t == 'N':
            fin = buf.index(b';', pos[0])
            s = buf[pos[0]:fin].decode('latin1')
            pos[0] = fin + 1
            n = float(s)
            return int(n) if n.is_integer() else n
        if t == 'S':
            fin = buf.index(b':', pos[0])
            longueur = int(buf[pos[0]:fin])
            pos[0] = fin + 1
            s = buf[pos[0]:pos[0] + longueur].decode('utf-8')
            pos[0] += longueur
            return s
        if t == 'T':
            o = {}
            while chr(buf[pos[0]]) != 'E':
                k = lire()
                o[k] = lire()
            pos[0] += 1
            return o
        raise ValueError('tag inconnu %r a %d' % (t, pos[0] - 1))

    return lire()


def lire_pack(chemin, cle):
    source = open(chemin, encoding='utf-8').read()
    for m in re.finditer(r'code = "NECROPACK_1:B:([^"]*)"[\s\S]*?key = "([^"]*)"', source):
        if m.group(2) == cle:
            brut = zlib.decompress(base64.b64decode(m.group(1)), -15)
            charge = deserialiser(brut)
            return charge['body'] if isinstance(charge, dict) and 'body' in charge else charge
    raise SystemExit('bloc « %s » introuvable dans %s' % (cle, chemin))


def lire_sauvegarde(chemin, variable):
    """Une SavedVariables de WoW, chargee dans un Lua a part et rendue en
    dictionnaires Python. Lecture seule : le fichier n'est jamais reecrit."""
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(open(chemin, encoding='utf-8', errors='replace').read())

    def conv(o):
        if hasattr(o, 'items') and not isinstance(o, (str, bytes)):
            return {(str(int(k)) if isinstance(k, float) and k.is_integer() else str(k)): conv(v) for k, v in o.items()}
        if isinstance(o, float) and o.is_integer():
            return int(o)
        return o
    return conv(lua.globals()[variable])


def liste(d):
    """Une table Lua a cles 1, 2, 3... devenue dict : dans l'ordre."""
    if isinstance(d, list):
        return d
    if not isinstance(d, dict):
        return []
    cles = [k for k in d if str(k).isdigit()]
    return [d[k] for k in sorted(cles, key=lambda k: int(k))]


# ===== Identifiants ========================================================
# Meme derivation que Brouillons.Identifiant (MJ/Brouillons.lua) : un nom
# importe et un nom saisi en jeu donnent le meme identifiant.

ACCENTS = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'À': 'a', 'Â': 'a', 'Ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'É': 'e', 'È': 'e', 'Ê': 'e', 'Ë': 'e',
    'î': 'i', 'ï': 'i', 'Î': 'i', 'Ï': 'i', 'ô': 'o', 'ö': 'o', 'Ô': 'o', 'Ö': 'o',
    'ù': 'u', 'û': 'u', 'ü': 'u', 'Ù': 'u', 'Û': 'u', 'Ü': 'u',
    'ç': 'c', 'Ç': 'c', 'ÿ': 'y', 'œ': 'oe', 'Œ': 'oe', 'æ': 'ae', 'Æ': 'ae',
}


def identifiant(nom):
    texte = ''.join(ACCENTS.get(c, c if ord(c) < 128 else '') for c in str(nom or ''))
    texte = re.sub(r'[^0-9a-zA-Z]+', '_', texte.lower()).strip('_')
    return texte


class Ids:
    """Distribue des identifiants uniques par famille."""

    def __init__(self):
        self.pris = {}

    def donner(self, famille, nom):
        base = identifiant(nom) or famille
        pris = self.pris.setdefault(famille, set())
        cle, n = base, 2
        while cle in pris:
            cle = '%s_%d' % (base, n)
            n += 1
        pris.add(cle)
        return cle


# ===== Statistiques ========================================================
# Clef Necronicon -> champ du schema de l'addon. Le template a des fautes de
# frappe dans ses clefs (« terreste », « ombre » pour la resistance a l'ombre,
# « champ_18 ») : elles sont resolues ici, une par une, et nulle part ailleurs.

TYPES = {
    'tranchant': 'tranchant', 'perforant': 'perforant', 'contondant': 'contondant',
    'feu': 'feu', 'eau': 'eau', 'air': 'vent', 'terre': 'terre', 'esprit': 'esprit',
    'pourriture': 'pourriture', 'lumiere': 'lumiere', 'ombre': 'ombre',
    'desordre': 'desordre', 'ordre': 'ordre', 'vie': 'vie', 'mort': 'mort',
}

MECANIQUES = {
    'attaquesimple': 'attaque_simple', 'attaque_simple': 'attaque_simple',
    'perce_armure': 'perce_armure', 'brise_armure': 'brise_armure', 'bouclier': 'bouclier',
    'soin': 'soin', 'buff': 'buff', 'debuff': 'debuff', 'attraction': 'attraction',
    'communication': 'communication', 'repulsion': 'repulsion', 'immobilisation': 'immobilisation',
    'entrave': 'entrave', 'deviation': 'deviation', 'levitation': 'levitation',
    'intervention': 'intervention', 'permutation': 'permutation', 'dissipation': 'dissipation',
    'creation': 'creation', 'confusion': 'confusion', 'controle_mental': 'controle_mental',
    'illusion': 'illusion',
}

DIRECTS = {
    'force', 'mystique', 'perception', 'adresse', 'esprit', 'constitution',
    'pa', 'fatigue', 'initiative',
    'vue', 'odorat_gout', 'ouie', 'toucher', 'investigation', 'elementaire', 'cosmique', 'pistage',
    'puissance', 'projection', 'prise', 'equilibre', 'escalade', 'resistance', 'endurance', 'course',
    'discretion', 'deguisement', 'vol_a_la_tire', 'crochetage', 'escamotage', 'evasion', 'sabotage',
    'force_attaque', 'mystique_attaque', 'perception_attaque', 'defense_constitution',
    'force_bouclier', 'mystique_bouclier', 'constitution_bouclier', 'mystique_soin', 'constitution_soin',
    'force_buff', 'mystique_buff', 'perception_buff', 'constitution_buff', 'duree_buff', 'puissance_buff',
    'force_perce_armure', 'mystique_perce_armure', 'perception_perce_armure',
    'force_brise_armure', 'mystique_brise_armure', 'perception_brise_armure',
    'force_provocation', 'constitution_provocation', 'esprit_provocation', 'mystique_provocation',
    'force_intimidation', 'constitution_intimidation', 'esprit_intimidation', 'mystique_intimidation',
    'force_saignement', 'mystique_saignement', 'perception_saignement',
    'mystique_empoisonnement', 'perception_empoisonnement', 'constitution_empoisonnement',
    'force_debuff', 'mystique_debuff', 'perception_debuff', 'constitution_debuff',
    'duree_debuff', 'puissance_debuff',
}

SPECIAUX = {
    'terreste': 'depl_terrestre', 'acrobatie': 'acrobaties', 'nage_2': 'nage',
    'champ_18': 'pen_feu', 'champ_99': 'force_perce_armure', 'ombre': 'resi_ombre',
}


def champ_stat(cle, dossier=''):
    """Le champ de l'addon vise par une clef de statistique, ou None."""
    brut = str(cle)
    if brut == 'nage':
        # Deux « Nage » dans le template : le deplacement (dossier Bonus) et
        # l'expertise (dossier Athletismes).
        return 'depl_nage' if dossier == 'Bonus' else 'nage'
    k = identifiant(brut)
    if k in SPECIAUX:
        return SPECIAUX[k]
    if k in DIRECTS:
        return k
    for prefixe in ('pen_', 'resi_'):
        if k.startswith(prefixe) and k[len(prefixe):] in TYPES:
            return prefixe + TYPES[k[len(prefixe):]]
    if k in MECANIQUES:
        return 'meca_' + MECANIQUES[k]
    return None


def nombre(v):
    try:
        n = float(str(v).replace(',', '.'))
    except (TypeError, ValueError):
        return None
    return int(n) if n.is_integer() else n


# ===== Ecriture Lua ========================================================

def chaine(s):
    s = str(s)
    s = s.replace(chr(92), chr(92) * 2).replace('"', chr(92) + '"')
    s = s.replace('\r', '').replace('\n', chr(92) + 'n')
    return '"' + s + '"'


IDENT = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')
RESERVES = {'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if', 'in',
            'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while'}


def cle_lua(k):
    if isinstance(k, str) and IDENT.match(k) and k not in RESERVES:
        return k
    return '[' + (chaine(k) if isinstance(k, str) else str(k)) + ']'


def lua(v, retrait=1, ordre=None):
    pad = '    ' * retrait
    if v is None:
        return 'nil'
    if v is True:
        return 'true'
    if v is False:
        return 'false'
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return chaine(v)
    if isinstance(v, list):
        if not v:
            return '{}'
        simples = all(isinstance(x, (str, int, float, bool)) for x in v)
        if simples and sum(len(lua(x)) for x in v) < 70:
            return '{ ' + ', '.join(lua(x) for x in v) + ' }'
        return '{\n' + ''.join(pad + lua(x, retrait + 1) + ',\n' for x in v) + '    ' * (retrait - 1) + '}'
    if isinstance(v, dict):
        if not v:
            return '{}'
        cles = list(v.keys())
        if ordre:
            cles = [k for k in ordre if k in v] + sorted(k for k in cles if k not in ordre)
        else:
            cles = sorted(cles, key=str)
        return '{\n' + ''.join(pad + cle_lua(k) + ' = ' + lua(v[k], retrait + 1) + ',\n' for k in cles) \
            + '    ' * (retrait - 1) + '}'
    raise TypeError(type(v))


ORDRE = ['id', 'label', 'liste', 'categorie', 'cout', 'morphology', 'icone', 'description',
         'tags', 'couleurTitre', 'couleurFond', 'pileMax', 'type', 'metiers', 'etat',
         'places', 'placesDevise', 'sacMJ', 'bonus', 'avantage']

ENTETE = """-- ============================================================================
--  FICHIER GENERE — NE PAS MODIFIER A LA MAIN
-- ============================================================================
--  Ecrit par Outils/importer_necronicon.py a partir du compendium Necronicon
--  « Systeme d'Aelskar »
--  (%s).
--  Toute retouche manuelle sera perdue au prochain import.
--
--  Pour changer une entree : la corriger en jeu (Compendium, mode MJ), puis
--  l'exporter comme un brouillon.
-- ============================================================================

local _, LCM = ...
"""


def bloc(registre, definition):
    return '%s.Add(%s)\n' % (registre, lua(definition, 1, ORDRE))


# ===== Conversion ==========================================================

def couleur(hexa, defaut):
    h = str(hexa or '').strip().lstrip('#').upper()
    if not re.match(r'^[0-9A-F]{6}$', h) or h == defaut:
        return None
    return h


def identite(e, valeurs):
    """Les champs de l'onglet General du template, communs a toutes les entrees."""
    d = {}
    icone = str(valeurs.get('icone') or '').strip()
    if icone and icone.lower() != 'interface\\icons\\inv_misc_questionmark':
        d['icone'] = icone
    description = str(valeurs.get('description') or '').strip()
    if description:
        d['description'] = description
    tags = str(e.get('tags') or '').strip()
    if tags:
        d['tags'] = tags
    titre = couleur(e.get('titleColor'), 'F2E6C6')
    if titre:
        d['couleurTitre'] = titre
    fond = couleur(e.get('bgColor'), '111111')
    if fond:
        d['couleurFond'] = fond
    return d


def etat_jauge(v):
    """La jauge « Etat » (durabilite) : retenue seulement si elle s'ecarte du
    defaut de la categorie (100 / 100)."""
    if not isinstance(v, dict):
        return None
    maximum = nombre(v.get('gaugeMax'))
    if maximum is None:
        maximum = nombre(v.get('gaugeMaxFormula'))
    courant = nombre(v.get('currentValue'))
    if courant is None:
        courant = nombre(v.get('currentValueFormula'))
    if maximum is None:
        return None
    if courant is None:
        courant = maximum
    if maximum == 100 and courant == 100:
        return None
    return {'courant': courant, 'max': maximum}


def effets(tab, valeurs, nom):
    """Les statistiques non nulles d'une entree generique -> bonus."""
    dossiers = {f.get('key'): (f.get('folder') or '') for f in liste(tab.get('fields'))}
    bonus = {}
    for f in liste(tab.get('fields')):
        if f.get('dataType') != 'statistic':
            continue
        cle = f.get('key')
        n = nombre(valeurs.get(cle))
        if not n:
            continue
        champ = champ_stat(cle, dossiers.get(cle, ''))
        if not champ:
            signaler('%s : statistique « %s » (%s) sans equivalent dans la fiche, ignoree (%s)'
                     % (nom, f.get('label'), cle, n))
            continue
        bonus[champ] = (bonus.get(champ) or 0) + n
    return bonus


def doublon(vus, e, tab_nom):
    """Une entree strictement identique a une entree deja vue (meme nom, memes
    valeurs) : le template contient des copies. On n'importe qu'un exemplaire,
    et on le dit. Renvoie l'identifiant Necronicon de l'original, ou None."""
    # L'identifiant technique (uid) change d'une copie a l'autre : il ne
    # compte pas.
    valeurs = {k: v for k, v in (e.get('values') or {}).items() if k != 'uid'}
    signature = json.dumps({'n': e.get('name'), 'v': valeurs}, sort_keys=True, ensure_ascii=False)
    if signature in vus:
        signaler('%s : « %s » (#%s) est une copie exacte de #%s, non importee'
                 % (tab_nom, e.get('name'), e.get('id'), vus[signature]))
        return vus[signature]
    vus[signature] = e.get('id')
    return None


SECONDAIRES = {'vitalite': 'sec_vitalite', 'fatigue': 'sec_fatigue', 'initiative': 'sec_initiative',
               'pointsdaction': 'sec_pa', 'deplacement': 'sec_deplacement',
               'penetration': 'sec_penetration', 'resistance': 'sec_resistance',
               'expertises': 'sec_expertises', 'mecaniquedecompetence': 'sec_mecanique'}


def tableau(o):
    """Les tables a cles 1, 2, 3... deviennent des listes, recursivement."""
    if isinstance(o, dict):
        if o and all(str(k).isdigit() for k in o):
            return [tableau(x) for x in liste(o)]
        return {k: tableau(x) for k, x in o.items()}
    if isinstance(o, list):
        return [tableau(x) for x in o]
    return o


def convertir(etat, extra=None):
    extra = extra or {}
    tabs = {t['name']: t for t in liste(etat.get('tabs'))}
    ids = Ids()
    contenu, resolutions, pnj, grimoires = [], [], [], []

    # Les identifiants Necronicon (« 207 ») des entrees de liste et de metier,
    # traduits une fois pour toutes.
    ref_liste, ref_metier = {}, {}
    LISTES = [('Type Armures', 'type_armures'), ('Liste Armes', 'armes'),
              ('Liste origine', 'origines'), ('Liste ressources', 'ressources')]
    for nom_tab, liste_id in LISTES:
        tab = tabs[nom_tab]
        contenu.append('\n-- ===== Liste : %s =====\n' % nom_tab)
        for e in liste(tab.get('entries')):
            v = e.get('values') or {}
            d = {'id': ids.donner('listes', e['name']), 'label': e['name'], 'liste': liste_id}
            d.update(identite(e, v))
            ref_liste[str(e['id'])] = d['id']
            contenu.append(bloc('LCM.Listes', d))
    for e in liste(tabs['Liste métiers'].get('entries')):
        ref_metier[str(e['id'])] = identifiant(e['name'])

    def metiers(v, nom):
        out = []
        for r in liste(v):
            m = ref_metier.get(str(r))
            if m:
                out.append(m)
            else:
                signaler('%s : metier #%s inconnu, ignore' % (nom, r))
        return out or None

    def type_liste(v, nom):
        choix = liste(v)
        if not choix:
            return None
        r = ref_liste.get(str(choix[0]))
        if not r:
            signaler('%s : type #%s introuvable dans les listes, ignore' % (nom, choix[0]))
        return r

    # ----- Information, devises --------------------------------------------
    for nom_tab, registre, famille in (('Information', 'LCM.Informations', 'informations'),
                                       ('Devises', 'LCM.Devises', 'devises')):
        contenu.append('\n-- ===== %s =====\n' % nom_tab)
        for e in liste(tabs[nom_tab].get('entries')):
            d = {'id': ids.donner(famille, e['name']), 'label': e['name']}
            d.update(identite(e, e.get('values') or {}))
            contenu.append(bloc(registre, d))

    # ----- Sacs ---------------------------------------------------------------
    contenu.append('\n-- ===== Sacs =====\n')
    for e in liste(tabs['Sacs'].get('entries')):
        v = e.get('values') or {}
        d = {'id': ids.donner('sacs', e['name']), 'label': e['name']}
        d.update(identite(e, v))
        d['places'] = nombre(v.get('slotcount')) or 12
        d['placesDevise'] = nombre(v.get('currencyslotcount')) or 0
        if v.get('gmbag') is True:
            d['sacMJ'] = True
        pile = nombre(e.get('maxStack'))
        if pile:
            d['pileMax'] = pile
        contenu.append(bloc('LCM.Sacs', d))

    # ----- Categories generiques (bloc de statistiques) ----------------------
    # (onglet du template, registre, famille d'identifiants, categorie fixe)
    GENERIQUES = [
        ('Ressources', 'LCM.Ressources', 'ressources', None),
        ('Armes', 'LCM.Objets', 'objets', 'arme'),
        ('Armures', 'LCM.Objets', 'objets', 'equipement'),
        ('Accessoires', 'LCM.Objets', 'objets', 'accessoire'),
        ('Races', 'LCM.Races', 'races', None),
        ('Traits', 'LCM.Traits', 'traits', None),
        ('Etats', 'LCM.Etats', 'etats', 'etat'),
        ('Maladies', 'LCM.Etats', 'etats', 'maladie'),
        ('Apprentissage', 'LCM.Apprentissages', 'apprentissages', None),
    ]
    PAR_ONGLET = {g[0]: g for g in GENERIQUES}
    # Le template range une tenue et une capuche dans « Armes » ; la fiche du
    # PNJ qui les porte les place dans « Armures et vetements ». C'est la fiche
    # qui a raison : un objet d'armure doit pouvoir s'equiper comme tel.
    RECLASSES = {"Tenue d'assassin du culte": 'equipement', "Capuche d'assassin du culte": 'equipement'}

    def generique(e, nom_tab, nom):
        _, registre, famille, categorie = PAR_ONGLET[nom_tab]
        tab = tabs[nom_tab]
        v = e.get('values') or {}
        d = {'id': ids.donner(famille, e['name']), 'label': e['name']}
        if categorie:
            d['categorie'] = RECLASSES.get(e['name'], categorie)
            if e['name'] in RECLASSES:
                signaler('%s : rangee en armure (le template la met dans Armes, la fiche du PNJ l\'equipe en armure)' % nom)
        d.update(identite(e, v))
        t = type_liste(v.get('test02'), nom)
        if t:
            d['type'] = t
        m = metiers(v.get('metier'), nom)
        if m:
            d['metiers'] = m
        j = etat_jauge(v.get('etat'))
        if j:
            d['etat'] = j
        b = effets(tab, v, nom)
        if b:
            d['bonus'] = b
        if registre == 'LCM.Races':
            d['morphology'] = 'humanoide'
        if registre == 'LCM.Traits':
            # Le template n'a pas de cout : le chiffre est dans les tags.
            cout = nombre(d.get('tags'))
            if cout and 1 <= cout <= 4:
                d['cout'] = int(cout)
                del d['tags']
            else:
                signaler('%s : aucun cout dans les tags, cout par defaut du registre (1)' % nom)
        if e['name'] == 'Nouvelle entree':
            signaler('%s : entree « Nouvelle entree » importee telle quelle (brouillon du template ?)' % nom)
        contenu.append(bloc(registre, d))
        return famille, d['id']

    ref_entree = {}
    for nom_tab, registre, famille, categorie in GENERIQUES:
        contenu.append('\n-- ===== %s =====\n' % nom_tab)
        vus = {}
        for e in liste(tabs[nom_tab].get('entries')):
            original = doublon(vus, e, nom_tab)
            if original is not None:
                # Ce qui designait la copie designe l'original.
                ref_entree[str(e['id'])] = ref_entree.get(str(original))
                continue
            ref_entree[str(e['id'])] = generique(e, nom_tab, '%s « %s »' % (nom_tab, e['name']))

    # ----- Entrees d'un ancien compendium, sauvees par leurs copies ----------
    # Le compendium « Aelskar » (window_custom_2) n'existe plus ; certaines de
    # ses entrees survivent en copie (connaissance apprise, inventaire). On les
    # reprend telles quelles, et ce qui les designait les retrouve.
    ref_ancien = {}
    if extra.get('orphelins'):
        contenu.append('\n-- ===== Reprises de l\'ancien compendium « Aelskar » =====\n')
    for o in extra.get('orphelins', []):
        nom = '%s « %s »' % (o['onglet'], o['entree']['name'])
        signaler('%s : reprise de l\'ancien compendium, depuis sa copie (%s)' % (nom, o['ou']))
        ref_ancien[o['id']] = generique(o['entree'], o['onglet'], nom)

    # ----- Connaissances -----------------------------------------------------
    contenu.append('\n-- ===== Connaissances =====\n')
    for e in liste(tabs['Connaissances'].get('entries')):
        v = e.get('values') or {}
        nom = 'Connaissance « %s »' % e['name']
        d = {'id': ids.donner('connaissances', e['name']), 'label': e['name']}
        d.update(identite(e, v))
        m = metiers(v.get('metier'), nom)
        if m:
            d['metiers'] = m
        if str(v.get('niveau') or '').strip():
            d['niveau'] = str(v['niveau']).strip()

        def reference(brute):
            brute = str(brute or '').strip()
            if not brute:
                return None
            m2 = re.match(r'^(.*)__(\d+)$', brute)
            if m2 and m2.group(1) == 'compendium_window_custom_29' and m2.group(2) in ref_entree:
                famille, eid = ref_entree[m2.group(2)]
                return famille + '/' + eid
            if m2 and m2.group(1) == 'compendium_window_custom_2' and m2.group(2) in ref_ancien:
                famille, eid = ref_ancien[m2.group(2)]
                return famille + '/' + eid
            signaler('%s : reference « %s » introuvable (ni dans le compendium, ni en copie), gardee telle quelle'
                     % (nom, brute))
            return 'necronicon/' + brute

        composants = []
        for r in liste(v.get('composants')):
            ref = reference(r.get('label'))
            if ref:
                composants.append({'ref': ref, 'quantite': nombre(r.get('value')) or 1})
        if composants:
            d['composants'] = composants
        prerequis = []
        for r in liste(v.get('prerequis')):
            texte = str(r.get('label') or '').strip()
            if not texte:
                continue
            if str(r.get('value')) == 'entry':
                prerequis.append({'ref': reference(texte)})
            else:
                prerequis.append({'texte': texte})
        if prerequis:
            d['prerequis'] = prerequis
        if str(v.get('fabrication')) in ('1', 'true', 'oui'):
            d['fabrication'] = True
        res = reference(v.get('fabricationresultat'))
        if res:
            d['resultat'] = res
        q = nombre(v.get('fabricationquantite'))
        if q and q != 1:
            d['quantite'] = q
        if str(v.get('peutetreappris')) in ('1', 'true', 'oui'):
            d['apprenable'] = True
        xp = nombre(v.get('fabricationxp'))
        if xp:
            d['xp'] = xp
        for source, cible in (('fabricationniveaurequis', 'niveauRequis'), ('fabricationxpplafond', 'xpPlafond')):
            if str(v.get(source) or '').strip():
                d[cible] = str(v[source]).strip()
        contenu.append(bloc('LCM.Connaissances', d))

    # ----- Resolutions d'action et calculateurs ------------------------------
    for nom_tab, categorie in (('Systeme-Résolution-Action', 'systeme'), ('Actions-MJ', 'mj')):
        resolutions.append('\n-- ===== %s =====\n' % nom_tab)
        vus = {}
        for e in liste(tabs[nom_tab].get('entries')):
            if doublon(vus, e, nom_tab) is not None:
                continue
            v = e.get('values') or {}
            d = {'id': ids.donner('resolutions', e['name']), 'label': e['name'], 'categorie': categorie}
            d.update(identite(e, v))
            if str(v.get('natures') or '').strip():
                d['natures'] = str(v['natures']).strip()
            if v.get('emission') is True:
                d['emission'] = True
            if v.get('debug') is True:
                d['debug'] = True
            feuilles = []
            for s in liste(v.get('sheets')):
                feuilles.append({'id': s.get('id'), 'nom': s.get('name'),
                                 'etapes': tableau(liste(s.get('steps')))})
            d['feuilles'] = feuilles
            resolutions.append(bloc('LCM.Resolutions', d))

    resolutions.append('\n-- ===== Calculateur =====\n')
    for e in liste(tabs['Calculateur'].get('entries')):
        v = e.get('values') or {}
        d = {'id': ids.donner('calculateurs', e['name']), 'label': e['name']}
        d.update(identite(e, v))
        if str(v.get('formule') or '').strip():
            d['formule'] = str(v['formule'])
        d['injections'] = [{'nom': r.get('label') or '', 'description': r.get('value') or ''}
                           for r in liste(v.get('injections'))]
        d['lignes'] = tableau(liste(v.get('lignes')))
        resolutions.append(bloc('LCM.Calculateurs', d))

    # ----- PNJ ---------------------------------------------------------------
    # Un PNJ Necronicon a une fiche par fenetre (Creation, Equipements...). On
    # les fond en un seul modele : ce que les fiches REPARTISSENT (niveau,
    # race, points) et ce qu'elles PORTENT (traits, equipement). Les formules,
    # elles, sont celles de l'addon.
    races_par_nom = {}
    for e in liste(tabs['Races'].get('entries')):
        races_par_nom.setdefault(e['name'], e)

    def fondre(nom, fiches):
        valeurs, traits, equipement = {}, [], {}
        for fenetre, st in fiches:
            st = st.get('state', st) if isinstance(st, dict) else {}
            for onglet in liste(st.get('tabs')):
                for en in liste(onglet.get('entries')):
                    if en.get('type') == 'field' and str(en.get('name', '')).startswith('Niveau du personnage'):
                        n = nombre(en.get('value'))
                        if n:
                            valeurs['niveau'] = n
                    pools = liste(en.get('allocPools'))
                    cache = (en.get('_allocInfoCache') or {}).get('info', {}).get('pools')
                    if cache:
                        pools = pools + [{'lines': {k: l for p in liste(cache) for k, l in (p.get('lines') or {}).items()}}]
                    for pool in pools:
                        lignes = pool.get('lines') if isinstance(pool, dict) else None
                        for l in liste(lignes) if isinstance(lignes, dict) else []:
                            tag = identifiant(l.get('tag'))
                            n = nombre(l.get('value'))
                            if not n:
                                continue
                            champ = SECONDAIRES.get(tag) if onglet.get('name') == 'Statistiques' and tag in SECONDAIRES else None
                            champ = champ or champ_stat(l.get('tag'))
                            if not champ:
                                signaler('%s (%s) : repartition « %s » sans equivalent, ignoree (%s)'
                                         % (nom, fenetre, l.get('tag'), n))
                                continue
                            valeurs[champ] = n
                    if en.get('type') != 'container':
                        continue
                    for c in liste(((en.get('storage') or {}).get('cells')) or {}):
                        objet = (c.get('entry') or {})
                        n_objet = c.get('name') or objet.get('name')
                        source = (objet.get('source') or {})
                        if not objet or n_objet in (None, 'Emplacement'):
                            continue
                        cible = ref_entree.get(str(source.get('entryId') or ''))
                        conteneur = en.get('name')
                        if conteneur == 'RACE':
                            race = races_par_nom.get(n_objet)
                            cible = race and ref_entree.get(str(race['id']))
                            if cible:
                                valeurs['race'] = cible[1]
                            else:
                                signaler('%s : race « %s » introuvable' % (nom, n_objet))
                            continue
                        if not cible:
                            if conteneur not in ('Statistiques', 'Parties corporelles', 'Existence'):
                                signaler('%s (%s) : « %s » dans « %s » introuvable dans le compendium'
                                         % (nom, fenetre, n_objet, conteneur))
                            continue
                        famille, ident = cible
                        if famille == 'traits' and ident not in traits:
                            traits.append(ident)
                        elif famille == 'objets':
                            cat = {'Armes principales': 'arme', 'Accessoires': 'accessoire'}.get(conteneur, 'equipement')
                            if ident not in equipement.get(cat, []):
                                equipement.setdefault(cat, []).append(ident)
        return valeurs, traits, equipement

    def ecrire_pnj(label, icone, valeurs, traits, equipement, e=None):
        d = {'id': ids.donner('pnj', label), 'label': label}
        if e is not None:
            d.update(identite(e, e.get('values') or {}))
        elif icone:
            d['icone'] = icone
        if valeurs:
            d['valeurs'] = valeurs
        if traits:
            d['traits'] = traits
        if equipement:
            d['equipement'] = equipement
        pnj.append(bloc('LCM.PNJ', d))

    fiches = liste(tabs['Fiches PNJ'].get('entries'))
    modeles = {}
    for e in liste(tabs['PNJ'].get('entries')):
        nom = 'PNJ « %s »' % e['name']
        prefixe = e['name'] + ' - '
        liees = [(f['name'][len(prefixe):], (f.get('values') or {}).get('ficheSnapshot') or {})
                 for f in fiches if str(f['name']).startswith(prefixe)]
        fondu = fondre(nom, liees)
        modeles[e['name']] = fondu
        ecrire_pnj(e['name'], None, *fondu, e=e)

    # Les PNJ vivants (instances de profil) : un PNJ identique a son modele du
    # compendium n'est pas recopie ; un autre l'est, sous son nom.
    for inst in extra.get('pnj', []):
        nom = 'PNJ vivant « %s »' % inst['nom']
        fondu = fondre(nom, inst['fiches'])
        if modeles.get(inst['nom']) == fondu:
            signaler('%s : identique au modele du compendium, non recopie' % nom)
            continue
        label = inst['nom'] if inst['nom'] not in modeles else inst['nom'] + ' (instance)'
        signaler('%s : repris depuis ses fenetres (%d fiches)' % (nom, len(inst['fiches'])))
        modeles[label] = fondu
        ecrire_pnj(label, inst.get('icone'), *fondu)

    # ----- Grimoires ---------------------------------------------------------
    # Repris en brut, en attendant la fenetre Grimoires : nom, description,
    # onglets et sorts (icone, description, champs, jet). Les liens vers des
    # agregateurs ou des macros Necronicon ne sont pas repris (ils visent des
    # fenetres qui n'existent pas ici) : c'est signale.
    vus = {}
    for g in extra.get('grimoires', []):
        signature = json.dumps(g['onglets'], sort_keys=True, ensure_ascii=False)
        if signature in vus:
            signaler('Grimoire « %s » : copie exacte de « %s », non importe' % (g['nom'], vus[signature]))
            continue
        vus[signature] = g['nom']
        d = {'id': ids.donner('grimoires', g['nom']), 'label': g['nom']}
        if g.get('description'):
            d['description'] = g['description']
        d['onglets'] = []
        for t in g['onglets']:
            sorts = []
            for sp in liste(t.get('spells')):
                nom_sort = str(sp.get('name') or 'Sort').strip()
                so = {'id': identifiant(nom_sort) or 'sort', 'label': nom_sort}
                icone = str(sp.get('icon') or '').strip()
                if icone and icone.lower() != 'interface\\icons\\inv_misc_questionmark':
                    so['icone'] = icone
                desc = str(sp.get('descriptionRaw') or sp.get('description') or '').strip()
                if desc:
                    so['description'] = desc
                for cle, cible in (('fieldOne', 'champ1'), ('fieldTwo', 'champ2'), ('shortcutMacroName', 'raccourci')):
                    if str(sp.get(cle) or '').strip():
                        so[cible] = str(sp[cle]).strip()
                if sp.get('actionRollEnabled') is True:
                    so['jet'] = {k2: sp[k1] for k1, k2 in (('actionRollMin', 'min'), ('actionRollMax', 'max'),
                                 ('actionRollIcon', 'icone'), ('actionRollFormula', 'formule'),
                                 ('actionRollBonus', 'bonus'), ('actionRollStatRef', 'stat'))
                                 if str(sp.get(k1) or '').strip()}
                if str(sp.get('actionExecAggregatorEntryId') or sp.get('actionRollAggregatorEntryId') or '').strip():
                    signaler('Grimoire « %s », sort « %s » : lien vers un agregateur Necronicon non repris'
                             % (g['nom'], nom_sort))
                sorts.append(so)
            d['onglets'].append({'nom': t.get('name') or 'Grimoire', 'sorts': sorts})
        grimoires.append(bloc('LCM.Grimoires', d))
    return contenu, resolutions, pnj, grimoires


def ecrire(nom, morceaux, source):
    chemin = os.path.join(GENERE, nom)
    with open(chemin, 'w', encoding='utf-8', newline='\n') as f:
        f.write(ENTETE % source)
        for m in morceaux:
            f.write(m)
    return chemin


def extra_depuis(necro):
    """Ce que la sauvegarde de Necronicon apporte en plus du compendium."""
    extra = {'orphelins': [], 'pnj': [], 'grimoires': []}
    profil = (necro.get('profiles') or {}).get('Template Fiche LVL 5 - Contes Malveillants V2') or {}

    # Entrees de l'ancien compendium, sauvees par leurs copies.
    vus = set()

    def orphelin(onglet, eid, entree, ou):
        if eid in vus:
            return
        vus.add(eid)
        extra['orphelins'].append({'onglet': onglet, 'id': eid, 'entree': entree, 'ou': ou})

    def parcourir(o):
        if isinstance(o, dict):
            sn = o.get('snapshot') if isinstance(o.get('snapshot'), dict) else None
            for cand in [sn, o.get('outputSnapshot') if isinstance(o.get('outputSnapshot'), dict) else None]:
                if cand and isinstance(cand.get('entry'), dict):
                    src = cand.get('source') or {}
                    cat = (cand.get('category') or {}).get('name')
                    if src.get('windowId') == 'window_custom_2' and cat == 'Ressources':
                        e = dict(cand['entry'])
                        orphelin('Ressources', str(e.get('id')), e, 'connaissance apprise')
            for v in o.values():
                parcourir(v)
    parcourir(((profil.get('windowStates') or {}).get('profession_sheet') or {}))
    for wid, w in (profil.get('inventoryWindows') or {}).items():
        for c in liste(w.get('categories')):
            for p in liste(c.get('placements')):
                e = p.get('entry') or {}
                src = e.get('source') or {}
                if src.get('compendiumId') == 'compendium:window_custom_2' and e.get('categoryType') == 'generic':
                    orphelin('Armes', str(src.get('entryId')), e, 'inventaire « %s »' % c.get('name'))

    # PNJ vivants : leurs fenetres de fiche.
    etats = (necro.get('sharedWindowStates') or {}).get('fiche') or {}
    fenetres = necro.get('sharedNpcWindows') or {}
    for pid, inst in sorted((necro.get('npcProfileInstances') or {}).items()):
        fiches = []
        for _, wid in sorted((inst.get('windowMap') or {}).items()):
            if wid in etats:
                nom_fenetre = str((fenetres.get(wid) or {}).get('name') or wid)
                fiches.append((nom_fenetre.split(' - ')[-1], etats[wid]))
        extra['pnj'].append({'nom': inst.get('name') or pid, 'icone': inst.get('icon'), 'fiches': fiches})

    # Grimoires : ceux du profil, puis ceux des PNJ.
    noms = {k: w.get('name') for k, w in (profil.get('menuWindows') or {}).items()}
    noms.update({k: w.get('name') for k, w in fenetres.items()})
    sources = list(((profil.get('windowStates') or {}).get('grimoire') or {}).items())
    sources += list(((necro.get('sharedWindowStates') or {}).get('grimoire') or {}).items())
    for wid, g in sources:
        nom = noms.get(wid)
        if not nom:
            nom = 'Grimoire sans fenetre (%s)' % wid
            signaler('%s : sa fenetre n\'existe plus dans le profil, nom deduit de son identifiant' % nom)
        extra['grimoires'].append({'nom': nom, 'description': str(g.get('description') or '').strip(),
                                   'onglets': liste(g.get('tabs'))})
    return extra


def main():
    args = sys.argv[1:]

    def option(nom, defaut):
        return args[args.index(nom) + 1] if nom in args else defaut
    pack = option('--pack', DEFAUT)
    dossier = option('--sauvegardes', SAUVEGARDES)
    systeme = os.path.join(dossier, 'Necronicon_System_Les_contes_Malveillants_MJ.lua')
    necro = os.path.join(dossier, 'necronicon.lua')
    extra = {}
    if os.path.isfile(systeme):
        db = lire_sauvegarde(systeme, 'NecroniconSystemLescontesMalveillantsMJDB')
        etat = db['compendiums']['aelskar']
        nom_source = 'sauvegarde ' + os.path.basename(os.path.dirname(dossier)) + '/' + os.path.basename(systeme)
    else:
        etat = lire_pack(pack, 'aelskar')
        nom_source = os.path.basename(os.path.dirname(pack)) + '/' + os.path.basename(pack)
    etat = etat.get('state', etat)
    if os.path.isfile(necro):
        extra = extra_depuis(lire_sauvegarde(necro, 'NecroniconDB'))
    contenu, resolutions, pnj, grimoires = convertir(etat, extra)
    for nom, morceaux in (('Compendium_Contenu.lua', contenu),
                          ('Compendium_Resolutions.lua', resolutions),
                          ('Compendium_PNJ.lua', pnj),
                          ('Necronicon_Grimoires.lua', grimoires)):
        print('ecrit : ' + os.path.relpath(ecrire(nom, morceaux, nom_source), DEPOT))
    if RAPPORT:
        print('\n%d remarque(s) :' % len(RAPPORT))
        for r in RAPPORT:
            print('  - ' + r)


if __name__ == '__main__':
    main()
