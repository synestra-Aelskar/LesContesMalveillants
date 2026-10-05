"""Transforme les brouillons du MJ en fichiers Lua de l'addon.

Lit LCM_MJ_DB dans la SavedVariables du compagnon MJ, puis reecrit
Data/Genere/Atelier.lua. Ce fichier est ENTIEREMENT regenere : ce qui n'est plus
dans les brouillons disparait, et toute retouche manuelle est perdue.

    python exporter.py [--apercu]

TOUTES les familles de l'atelier y passent (5 octobre 2026). L'outil n'en
exportait que trois — traits, races, objets — donc les etats, les maladies, les
sacs, les PNJ, les resolutions et le reste restaient coinces dans la
SavedVariables d'une seule machine : crees en seance, jamais figes, invisibles
pour l'autre maitre du jeu.

Un SEUL fichier, et non un par famille : le .toc n'a qu'une ligne a declarer, et
ajouter une famille ne demande plus d'y toucher.

Le jeu doit avoir ete quitte (ou /reload fait) pour que la SavedVariables soit
a jour sur le disque : WoW n'ecrit qu'a la deconnexion.
"""
from lupa.lua51 import LuaRuntime
import io, os, sys, datetime

SAVED = r'F:\WOW EPSILON\Epsilon\Epsilon\_retail_\WTF\Account\SYNESTRA\SavedVariables\LesContesMalveillants_MJ.lua'
GENERE = r'F:\WOW EPSILON\Epsilon\Epsilon\_retail_\Interface\AddOns\LesContesMalveillants\Data\Genere'

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
        return '"' + valeur.replace('\\', '\\\\').replace('"', '\\"') + '"'

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


def ecrire_tout(par_famille, apercu):
    """Ecrit Atelier.lua : toutes les familles, dans un ordre stable.

    L'ordre compte pour la relecture d'un diff : a contenu egal, le fichier doit
    etre octet pour octet le meme d'un export a l'autre, sinon chaque export
    ressemble a un changement."""
    corps = [ENTETE.format(date=datetime.datetime.now().strftime('%Y-%m-%d %H:%M'))]
    total = 0
    for famille in sorted(par_famille.keys()):
        registre, entrees = par_famille[famille]
        if not entrees:
            continue
        corps.append('-- ----- %s (%d) %s\n'
                     % (famille, len(entrees), '-' * max(0, 56 - len(famille))))
        for identifiant in sorted(entrees.keys()):
            corps.append('LCM.%s.Add(%s)\n\n' % (registre, lua_valeur(entrees[identifiant])))
        total += len(entrees)
    if total == 0:
        corps.append('-- Aucune entree creee en seance.\n')
    texte = ''.join(corps).rstrip() + '\n'

    chemin = os.path.join(GENERE, 'Atelier.lua')
    if apercu:
        print(texte)
    else:
        io.open(chemin, 'w', encoding='utf-8', newline='\n').write(texte)
    return total


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
    }

    par_famille, inconnues = {}, []
    for cle in brouillons.keys():
        famille = str(cle)
        if famille not in familles:
            inconnues.append(famille)
            continue
        table = brouillons[cle]
        entrees = {}
        if table is not None:
            for identifiant in table.keys():
                entrees[str(identifiant)] = table[identifiant]
        if entrees:
            par_famille[famille] = (familles[famille], entrees)

    total = ecrire_tout(par_famille, apercu)

    if inconnues:
        print('')
        print('ATTENTION : famille(s) inconnue(s) de cet outil, NON exportee(s) : '
              + ', '.join(sorted(inconnues)))
        print("Ajoute-la(les) a `familles` dans exporter.py, sinon ce contenu reste")
        print("sur cette machine et n'arrivera jamais chez l'autre.")

    if not apercu:
        print('')
        for famille in sorted(par_famille.keys()):
            print('  %-16s %d' % (famille, len(par_famille[famille][1])))
        print('%d entree(s) exportee(s) dans Genere/Atelier.lua.' % total)
        print("Pense a publier l'addon, puis a faire mettre a jour tout le monde.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
