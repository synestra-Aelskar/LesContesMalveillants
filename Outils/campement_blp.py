"""Decoupe les planches generees et emballe leur alpha en BLP2 / DXT5.

Usage : python Outils/campement_blp.py atlas.png feu.png
Les PNG sources sont conserves pour permettre une nouvelle conversion.
"""
import io
from pathlib import Path
import shutil
import struct
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'LesContesMalveillants/ressources/campement'
SOURCES = ROOT / 'Outils/sources/campement'


def exporter(image, nom, taille, opaque=False):
    image = image.convert('RGBA')
    cadre = Image.new('RGBA', taille)
    marge=0 if opaque else 8
    ratio=min((taille[0]-marge)/image.width,(taille[1]-marge)/image.height)
    image=image.resize((round(image.width*ratio),round(image.height*ratio)),Image.Resampling.LANCZOS)
    cadre.paste(image, ((taille[0]-image.width)//2, (taille[1]-image.height)//2))
    dds = io.BytesIO()
    cadre.save(dds, format='DDS', pixel_format='DXT5')
    contenu = dds.getvalue()[128:]
    assert len(contenu) == taille[0]*taille[1]
    offset = 148+1024
    entete = (b'BLP2' + struct.pack('<I4B2I', 1, 2, 8, 7, 0, *taille)
              + struct.pack('<16I', offset, *([0]*15))
              + struct.pack('<16I', len(contenu), *([0]*15)))
    cible = DEST / (nom+'.blp')
    cible.write_bytes(entete + bytes(1024) + contenu)
    # Relecture par le decodeur BLP independant de l'encodeur DDS.
    with Image.open(cible) as relu:
        relu.load()
        assert relu.size == taille and relu.mode == 'RGBA'
        alpha_min, alpha_max = relu.getchannel('A').getextrema()
        assert alpha_min == (255 if opaque else 0) and alpha_max >= 240
    print(nom, taille, len(contenu), 'alpha verifie')


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    SOURCES.mkdir(parents=True, exist_ok=True)
    for source, nom in zip(sys.argv[1:3], ('atlas-v2.png','feu.png')):
        cible = SOURCES / nom
        if Path(source).resolve() != cible.resolve():
            shutil.copyfile(source, cible)
    atlas = Image.open(SOURCES/'atlas-v2.png').convert('RGBA')
    # Coordonnees de cette planche, images isolees par des gouttieres transparentes.
    for nom, boite, taille in [
        ('foret',(0,0,638,650),(1024,1024)),
        ('sol',(640,450,1254,665),(1024,512)),
        ('tente',(0,670,627,1190),(512,512)),
    ]:
        morceau=atlas.crop(boite)
        boite_visible=morceau.getchannel('A').point(lambda a: 255 if a>16 else 0).getbbox()
        exporter(morceau.crop(boite_visible),nom,taille)
    feu=Image.open(SOURCES/'feu.png').convert('RGBA')
    largeur=feu.width//4
    frames=[feu.crop((i*largeur,0,(i+1)*largeur,feu.height)) for i in range(4)]
    boites=[f.getbbox() for f in frames]
    boite=(min(b[0] for b in boites),min(b[1] for b in boites),max(b[2] for b in boites),max(b[3] for b in boites))
    for i,frame in enumerate(frames):
        exporter(frame.crop(boite),'feu'+str(i+1),(256,256))
    exporter(Image.open(SOURCES/'ciel-cycle.png').convert('RGB'),'ciel-cycle',(1024,1024),opaque=True)


if __name__ == '__main__':
    main()
