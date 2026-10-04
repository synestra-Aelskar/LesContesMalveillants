"""Transforme les brouillons du MJ en fichiers Lua de l'addon.

Lit LCM_MJ_DB dans la SavedVariables du compagnon MJ, puis reecrit
Data/Genere/*.lua. Ces fichiers sont ENTIEREMENT regeneres : ce qui n'est plus
dans les brouillons disparait, et toute retouche manuelle est perdue.

    python exporter.py [--apercu]

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


def ecrire(nom_fichier, appel, entrees, apercu):
    chemin = os.path.join(GENERE, nom_fichier)
    corps = [ENTETE.format(date=datetime.datetime.now().strftime('%Y-%m-%d %H:%M'))]
    if not entrees:
        corps.append('-- Aucune entree.\n')
    else:
        for identifiant in sorted(entrees.keys()):
            corps.append(appel + '(' + lua_valeur(entrees[identifiant]) + ')\n\n')
    texte = ''.join(corps).rstrip() + '\n'
    if apercu:
        print('--- ' + nom_fichier + ' (' + str(len(entrees)) + ' entree(s))')
        print(texte)
    else:
        io.open(chemin, 'w', encoding='utf-8', newline='\n').write(texte)
        print('ecrit  %-14s %d entree(s)' % (nom_fichier, len(entrees)))


def main():
    apercu = '--apercu' in sys.argv
    brouillons, erreur = lire_sauvegarde(SAVED)
    if erreur:
        print('ERREUR : ' + erreur)
        return 1
    if brouillons is None:
        print('Aucun brouillon : rien a exporter.')
        return 0

    familles = {
        'traits': ('Traits.lua', 'LCM.Traits.Add'),
        'races': ('Races.lua', 'LCM.Races.Add'),
        'objets': ('Objets.lua', 'LCM.Objets.Add'),
    }
    total = 0
    for famille, (fichier, appel) in sorted(familles.items()):
        table = brouillons[famille] if famille in brouillons else None
        entrees = {}
        if table is not None:
            for cle in table.keys():
                entrees[str(cle)] = table[cle]
        total += len(entrees)
        ecrire(fichier, appel, entrees, apercu)

    if not apercu:
        print('')
        print('%d entree(s) exportee(s).' % total)
        print("Pense a publier l'addon, puis a faire mettre a jour tout le monde.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
