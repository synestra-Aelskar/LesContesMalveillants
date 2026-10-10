"""Transforme les brouillons du MJ en fichiers Lua de l'addon.

Lit LCM_MJ_DB dans la SavedVariables du compagnon MJ, puis reecrit DEUX
fichiers, entierement regeneres a chaque fois :

    LesContesMalveillants/Data/Genere/Atelier.lua       -> livre a tout le monde
    LesContesMalveillants_MJ/Genere/Atelier_MJ.lua      -> reste chez les MJ

    python exporter.py [--apercu]

TOUTES les familles de l'atelier y passent (5 octobre 2026). L'outil n'en
exportait que trois — traits, races, objets — donc les etats, les maladies, les
sacs, les PNJ, les resolutions et le reste restaient coinces dans la
SavedVariables d'une seule machine : crees en seance, jamais figes, invisibles
pour l'autre maitre du jeu.

POURQUOI DEUX FICHIERS (6 octobre 2026). Tout partait dans l'addon des joueurs,
fiches de PNJ comprises : leurs statistiques, leur equipement, leurs resolutions
d'action. Un addon vit sur la machine du joueur — masquer une entree dans
l'interface ne protege rien, la seule protection est de ne pas livrer le
fichier. C'est deja la regle de importer_necronicon.py (RESERVE_MJ) ; l'export
des brouillons ne la suivait pas.

CE QUI NE SE PARTAGE PAS SUR `mjSeulement`. Une race « reservee au MJ » porte ce
drapeau, et elle doit pourtant partir chez les joueurs : le jour ou le MJ la
donne a quelqu'un, la fiche de ce joueur la reference, et son addon doit savoir
ce que c'est. Le drapeau dit qui peut la CHOISIR, pas qui peut la connaitre. Le
partage se fait donc par famille, et par categorie pour les resolutions.

Un seul fichier par cote, et non un par famille : le .toc n'a qu'une ligne a
declarer, et ajouter une famille ne demande plus d'y toucher.

Le jeu doit avoir ete quitte (ou /reload fait) pour que la SavedVariables soit
a jour sur le disque : WoW n'ecrit qu'a la deconnexion.
"""
from lupa.lua51 import LuaRuntime
import io, os, sys, datetime

SAVED = r'F:\WOW EPSILON\Epsilon\Epsilon\_retail_\WTF\Account\SYNESTRA\SavedVariables\LesContesMalveillants_MJ.lua'
GENERE = r'F:\WOW EPSILON\Epsilon\Epsilon\_retail_\Interface\AddOns\LesContesMalveillants\Data\Genere'
GENERE_MJ = r'F:\WOW EPSILON\Epsilon\Epsilon\_retail_\Interface\AddOns\LesContesMalveillants_MJ\Genere'

ENTETE = """-- ============================================================================
--  FICHIER GENERE — NE PAS MODIFIER A LA MAIN
-- ============================================================================
--  Ecrit par l'outil « Exporter les brouillons » le {date}.
--  Source : ce que le MJ a cree en jeu. Toute retouche manuelle sera perdue au
--  prochain export.
--
--  Pour changer une entree : la corriger en jeu, puis reexporter.
-- ============================================================================

local _, LCM = ...

"""

# Dans le compagnon MJ, le second argument d'un fichier d'addon est l'espace du
# compagnon, pas LCM : on prend LCM au global, comme les autres fichiers du
# compagnon. Et on sort si l'addon joueur n'est pas la — les registres y vivent,
# il n'y aurait rien ou ajouter.
ENTETE_MJ = ENTETE.replace(
    'local _, LCM = ...',
    'local LCM = _G.LCM\nif not LCM then return end')


def lire_sauvegarde(chemin):
    """Charge la SavedVariables (du Lua) et renvoie la table des brouillons."""
    if not os.path.isfile(chemin):
        return None, "fichier introuvable : " + chemin
    lua = LuaRuntime(unpack_returned_tuples=True)
    source = io.open(chemin, encoding='utf-8').read()
    try:
        lua.execute(source)
    except Exception as erreur:
        return None, "lecture impossible : " + str(erreur)
    db = lua.globals().LCM_MJ_DB
    if db is None:
        return None, "LCM_MJ_DB absent : le compagnon MJ n'a jamais ete charge ?"
    brouillons = db['brouillons'] if 'brouillons' in db else None
    return brouillons, None


# Ce qui doit etre echappe dans une chaine Lua entre guillemets. L'ordre compte :
# l'antislash d'abord, sinon on echapperait les antislashs qu'on vient de poser.
#
# Le RETOUR A LA LIGNE surtout : une description d'objet en tient souvent
# plusieurs, et Lua refuse un saut de ligne brut entre guillemets (« unfinished
# string »). Recopie tel quel, il rendait tout le fichier illisible — l'addon ne
# chargeait plus, et pas seulement l'entree fautive (6 octobre 2026).
ECHAPPEMENTS = [
    ('\\', '\\\\'),
    ('"', '\\"'),
    ('\r\n', '\\n'),
    ('\r', '\\n'),
    ('\n', '\\n'),
    ('\t', '\\t'),
]


def chaine_lua(valeur):
    for brut, echappe in ECHAPPEMENTS:
        valeur = valeur.replace(brut, echappe)
    # Le reste des caracteres de controle n'a rien a faire dans une chaine : on
    # les ecrit par leur code plutot que de les laisser passer en silence.
    return '"' + ''.join(
        c if ord(c) >= 32 or c == '\\' else '\\%d' % ord(c) for c in valeur) + '"'


def lua_valeur(valeur, indent=0):
    """Serialise une valeur Lua, lisible et stable (cles triees)."""
    marge = '    ' * indent
    if valeur is None:
        return 'nil'
    if isinstance(valeur, bool):
        return 'true' if valeur else 'false'
    if isinstance(valeur, (int, float)):
        if isinstance(valeur, float) and valeur.is_integer():
            return str(int(valeur))
        return str(valeur)
    if isinstance(valeur, str):
        return chaine_lua(valeur)

    # Table Lua (lupa) : partie tableau puis partie dictionnaire.
    cles = list(valeur.keys())
    numeriques = sorted([c for c in cles if isinstance(c, int)])
    textuelles = sorted([c for c in cles if isinstance(c, str)])

    if numeriques and not textuelles:
        elements = [lua_valeur(valeur[c], indent + 1) for c in numeriques]
        return '{ ' + ', '.join(elements) + ' }'

    lignes = []
    for cle in numeriques:
        lignes.append('    ' * (indent + 1) + lua_valeur(valeur[cle], indent + 1) + ',')
    for cle in textuelles:
        nom = cle if cle.isidentifier() else '["' + cle + '"]'
        lignes.append('    ' * (indent + 1) + nom + ' = ' + lua_valeur(valeur[cle], indent + 1) + ',')
    if not lignes:
        return '{}'
    return '{\n' + '\n'.join(lignes) + '\n' + marge + '}'


# Les familles qui ne quittent PAS le compagnon MJ.
#
#   pnj   : des fiches completes — statistiques, equipement, sorts. C'est le
#           materiel du MJ ; les livrer, c'est donner la reponse avant la
#           rencontre.
#   jeux  : les jeux d'equilibrage de la forge, c'est-a-dire le bareme de
#           construction : ce que coute chaque statistique, le pool de chaque
#           rarete. Un joueur ne forge jamais (la forge et l'atelier sont des
#           outils du compagnon MJ), et l'addon joueur se passe tres bien de
#           leur absence : une entree dont le jeu est inconnu s'affiche, elle ne
#           se VERIFIE pas, et seule la creation d'entree verifie.
RESERVE_MJ = {'pnj', 'jeux', 'points'}

# Les resolutions se partagent en deux par leur categorie (Core/Contenus.lua) :
# « systeme » decrit comment une action se resout — tout le monde en a besoin ;
# « mj » est une action que seul le MJ declenche.
CATEGORIE_RESOLUTION_MJ = 'mj'


def cote_de(famille, entree):
    """'mj' si cette entree reste chez le MJ, 'joueur' sinon."""
    if famille in RESERVE_MJ:
        return 'mj'
    if famille == 'resolutions':
        categorie = entree['categorie'] if entree is not None else None
        if str(categorie or '') == CATEGORIE_RESOLUTION_MJ:
            return 'mj'
    return 'joueur'


def corps_de(par_famille, entete):
    """Le texte d'un fichier, dans un ordre stable.

    L'ordre compte pour la relecture d'un diff : a contenu egal, le fichier doit
    etre octet pour octet le meme d'un export a l'autre, sinon chaque export
    ressemble a un changement."""
    corps = [entete.format(date=datetime.datetime.now().strftime('%Y-%m-%d %H:%M'))]
    total = 0
    for famille in sorted(par_famille.keys()):
        registre, entrees = par_famille[famille]
        if not entrees:
            continue
        corps.append('-- ----- %s (%d) %s\n'
                     % (famille, len(entrees), '-' * max(0, 56 - len(famille))))
        for identifiant in sorted(entrees.keys()):
            # Le contenu importe est charge avant Atelier.lua. Une correction
            # publiee avec le meme identifiant doit remplacer cette ancienne
            # version ; `Add` seul transforme cette situation normale en
            # erreur "en double" avant meme le chargement du compagnon MJ.
            corps.append('LCM.Publier(LCM.%s, %s)\n\n'
                         % (registre, lua_valeur(entrees[identifiant])))
        total += len(entrees)
    if total == 0:
        corps.append('-- Aucune entree creee en seance.\n')
    return ''.join(corps).rstrip() + '\n', total


def ecrire_tout(cotes, apercu):
    """Ecrit les deux fichiers et rend le compte de chacun.

    Les DEUX sont reecrits meme vides : une famille qui change de cote laisserait
    sinon sa copie d'avant en place, et le contenu existerait en double — ou
    continuerait de partir chez les joueurs apres qu'on a decide le contraire."""
    comptes = {}
    for cote, (dossier, nom, entete) in CIBLES.items():
        texte, total = corps_de(cotes.get(cote, {}), entete)
        comptes[cote] = total
        if apercu:
            print('=' * 78)
            print('%s  (%s, %d entree(s))' % (nom, cote, total))
            print('=' * 78)
            print(texte)
        else:
            io.open(os.path.join(dossier, nom), 'w',
                    encoding='utf-8', newline='\n').write(texte)
    return comptes


CIBLES = {
    'joueur': (GENERE, 'Atelier.lua', ENTETE),
    'mj': (GENERE_MJ, 'Atelier_MJ.lua', ENTETE_MJ),
}


def main():
    apercu = '--apercu' in sys.argv
    brouillons, erreur = lire_sauvegarde(SAVED)
    if erreur:
        print('ERREUR : ' + erreur)
        return 1
    if brouillons is None:
        print('Aucun brouillon : rien a exporter.')
        return 0

    # La meme table que Core/Compendium.lua (FAMILLES) : famille -> registre.
    # Tenue a deux endroits, donc verifiee au passage — une famille ajoutee en
    # jeu et oubliee ici repartirait silencieusement dans le vide.
    familles = {
        'objets': 'Objets', 'traits': 'Traits', 'races': 'Races', 'etats': 'Etats',
        'apprentissages': 'Apprentissages', 'sacs': 'Sacs', 'ressources': 'Ressources',
        'devises': 'Devises', 'informations': 'Informations', 'listes': 'Listes',
        'connaissances': 'Connaissances', 'resolutions': 'Resolutions',
        'calculateurs': 'Calculateurs', 'pnj': 'PNJ', 'jeux': 'Forge',
        'points': 'Points',
        'tentes': 'Tentes', 'accessoires_camping': 'AccessoiresCamping',
    }

    # Une famille peut nourrir les deux fichiers (les resolutions), d'ou le tri
    # entree par entree et non famille par famille.
    cotes, inconnues = {'joueur': {}, 'mj': {}}, []
    for cle in brouillons.keys():
        famille = str(cle)
        if famille not in familles:
            inconnues.append(famille)
            continue
        table = brouillons[cle]
        if table is None:
            continue
        for identifiant in table.keys():
            entree = table[identifiant]
            cote = cote_de(famille, entree)
            registre, entrees = cotes[cote].setdefault(famille, (familles[famille], {}))
            entrees[str(identifiant)] = entree

    comptes = ecrire_tout(cotes, apercu)

    if inconnues:
        print('')
        print('ATTENTION : famille(s) inconnue(s) de cet outil, NON exportee(s) : '
              + ', '.join(sorted(inconnues)))
        print("Ajoute-la(les) a `familles` dans exporter.py, sinon ce contenu reste")
        print("sur cette machine et n'arrivera jamais chez l'autre.")

    if not apercu:
        for cote in ('joueur', 'mj'):
            dossier, nom, _ = CIBLES[cote]
            print('')
            print('%s  (%s)' % (nom, 'livre a tout le monde' if cote == 'joueur'
                                else 'reste chez les MJ'))
            par_famille = cotes[cote]
            if not par_famille:
                print('  (rien)')
            for famille in sorted(par_famille.keys()):
                print('  %-16s %d' % (famille, len(par_famille[famille][1])))
            print('  = %d entree(s)' % comptes[cote])
        print('')
        print("Pense a publier les DEUX addons : le fichier du MJ ne part pas")
        print("avec celui des joueurs.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
