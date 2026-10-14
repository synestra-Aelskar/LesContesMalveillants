"""Decoupe les planches generees et emballe leur alpha en BLP2 / DXT5.

Usage : python Outils/campement_blp.py
Les PNG sources sont conserves pour permettre une nouvelle conversion.
"""
import io
from pathlib import Path
import struct
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'LesContesMalveillants/ressources/campement'
SOURCES = ROOT / 'Outils/sources/campement'


def exporter(image, nom, taille, opaque=False, plein=False):
    image = image.convert('RGBA')
    cadre = Image.new('RGBA', taille)
    marge=0 if opaque or plein else 8
    ratio=min((taille[0]-marge)/image.width,(taille[1]-marge)/image.height)
    image=image.resize((round(image.width*ratio),round(image.height*ratio)),Image.Resampling.LANCZOS)
    cadre.paste(image, ((taille[0]-image.width)//2, (taille[1]-image.height)//2))
    if opaque:
        cadre=image.resize(taille,Image.Resampling.LANCZOS)
        cadre.putalpha(255)
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
    tente=Image.open(SOURCES/'tente.png').convert('RGBA')
    exporter(tente.crop(tente.getbbox()),'tente',(1024,1024))
    feu=Image.open(SOURCES/'feu.png').convert('RGBA')
    largeur=feu.width//4
    frames=[feu.crop((i*largeur,0,(i+1)*largeur,feu.height)) for i in range(4)]
    boites=[f.getbbox() for f in frames]
    boite=(min(b[0] for b in boites),min(b[1] for b in boites),max(b[2] for b in boites),max(b[3] for b in boites))
    for i,frame in enumerate(frames):
        exporter(frame.crop(boite),'feu'+str(i+1),(512,512))
    exporter(Image.open(SOURCES/'lac-montagne.png'),'lac-montagne',(2048,1024),plein=True)
    ciel=Image.open(SOURCES/'ciel-pixel.png').convert('RGBA')
    for i,nom in enumerate(('ciel-nuit','ciel-aube')):
        morceau=ciel.crop((i*627,0,(i+1)*627,625)).convert('RGB')
        exporter(morceau,nom,(1024,1024),opaque=True)
    for nom,boite in [('lune',(120,730,510,1130)),('soleil',(675,690,1210,1185))]:
        morceau=ciel.crop(boite)
        exporter(morceau,nom,(256,256))


if __name__ == '__main__':
    main()
