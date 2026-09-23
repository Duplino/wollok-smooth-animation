#!/usr/bin/env python3
"""
Genera los frames de una animación reversible en la que un sprite se desliza
fuera de su celda, en los ejes horizontal (h) y vertical (v).

Para "pepita.png" crea la carpeta "pepita/" con:
    0.png                   -> posición central (sin desplazamiento)
    h1.png ... hn.png       -> desplazamiento hacia la derecha
    h-1.png ... h-n.png     -> desplazamiento hacia la izquierda
    v1.png ... vn.png       -> desplazamiento hacia arriba
    v-1.png ... v-n.png     -> desplazamiento hacia abajo

El frame n (y -n) es el sprite completamente afuera de la celda, así que
un contador de -n a n recorre la animación completa en cualquier sentido.
La convención de signos sigue a Wollok: x crece a la derecha, y crece hacia arriba.

Uso:
    python generar_sprites.py pepita.png                 # 10 frames por lado
    python generar_sprites.py pepita.png --frames 5
    python generar_sprites.py pepita.png --paso 5        # 5px por frame
    python generar_sprites.py pepita.png --ejes h        # solo horizontal
    python generar_sprites.py pepita.png --salida assets # crea assets/pepita/

Requiere Pillow:  pip install pillow
"""

import argparse
import math
from pathlib import Path

from PIL import Image


def calcular_offsets(tamanio, frames=None, paso=None):
    """Desplazamiento en px para los frames 1..n. El último siempre es
    `tamanio`, o sea, el sprite completamente afuera."""
    if paso:
        frames = math.ceil(tamanio / paso)
        return [min(paso * i, tamanio) for i in range(1, frames + 1)]
    return [round(tamanio * i / frames) for i in range(1, frames + 1)]


def desplazar(original, dx, dy):
    ancho, alto = original.size
    frame = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    frame.paste(original, (dx, dy), original)
    return frame


def generar(ruta_png, ejes, frames, paso, carpeta_base):
    original = Image.open(ruta_png).convert("RGBA")
    ancho, alto = original.size
    carpeta = carpeta_base / Path(ruta_png).stem
    carpeta.mkdir(parents=True, exist_ok=True)

    creados = {}
    creados["0.png"] = desplazar(original, 0, 0)

    if "h" in ejes:
        for i, off in enumerate(calcular_offsets(ancho, frames, paso), start=1):
            creados[f"h{i}.png"] = desplazar(original, off, 0)    # derecha
            creados[f"h-{i}.png"] = desplazar(original, -off, 0)  # izquierda

    if "v" in ejes:
        for i, off in enumerate(calcular_offsets(alto, frames, paso), start=1):
            # En la imagen "y" crece hacia abajo, por eso se invierte el signo
            creados[f"v{i}.png"] = desplazar(original, 0, -off)   # arriba
            creados[f"v-{i}.png"] = desplazar(original, 0, off)   # abajo

    for nombre, imagen in creados.items():
        imagen.save(carpeta / nombre)

    return carpeta, list(creados)


def main():
    p = argparse.ArgumentParser(description="Genera frames reversibles de un sprite saliendo de su celda.")
    p.add_argument("png", help="PNG de entrada, con el sprite centrado")
    grupo = p.add_mutually_exclusive_group()
    grupo.add_argument("--frames", type=int, help="Frames por lado, n (default: 10)")
    grupo.add_argument("--paso", type=int, help="Píxeles por frame (alternativa a --frames)")
    p.add_argument("--ejes", nargs="+", choices=["h", "v"], default=["h", "v"],
                   help="Ejes a generar (default: h v)")
    p.add_argument("--salida", default=".",
                   help="Carpeta donde se crea la carpeta del sprite (default: actual)")
    args = p.parse_args()

    frames = args.frames if (args.frames or args.paso) else 10
    carpeta, nombres = generar(args.png, args.ejes, frames, args.paso, Path(args.salida))
    print(f"Se crearon {len(nombres)} frames en '{carpeta}/'")


if __name__ == "__main__":
    main()