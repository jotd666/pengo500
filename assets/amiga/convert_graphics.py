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



NB_POSSIBLE_SPRITES = 64


palette = block_dict["palette"]["data"]
# 19 unique colors
##print(palette)
##print(len({tuple(x) for x in palette}))
# looks that there are only 32 cluts for 16 colors totol

palette = [tuple(x) for x in palette[:16]]

with open(os.path.join(src_dir,"palette.68k"),"w") as f:
    bitplanelib.palette_dump(palette,f,pformat=bitplanelib.PALETTE_FORMAT_ASMGNU)


cluts = block_dict["clut"]["data"][:32]

character_codes_list = list()

clut_index = 7  # TEMP


rgb_cluts = [[tuple(palette[pidx]) for pidx in clut] for clut in cluts]


for k,chardat in enumerate(block_dict["tile"]["data"]):
    img = Image.new('RGB',(8,8))

    character_codes = list()
    for colors in rgb_cluts:
        d = iter(chardat)
        for i in range(8):
            for j in range(8):
                v = next(d)
                img.putpixel((j,i),colors[v])
        character_codes.append(bitplanelib.palette_image2raw(img,None,palette))
    character_codes_list.append(character_codes)

##    if dump_it:
##        scaled = ImageOps.scale(img,5,0)
##        scaled.save(os.path.join(dump_dir,f"char_{k:02x}.png"))

with open(os.path.join(this_dir,"sprite_config.json")) as f:
    sprite_config = {int(k):v for k,v in json.load(f).items()}
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

bg_cluts = block_dict["clut"]["data"]
bg_cluts = [[tuple(palette[pidx]) for pidx in clut] for clut in bg_cluts]

hw_sprite_table = [False]*NB_POSSIBLE_SPRITES
if False:
    for k,data in sprite_config.items():
        sprdat = block_dict["sprite"]["data"][k]
        for m,clut_index in enumerate(data["cluts"]):
            spritepal = bg_cluts[clut_index]
            hw_sprite = None #data.get("hw_sprite")
            d = iter(sprdat)
            img = Image.new('RGB',(16,16))
            y_start = 0

            #spritepal = [tuple(palette[pidx]) for pidx in spritepal]

            for i in range(16):
                for j in range(16):
                    v = next(d)
                    if j >= y_start:
                        img.putpixel((j,i),spritepal[v])

            entry = dict()
            sprites[k][clut_index] = entry
            sprites[k]["name"] = data['name']

            right = None
            outname = f"{k:02x}_{clut_index}_{data['name']}.png"
            if hw_sprite is None:
                kwargs = {"output_filename":None,"palette":bob_palette,"generate_mask":True,"blit_pad":True}
                left = bitplanelib.palette_image2raw(img,**kwargs)
                if data["mirror"]:
                    right = bitplanelib.palette_image2raw(ImageOps.mirror(img),**kwargs)
            else:
                entry["palette"]=spritepal
                entry["hw_sprite"]=hw_sprite
                hw_sprite_table[k] = True

                left = bitplanelib.palette_image2sprite(img,None,spritepal)

            entry.update({"left":left,"right":right})

            if dump_it:
                scaled = ImageOps.scale(img,5,0)
                scaled.save(os.path.join(dump_dir,outname))

##grid = Image.open(os.path.join(this_dir,"grid.png"))
##p = bitplanelib.palette_extract(grid)
##grid_bitplanes = bitplanelib.palette_image2raw(grid,None,p,
##                                        generate_mask=True,blit_pad=True)

with open(os.path.join(src_dir,"graphics.68k"),"w") as f:
    f.write("\t.global\tcharacter_table\n")
    f.write("\t.global\tsprite_table\n")
    f.write("\t.global\thw_sprite_flag_table\n")
    f.write("\t.global\tbg_cluts\n")
    f.write("hw_sprite_flag_table:")
    bitplanelib.dump_asm_bytes(bytes(hw_sprite_table),f,mit_format=True)

    f.write("bg_cluts:")
    amiga_cols = [bitplanelib.to_rgb4_color(x) for clut in bg_cluts for x in clut]
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
                slot = sprite.get(j)
                f.write("\t.long\t")
                if slot:
                    # clut is valid for this sprite
                    f.write(f"{name}_{j}")
                else:
                    f.write("0")
                f.write("\n")

    for i in range(NB_POSSIBLE_SPRITES):
        sprite = sprites.get(i)
        if sprite:
            name = sprite_names[i]
            for j in range(8):
                slot = sprite.get(j)
                if slot:
                    # clut is valid for this sprite
                    f.write(f"{name}_{j}:\n\t.word\t")

                    hw_sprite = True  #slot.get("hw_sprite")
                    if hw_sprite is None:
                        f.write("0   | BOB\n")
                        # just bob pointers
                        left_ptr = f"\t.long\t{name}_{j}_left\n"
                        f.write(left_ptr)
                        if "right" in slot:
                            f.write(f"\t.long\t{name}_{j}_right\n")
                        else:
                            f.write(left_ptr)
                    else:
                        f.write("1   | HW_SPRITE\n")
                        f.write("* palette")
                        rgb4 = [bitplanelib.to_rgb4_color(x) for x in slot["palette"]]
                        bitplanelib.dump_asm_bytes(rgb4,f,mit_format=True,size=2)
                        f.write("\t.long\t0f\n")
                        f.write("* slots")
                        bitplanelib.dump_asm_bytes(bytes(hw_sprite),f,mit_format=True)
                        f.write("\t.byte\t0xff\n\t.align\t2\n")
                        # we chose HW sprites for sprites that only have 1 clut
                        # else this will generate multiply defined symbols
                        # but ATM this is sufficient
                        # also size is assumed 16x16

                        f.write(f"* frames\n0:\n")
                        for index in range(8):
                            if index in hw_sprite:
                                f.write(f"\t.long\t{name}_sprdata_{index}\n")
                            else:
                                f.write("\t.long\t0\n")
    f.write("\t.section\t.datachip\n")

    for i in range(256):
        sprite = sprites.get(i)
        if sprite:
            name = sprite_names[i]
            for j in range(8):
                slot = sprite.get(j)
                if slot:
                    # clut is valid for this sprite
                    hw_sprite = slot.get("hw_sprite")

                    if hw_sprite is None:
                        # just bob data
                        f.write(f"{name}_{j}_left:")
                        bitplanelib.dump_asm_bytes(slot["left"],f,mit_format=True)
                        if "right" in slot:
                            f.write(f"{name}_{j}_right:")
                            bitplanelib.dump_asm_bytes(slot["right"],f,mit_format=True)
                    else:
                        for index in range(8):
                            if index in hw_sprite:
                                f.write(f"{name}_sprdata_{index}:\n\t.long\t0\t| control word")
                                bitplanelib.dump_asm_bytes(slot["left"],f,mit_format=True)
                                f.write("\t.long\t0\n")
