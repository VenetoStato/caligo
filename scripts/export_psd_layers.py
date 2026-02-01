#!/usr/bin/env python3
"""
Esporta ogni livello di un file PSD come texture PNG separata.
Uso: python export_psd_layers.py <file.psd> [cartella_output]

Richiede: pip install psd-tools Pillow
Per effetti avanzati: pip install "psd-tools[composite]"
"""

import os
import sys
import re

def sanitize_filename(name):
    """Rendi il nome file sicuro per tutti i sistemi."""
    if not name or not name.strip():
        return "layer"
    name = re.sub(r'[<>:"/\\|?*]', '_', name)
    return name.strip()

def export_layer(layer, output_dir, prefix="", index=0):
    """Esporta un layer o un gruppo. Ritorna numero di file scritti."""
    written = 0
    try:
        from psd_tools import PSDImage
    except ImportError:
        print("ERRORE: Installa psd-tools e Pillow: pip install psd-tools Pillow")
        sys.exit(1)

    if layer.is_group():
        for i, child in enumerate(layer):
            sub_prefix = f"{prefix}{sanitize_filename(layer.name)}_" if layer.name else f"{prefix}group_"
            written += export_layer(child, output_dir, sub_prefix, i)
        return written

    # Layer con immagine (pixel, type, shape, etc.): prova composite()
    if not getattr(layer, 'visible', True):
        return 0
    try:
        img = layer.composite()
        if img is not None and img.size[0] > 0 and img.size[1] > 0:
            name = sanitize_filename(layer.name) or f"layer_{index}"
            base = f"{prefix}{name}".strip("_")
            path = os.path.join(output_dir, f"{base}.png")
            n = 0
            while os.path.exists(path):
                n += 1
                path = os.path.join(output_dir, f"{base}_{n}.png")
            img.save(path)
            print(f"  {path}")
            written += 1
    except Exception as e:
        print(f"  Salto '{getattr(layer, 'name', '?')}': {e}")
    return written

def main():
    if len(sys.argv) < 2:
        print("Uso: python export_psd_layers.py <file.psd> [cartella_output]")
        print("  Se cartella_output non è specificata, crea <nome_file>_layers/")
        sys.exit(1)

    psd_path = os.path.abspath(sys.argv[1])
    if not os.path.isfile(psd_path):
        print(f"File non trovato: {psd_path}")
        sys.exit(1)

    output_dir = os.path.abspath(sys.argv[2]) if len(sys.argv) >= 3 else (os.path.splitext(psd_path)[0] + "_layers")
    os.makedirs(output_dir, exist_ok=True)
    print(f"PSD: {psd_path}")
    print(f"Output: {output_dir}\n")

    from psd_tools import PSDImage
    psd = PSDImage.open(psd_path)
    total = 0
    for i, layer in enumerate(psd):
        total += export_layer(layer, output_dir, prefix="", index=i)
    psd.close()
    print(f"\nFatto: {total} texture salvate in {output_dir}")
    print("Importa la cartella in Godot per usare le texture.")

if __name__ == "__main__":
    main()
