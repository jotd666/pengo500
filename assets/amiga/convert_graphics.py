import os,re,bitplanelib,ast,json
from PIL import Image,ImageOps


import collections



this_dir = os.path.dirname(__file__)
src_dir = os.path.join(this_dir,"../../src/amiga")
ripped_tiles_dir = os.path.join(this_dir,"../tiles")
dump_dir = os.path.join(this_dir,"dumps")

dump_it = True

def dump_asm_bytes(*args,**kwargs):
    bitplanelib.dump_asm_bytes(*args,**kwargs,mit_format=True)




block_dict = {}

# hackish convert of c gfx table to dict of lists
# (Thanks to Mark Mc Dougall for providing the ripped gfx as C tables)
with open(os.path.join(this_dir,"..","pengo_gfx.c")) as f:
    block = []
    block_name = ""
    start_block = False

    for line in f:
        if "uint8" in line:
            # start group
            start_block = True
            if block:
                txt = "".join(block).strip().strip(";")
                block_dict[block_name] = {"size":size,"data":ast.literal_eval(txt)}
                block = []
            block_name = line.split()[1].split("[")[0]
            size = int(line.split("[")[2].split("]")[0])
        elif start_block:
            line = re.sub("//.*","",line)
            line = line.replace("{","[").replace("}","]")
            block.append(line)

    if block:
        txt = "".join(block).strip().strip(";")
        block_dict[block_name] = {"size":size,"data":ast.literal_eval(txt)}



NB_POSSIBLE_SPRITES = 128


palette = block_dict["palette"]["data"]
# 19 unique colors
##print(palette)
##print(len({tuple(x) for x in palette}))
# looks that there are only 32 cluts for 16 colors totol

palette = [tuple(x) for x in palette]

with open(os.path.join(src_dir,"palette.68k"),"w") as f:
    bitplanelib.palette_dump(palette,f,pformat=bitplanelib.PALETTE_FORMAT_ASMGNU)

# for some reason, colors 1 and 2 of the cluts must be swapped to match
# the palette! invert the colors back for perfect coloring of sprites & tiles!!
bg_cluts = block_dict["clut"]["data"]
bg_cluts = [[clut[0],clut[2],clut[1],clut[3]] for clut in bg_cluts]

cluts = bg_cluts[:32]

character_codes_list = list()


rgb_cluts = [[tuple(palette[pidx]) for pidx in clut] for clut in cluts]

with open(os.path.join(src_dir,"palette_cluts.68k"),"w") as f:
    for clut in rgb_cluts:
        rgb4 = [bitplanelib.to_rgb4_color(x) for x in clut]
        bitplanelib.dump_asm_bytes(rgb4,f,mit_format=True,size=2)

for k,chardat in enumerate(block_dict["tile"]["data"]):
    img = Image.new('RGB',(8,8))

    character_codes = list()
    for cidx,colors in enumerate(rgb_cluts):
        if cidx < 32:
            local_palette = palette[0:16]
            pshift = 0
        else:
            local_palette = palette[16:]
            pshift = 16
        d = iter(chardat)
        for i in range(8):
            for j in range(8):
                v = next(d)
                img.putpixel((j,i),colors[v])
        character_codes.append(bitplanelib.palette_image2raw(img,None,local_palette))
    character_codes_list.append(character_codes)

##    if dump_it:
##        scaled = ImageOps.scale(img,5,0)
##        scaled.save(os.path.join(dump_dir,f"char_{k:02x}.png"))

with open(os.path.join(this_dir,"sprite_config.json")) as f:
    sprite_config = {int(k):v for k,v in json.load(f).items()}

for j,c in enumerate(["pengo","snobee"]):
    for i in range(0x8):
        sprite_config[0x20*j+i+0x40] = {"name":f"{c}_zooming_front_left{i}"}
    for i in range(0x10):
        sprite_config[0x20*j+i+0x48] = {"name":f"{c}_zooming_back_left{i}"}
    for i in range(0x8):
        sprite_config[0x20*j+i+0x58] = {"name":f"{c}_zooming_left_{i}"}
# remove the remainder of pacman sprite sheet
del sprite_config[0x39]


##for i in range(NB_POSSIBLE_SPRITES):
##    if i not in sprite_config:
##        sprite_config[i] = {"cluts":[1],"name":"wtf_{}".format(i)}
##    else:
##        sprite_config[i].pop("mirror",None)
##        sprite_config[i].pop("clip_right",None)
##with open(os.path.join(this_dir,"sprite_config2.json"),"w") as f:
##    json.dump(sprite_config,f,indent=2,sort_keys=True)

sprites = collections.defaultdict(dict)

clut_index = 12  # temp

bg_cluts_bank_0 = [[tuple(palette[pidx]) for pidx in clut] for clut in bg_cluts[0:16]]
# second bank
bg_cluts_bank_1 = [[tuple(palette[pidx]) for pidx in clut] for clut in bg_cluts[16:]]


# pick a clut index with different colors
# it doesn't matter which one
for clut in bg_cluts:
    if len(clut)==len(set(clut)):
        spritepal = clut
        break
else:
    # can't happen
    raise Exception("no way jose")

# convert our picked palette to RGB
spritepal = [tuple(palette[pidx]) for pidx in spritepal]

for k,data in sprite_config.items():
    sprdat = block_dict["sprite"]["data"][k]

    d = iter(sprdat)
    img = Image.new('RGB',(16,16))
    y_start = 0


    for i in range(16):
        for j in range(16):
            v = next(d)
            if j >= y_start:
                img.putpixel((j,i),spritepal[v])

    spr = sprites[k]
    spr["name"] = data['name']
    mirror = "left" in data["name"]

    right = None
    outname = f"{k:02x}_{clut_index}_{data['name']}.png"

    left = bitplanelib.palette_image2sprite(img,None,spritepal)
    if mirror:
        right = bitplanelib.palette_image2sprite(ImageOps.mirror(img),None,spritepal)

    spr["left"] = left
    spr["right"] = right

    if dump_it:
        scaled = ImageOps.scale(img,5,0)
        scaled.save(os.path.join(dump_dir,outname))



with open(os.path.join(src_dir,"graphics.68k"),"w") as f:
    f.write("\t.global\tcharacter_table\n")
    f.write("\t.global\tsprite_table\n")
#    f.write("\t.global\thw_sprite_flag_table\n")
    f.write("\t.global\tbg_cluts\n")
#    f.write("hw_sprite_flag_table:")
#    bitplanelib.dump_asm_bytes(bytes(hw_sprite_table),f,mit_format=True)

    f.write("bg_cluts:")
    amiga_cols = [bitplanelib.to_rgb4_color(x) for clut in bg_cluts_bank_0 for x in clut]
    bitplanelib.dump_asm_bytes(amiga_cols,f,mit_format=True,size=2)
    amiga_cols = [bitplanelib.to_rgb4_color(x) for clut in bg_cluts_bank_1 for x in clut]
    bitplanelib.dump_asm_bytes(amiga_cols,f,mit_format=True,size=2)

    f.write("character_table:\n")
    for i,c in enumerate(character_codes_list):
        # c is the list of the same character with 31 different cluts
        if c is not None:
            f.write(f"\t.long\tchar_{i}\n")
        else:
            f.write("\t.long\t0\n")
    for i,c in enumerate(character_codes_list):
        if c is not None:
            f.write(f"char_{i}:\n")
            # this is a table
            for j,cc in enumerate(c):
                f.write(f"\t.word\tchar_{i}_{j}-char_{i}\n")

            for j,cc in enumerate(c):
                f.write(f"char_{i}_{j}:")
                bitplanelib.dump_asm_bytes(cc,f,mit_format=True)
    f.write("sprite_table:\n")

    sprite_names = [None]*NB_POSSIBLE_SPRITES
    for i in range(NB_POSSIBLE_SPRITES):
        sprite = sprites.get(i)
        f.write("\t.long\t")
        if sprite:
            name = f"{sprite['name']}_{i:02x}"
            sprite_names[i] = name
            f.write(name)
        else:
            f.write("0")
        f.write("\n")

    for i in range(NB_POSSIBLE_SPRITES):
        sprite = sprites.get(i)
        if sprite:
            name = sprite_names[i]
            f.write(f"{name}:\n")
            for j in range(8):
                f.write("\t.long\t")
                f.write(f"{name}_{j}")
                f.write("\n")

    for i in range(NB_POSSIBLE_SPRITES):
        sprite = sprites.get(i)
        if sprite:
            name = sprite_names[i]
            for j in range(8):
                f.write(f"{name}_{j}:\n")

                for d in ["left","right"]:
                    bitmap = sprite[d]
                    if bitmap:
                        f.write(f"\t.long\t{name}_{j}_sprdata\n".replace("left",d))
                    else:
                        f.write("\t.long\t0\n")

    f.write("\t.section\t.datachip\n")

    for i in range(256):
        sprite = sprites.get(i)
        if sprite:
            name = sprite_names[i]
            for j in range(8):
                # clut is valid for this sprite

                for d in ["left","right"]:
                    bitmap = sprite[d]
                    if bitmap:
                        sprite_label = f"{name}_{j}_sprdata".replace("left",d)
                        f.write(f"{sprite_label}:\n\t.long\t0\t| control word")
                        bitplanelib.dump_asm_bytes(sprite[d],f,mit_format=True)
                        f.write("\t.long\t0\n")
