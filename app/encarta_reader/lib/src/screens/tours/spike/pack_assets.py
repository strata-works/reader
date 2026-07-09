#!/usr/bin/env python3
"""Pack acr.gltf + acr.bin into a single-file acr.glb for the flutter_scene
offline importer, and extract decimated statue POINTS (positions+colors) into
a compact binary the spike loads for billboard quads."""
import json, struct, os, sys

SRC = "/Users/nexus/projects/experiments/strata/quarry/output/3dvt/acr"
OUT_ASSETS = "/Users/nexus/projects/experiments/strata/reader/app/encarta_reader/assets/spike"
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
glb += chunk(bin_padded, 0x004E4942)   # BIN
glb_path = os.path.join(OUT_ASSETS, "acr.glb")
open(glb_path, "wb").write(glb)
print(f"wrote {glb_path}  ({len(glb)} bytes)")

# ---- 2. Extract decimated POINTS (positions + colors) ----
acc = gltf["accessors"]; bvs = gltf["bufferViews"]
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

# emit: little-endian; header: u32 count; then per point: 3 float pos, 3 float rgb
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
print(f"wrote {pts_path}  ({len(buf)} bytes, {kept} pts)")

# Also compute mesh bbox center + radius for camera framing
mn = [1e30]*3; mx=[-1e30]*3
for a in acc:
    if a.get("type")=="VEC3" and "min" in a and a.get("componentType")==5126:
        for k in range(3):
            mn[k]=min(mn[k],a["min"][k]); mx[k]=max(mx[k],a["max"][k])
center=[(mn[k]+mx[k])/2 for k in range(3)]
size=[mx[k]-mn[k] for k in range(3)]
print("BBOX center", center, "size", size)
