import json,os,collections

clut_dump = r"C:\Users\Public\Documents\Amiga Files\WinUAE\used_cluts"
this_dir = os.path.dirname(__file__)

rw_json = os.path.join(this_dir,"used_cluts.json")

with open(clut_dump,"rb") as f:
    dump = f.read()

used_cluts_ = dict()
if os.path.exists(rw_json):
    with open(rw_json) as f:
        used_cluts_ = json.load(f)

used_cluts = collections.defaultdict(list)
for k,v in used_cluts_.items():
    used_cluts[k] = v

for tile_index in range(256):
    for clut_index in range(128):
        offset = tile_index*128
        offset+=clut_index
        if dump[offset]:
            used_cluts[tile_index].append(clut_index)

with open(rw_json,"w") as f:
    json.dump(used_cluts,f,indent=2)
