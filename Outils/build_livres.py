"""Regenere les ouvrages BLP a partir des sources locales."""
from pathlib import Path
import os, subprocess, sys

root = Path(__file__).resolve().parents[1]
subprocess.run(['node', str(root/'Outils/livres_sources.js')], check=True)
for theme in ('chronique', 'astral', 'herbier', 'necronicon'):
    env = dict(os.environ, LCM_LIVRES_SOURCE=str(root/'Outils/sources/livres/rendus'/theme))
    subprocess.run([sys.executable, str(root/'Outils/livres_atlas.py'), '--output',
                    str(root/'LesContesMalveillants/ressources/livres'/theme)], env=env, check=True)
