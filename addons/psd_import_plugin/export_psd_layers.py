#!/usr/bin/env python3
"""
Esporta ogni layer di un file PSD o PSB come PNG separato.
Richiede: pip install psd-tools Pillow

Uso:
  python export_psd_layers.py <file.psd|file.psb> [cartella_output]
  python export_psd_layers.py --flatten-only <file.psd|file.psb> <output.png>
  python export_psd_layers.py --for-godot <file.psd|file.psb> <cartella_output>
--for-godot: esporta ogni layer come PNG e scrive layers.json con posizioni (per import Godot).
"""

import json
import os
import sys
import re

def export_flatten_only(psd_path: str, output_png: str) -> bool:
    """Esporta solo l'immagine appiattita in un unico PNG. Usato dall'import Godot."""
    try:
        from psd_tools import PSDImage
    except ImportError:
        print("Installa: pip install psd-tools Pillow", file=sys.stderr)
        return False
    if not os.path.isfile(psd_path):
        print("File non trovato:", psd_path, file=sys.stderr)
        return False
    os.makedirs(os.path.dirname(os.path.abspath(output_png)) or ".", exist_ok=True)
    psd = PSDImage.open(psd_path)
    img = psd.composite()
    if img is None or img.size[0] == 0 or img.size[1] == 0:
        print("Impossibile creare immagine composita", file=sys.stderr)
        return False
    img.save(output_png)
    return True

def export_for_godot(psd_path: str, output_dir: str) -> bool:
    """Esporta ogni layer come PNG e scrive layers.json con path e bbox (left, top, width, height)."""
    try:
        from psd_tools import PSDImage
    except ImportError:
        print("Installa: pip install psd-tools Pillow", file=sys.stderr)
        return False
    if not os.path.isfile(psd_path):
        print("File non trovato:", psd_path, file=sys.stderr)
        return False
    os.makedirs(output_dir, exist_ok=True)
    psd = PSDImage.open(psd_path)
    base_name = os.path.splitext(os.path.basename(psd_path))[0]
    layers_info = []
    count = 0

    def do_layer(layer, prefix: str = ""):
        nonlocal count
        if layer.is_group():
            for child in layer:
                do_layer(child, prefix + sanitize_filename(layer.name) + "_")
            return
        try:
            img = layer.composite()
            if img is None or img.size[0] == 0 or img.size[1] == 0:
                return
            name = prefix + sanitize_filename(layer.name)
            if not name:
                name = "layer_%d" % count
            filename = "%s_%s.png" % (base_name, name)
            out_path = os.path.join(output_dir, filename)
            img.save(out_path)
            left, top, right, bottom = getattr(layer, "bbox", (0, 0, img.size[0], img.size[1]))
            w = right - left
            h = bottom - top
            layers_info.append({
                "path": filename,
                "left": int(left),
                "top": int(top),
                "width": int(w),
                "height": int(h),
                "name": name,
            })
            count += 1
        except Exception as e:
            print("Layer '%s' saltato: %s" % (getattr(layer, "name", "?"), e), file=sys.stderr)

    for layer in psd:
        do_layer(layer)

    if count == 0:
        try:
            img = psd.composite()
            if img and img.size[0] > 0 and img.size[1] > 0:
                filename = "%s_flattened.png" % base_name
                out_path = os.path.join(output_dir, filename)
                img.save(out_path)
                w, h = img.size
                layers_info.append({
                    "path": filename,
                    "left": 0,
                    "top": 0,
                    "width": w,
                    "height": h,
                    "name": "flattened",
                })
                count = 1
        except Exception as e:
            print("Export flattened fallito:", e, file=sys.stderr)

    if count == 0:
        print("Nessun layer esportato.", file=sys.stderr)
        return False
    json_path = os.path.join(output_dir, "layers.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump({"layers": layers_info}, f, indent=0)
    return True

def sanitize_filename(name: str) -> str:
    """Rende il nome sicuro per i file (niente slash, caratteri strani)."""
    name = re.sub(r'[<>:"/\\|?*]', '_', name)
    return name.strip() or "layer"

def main():
    if len(sys.argv) < 2:
        print("Uso: python export_psd_layers.py <file.psd> [cartella_output]", file=sys.stderr)
        sys.exit(1)
    if sys.argv[1] == "--flatten-only":
        if len(sys.argv) != 4:
            print("Uso: python export_psd_layers.py --flatten-only <file.psd|file.psb> <output.png>", file=sys.stderr)
            sys.exit(1)
        ok = export_flatten_only(os.path.abspath(sys.argv[2]), os.path.abspath(sys.argv[3]))
        sys.exit(0 if ok else 1)
    if sys.argv[1] == "--for-godot":
        if len(sys.argv) != 4:
            print("Uso: python export_psd_layers.py --for-godot <file.psd|file.psb> <cartella_output>", file=sys.stderr)
            sys.exit(1)
        ok = export_for_godot(os.path.abspath(sys.argv[2]), os.path.abspath(sys.argv[3]))
        sys.exit(0 if ok else 1)

    psd_path = os.path.abspath(sys.argv[1])
    if len(sys.argv) >= 3:
        output_dir = os.path.abspath(sys.argv[2])
    else:
        output_dir = os.path.dirname(psd_path)

    if not os.path.isfile(psd_path):
        print("File non trovato:", psd_path, file=sys.stderr)
        sys.exit(1)

    try:
        from psd_tools import PSDImage
        from PIL import Image
    except ImportError:
        print("Installa le dipendenze: pip install psd-tools Pillow", file=sys.stderr)
        sys.exit(1)

    os.makedirs(output_dir, exist_ok=True)
    psd = PSDImage.open(psd_path)
    base_name = os.path.splitext(os.path.basename(psd_path))[0]
    count = 0

    def export_layer(layer, prefix: str = ""):
        nonlocal count
        if layer.is_group():
            for child in layer:
                export_layer(child, prefix + sanitize_filename(layer.name) + "_")
            return
        try:
            img = layer.composite()
            if img is None or img.size[0] == 0 or img.size[1] == 0:
                return
            name = prefix + sanitize_filename(layer.name)
            if not name:
                name = "layer_%d" % count
            out_path = os.path.join(output_dir, "%s_%s.png" % (base_name, name))
            # Evita sovrascritture
            while os.path.exists(out_path):
                count += 1
                out_path = os.path.join(output_dir, "%s_%s_%d.png" % (base_name, name, count))
            img.save(out_path)
            count += 1
        except Exception as e:
            print("Layer '%s' saltato: %s" % (getattr(layer, 'name', '?'), e), file=sys.stderr)

    for layer in psd:
        export_layer(layer)

    if count == 0:
        # Fallback: esporta l'immagine flattenata
        try:
            img = psd.composite()
            if img and img.size[0] > 0 and img.size[1] > 0:
                out_path = os.path.join(output_dir, "%s_flattened.png" % base_name)
                img.save(out_path)
                count = 1
        except Exception as e:
            print("Export flattened fallito:", e, file=sys.stderr)

    if count == 0:
        print("Nessun layer esportato.", file=sys.stderr)
        sys.exit(1)
    sys.exit(0)

if __name__ == "__main__":
    main()
