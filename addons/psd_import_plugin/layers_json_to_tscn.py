#!/usr/bin/env python3
"""Genera un file .tscn da layers.json (stesso output dell'importer Godot).
Uso: python layers_json_to_tscn.py <cartella_layers> [nome_scena]
Es: python layers_json_to_tscn.py Landscape/Sprites/Lake_1_layers Lake_1
Scrive: Landscape/Sprites/Lake_1.tscn
"""
import json
import os
import sys

def main():
    if len(sys.argv) < 2:
        print("Uso: python layers_json_to_tscn.py <cartella_layers> [nome_scena]", file=sys.stderr)
        sys.exit(1)
    layers_dir = os.path.abspath(sys.argv[1])
    base_name = sys.argv[2] if len(sys.argv) >= 3 else os.path.basename(layers_dir).replace("_layers", "")
    json_path = os.path.join(layers_dir, "layers.json")
    if not os.path.isfile(json_path):
        print("File non trovato:", json_path, file=sys.stderr)
        sys.exit(1)
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    layers = data.get("layers", [])
    if not layers:
        print("Nessun layer in layers.json", file=sys.stderr)
        sys.exit(1)
    # Bounding box e centro
    min_x = min(l["left"] for l in layers)
    min_y = min(l["top"] for l in layers)
    max_x = max(l["left"] + l["width"] for l in layers)
    max_y = max(l["top"] + l["height"] for l in layers)
    cx = (min_x + max_x) * 0.5
    cy = (min_y + max_y) * 0.5
    # Percorso res:// = primo argomento con slash (es. Landscape/Sprites/Lake_1_layers)
    res_path = "res://" + sys.argv[1].replace("\\", "/").rstrip("/")
    lines = ['[gd_scene load_steps=%d format=4 uid="uid://psd_lake1"]' % (1 + len(layers))]
    for i, layer in enumerate(layers):
        path = layer["path"]
        # path in res://
        tex_res = res_path.rstrip("/") + "/" + path.replace("\\", "/")
        lines.append('[ext_resource type="Texture2D" path="%s" id="tex_%d"]' % (tex_res, i + 1))
    lines.append("")
    lines.append('[node name="%s" type="Node2D"]' % base_name)
    for i, layer in enumerate(layers):
        left = layer["left"]
        top = layer["top"]
        w = layer["width"]
        h = layer["height"]
        px = left + w * 0.5 - cx
        py = top + h * 0.5 - cy
        name = (layer.get("name", "layer_%d" % i) or "layer_%d" % i).replace(" ", "_").replace(".", "_")
        lines.append("")
        lines.append('[node name="%s" type="Sprite2D" parent="."]' % name)
        lines.append('texture = ExtResource("tex_%d")' % (i + 1))
        lines.append('centered = true')
        lines.append('position = Vector2(%.2f, %.2f)' % (px, py))
    out_dir = os.path.dirname(layers_dir)
    out_path = os.path.join(out_dir, base_name + ".tscn")
    os.makedirs(out_dir, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print("Scritto:", out_path)

if __name__ == "__main__":
    main()
