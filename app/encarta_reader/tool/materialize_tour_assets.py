#!/usr/bin/env python3
"""Materialize the Acropolis 3-D tour into the app's BUNDLED Flutter assets
dir: assets/3dtours/acropolis/.

flutter_scene (see lib/src/screens/tours/spike/, Task-1 spike) only loads
models from bundled Flutter assets (rootBundle) — not arbitrary dart:io file
paths — so the quarry-derived tour data has to live under the app's own
`assets/` tree and be declared in pubspec.yaml's `flutter: assets:` list
(already done for `assets/3dtours/acropolis/`).

This is a thin, path-parameterized adaptation of the Task-1 spike's
lib/src/screens/tours/spike/pack_assets.py — same GLB-packing and
points-decimation logic, pointed at the canonical output dir instead of
assets/spike/. Run once per tour (currently only "acr"/Acropolis), or
re-run any time the quarry output regenerates:

    python3 tool/materialize_tour_assets.py

Output (assets/3dtours/acropolis/):
  acr.glb          - packed acr.gltf + acr.bin, single-file GLB for the
                      flutter_scene offline importer. ~14 MB; GITIGNORED
                      (regenerate with this script — see the sibling
                      .gitignore in the output dir).
  acr_points.bin   - decimated statue POINTS (POSITION + COLOR_0), for
                      billboard-quad rendering. COMMITTED (small). Format:
                        u32   count
                        f32[count*3]  positions, PLANAR (all x,y,z triples
                                      back-to-back — NOT interleaved with
                                      color)
                        f32[count*3]  colors (r,g,b in [0,1]), PLANAR, same
                                      order as positions
                      i.e. total bytes = 4 + count*3*4 + count*3*4.
                      Read position i at offset 4 + i*12 (3 floats), color i
                      at offset 4 + count*12 + i*12 (3 floats).
  acr.scene.json     - copied verbatim from quarry output. COMMITTED.
  acr.hotspots.json  - copied verbatim from quarry output. COMMITTED.
"""
import json
import os
import shutil
import struct

SRC = "/Users/nexus/projects/experiments/strata/quarry/output/3dvt/acr"
OUT_ASSETS = os.path.normpath(
    os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "..",
        "assets",
        "3dtours",
        "acropolis",
    )
)
os.makedirs(OUT_ASSETS, exist_ok=True)

gltf = json.load(open(os.path.join(SRC, "acr.gltf")))
binblob = open(os.path.join(SRC, "acr.bin"), "rb").read()

# ---- 1. Build a GLB (embed the single .bin buffer) ----
# Our glTF has exactly one buffer with uri acr.bin. Rewrite it to a GLB.
assert len(gltf["buffers"]) == 1, gltf["buffers"]
g = json.loads(json.dumps(gltf))  # deep copy
# GLB binary chunk must be 4-byte aligned
bin_padded = binblob + b"\x00" * ((4 - len(binblob) % 4) % 4)
g["buffers"][0].pop("uri", None)
g["buffers"][0]["byteLength"] = len(binblob)
json_bytes = json.dumps(g, separators=(",", ":")).encode("utf-8")
json_padded = json_bytes + b" " * ((4 - len(json_bytes) % 4) % 4)


def chunk(data, typ):
    return struct.pack("<II", len(data), typ) + data


glb = b"glTF" + struct.pack("<II", 2, 12 + 8 + len(json_padded) + 8 + len(bin_padded))
glb += chunk(json_padded, 0x4E4F534A)  # JSON
glb += chunk(bin_padded, 0x004E4942)  # BIN
glb_path = os.path.join(OUT_ASSETS, "acr.glb")
open(glb_path, "wb").write(glb)
print(f"wrote {glb_path}  ({len(glb)} bytes)  [gitignored, regenerable]")

# ---- 2. Extract decimated POINTS (positions + colors) ----
acc = gltf["accessors"]
bvs = gltf["bufferViews"]
COMP = {5126: ("f", 4)}  # float32
TYPEN = {"VEC3": 3, "VEC4": 4, "SCALAR": 1}


def read_accessor(ai):
    a = acc[ai]
    bv = bvs[a["bufferView"]]
    n = TYPEN[a["type"]]
    fmt, size = COMP[a["componentType"]]
    stride = bv.get("byteStride", n * size)
    base = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    out = []
    for i in range(a["count"]):
        off = base + i * stride
        vals = struct.unpack_from("<" + fmt * n, binblob, off)
        out.append(vals)
    return out


# Find POINTS prims (mode 0)
point_meshes = []
for mi, m in enumerate(gltf["meshes"]):
    for p in m["primitives"]:
        if p.get("mode", 4) == 0:
            point_meshes.append((mi, m.get("name", ""), p))

TARGET = 50000
total_pts = sum(acc[p["attributes"]["POSITION"]]["count"] for _, _, p in point_meshes)
# global decimation stride to land <= TARGET across all meshes
stride_g = max(1, (total_pts + TARGET - 1) // TARGET)
print(f"total points {total_pts}, decimation stride {stride_g}")

# emit: little-endian; header u32 count; then all positions (planar xyz),
# then all colors (planar rgb) — see module docstring for the exact layout.
positions = []
colors = []
kept = 0
for mi, name, p in point_meshes:
    pos = read_accessor(p["attributes"]["POSITION"])
    col = read_accessor(p["attributes"]["COLOR_0"])
    for i in range(0, len(pos), stride_g):
        positions.extend(pos[i])
        c = col[i]
        colors.extend((c[0], c[1], c[2]))
        kept += 1
print(f"kept {kept} points after decimation")

buf = struct.pack("<I", kept)
buf += struct.pack("<" + "f" * len(positions), *positions)
buf += struct.pack("<" + "f" * len(colors), *colors)
pts_path = os.path.join(OUT_ASSETS, "acr_points.bin")
open(pts_path, "wb").write(buf)
print(f"wrote {pts_path}  ({len(buf)} bytes, {kept} pts)  [committed]")

# ---- 3. Copy the small scene/hotspots JSON verbatim ----
for name in ("acr.scene.json", "acr.hotspots.json"):
    src = os.path.join(SRC, name)
    dst = os.path.join(OUT_ASSETS, name)
    shutil.copyfile(src, dst)
    print(f"copied {src} -> {dst}  [committed]")

# ---- 4. Walkmap sidecar (COMMITTED): the .3wm mesh's triangles, flattened ----
# The .3wm is the original engine's walkmap (walkable ground). The reader's
# Walkmap ground solver (packages/encarta_3dtours) consumes this flat soup:
#   u32 triCount ; triCount * 9 f32 (three xyz vertices per triangle), LE.
wm_tris = []
for m in gltf["meshes"]:
    if not m["name"].lower().endswith(".3wm"):
        continue
    for prim in m["primitives"]:
        if prim.get("mode", 4) != 4 or "indices" not in prim:
            continue
        pos_acc = gltf["accessors"][prim["attributes"]["POSITION"]]
        pos_off = gltf["bufferViews"][pos_acc["bufferView"]]["byteOffset"]
        verts = struct.unpack_from(f"<{pos_acc['count'] * 3}f", binblob, pos_off)
        idx_acc = gltf["accessors"][prim["indices"]]
        idx_off = gltf["bufferViews"][idx_acc["bufferView"]]["byteOffset"]
        fmt = {5125: "I", 5123: "H"}[idx_acc["componentType"]]
        idx = struct.unpack_from(f"<{idx_acc['count']}{fmt}", binblob, idx_off)
        for i in idx:
            wm_tris.extend(verts[i * 3 : i * 3 + 3])

walk_path = os.path.join(OUT_ASSETS, "acr_walkmap.bin")
with open(walk_path, "wb") as f:
    f.write(struct.pack("<I", len(wm_tris) // 9))
    f.write(struct.pack(f"<{len(wm_tris)}f", *wm_tris))
print(f"wrote {walk_path}  ({len(wm_tris) // 9} tris)  [committed]")

# Also compute mesh bbox center + radius for camera framing (diagnostic only)
mn = [1e30] * 3
mx = [-1e30] * 3
for a in acc:
    if a.get("type") == "VEC3" and "min" in a and a.get("componentType") == 5126:
        for k in range(3):
            mn[k] = min(mn[k], a["min"][k])
            mx[k] = max(mx[k], a["max"][k])
center = [(mn[k] + mx[k]) / 2 for k in range(3)]
size = [mx[k] - mn[k] for k in range(3)]
print("BBOX center", center, "size", size)
