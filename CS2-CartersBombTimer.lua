-- CS2 Bomb Timer (FFI + Schema) - Carter-style visuals

local ffi = ffi
local C = ffi.C
ffi.cdef[[
    void* GetModuleHandleA(const char*);
]]

-- Fixed position (no GUI window)
local function getX() return 30 end
local function getY() return 350 end

-- Fonts
local font_secs, font_dmg
-- Drag state
local is_dragging = false
local drag_dx, drag_dy = 0, 0

-- Planting state for stability across frames
local planting_active = false
local plant_last_seen = 0
local plant_grace = 0.25 -- seconds to keep showing after signal drops briefly
local function ensure_fonts()
    if not font_secs then font_secs = draw.CreateFont("Bahnschrift", 17, 500) end
    if not font_dmg  then font_dmg  = draw.CreateFont("Bahnschrift", 14, 500) end
end

-- Bomb icon (Carter asset)
local bomb_tex, bomb_w, bomb_h = nil, 0, 0
-- Embedded base64 for bomb3.png to avoid HTTP at runtime
local BOMB_BASE64 = [[
iVBORw0KGgoAAAANSUhEUgAAARgAAADrCAYAAACy/4mPAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAO8ESURBVHhe7P0JvG3ZVdeLz7V235+zT3/Obes2VfdWqkmqKpVKAoR/gAASBJX3FBX1gc1fsUfRv/AEe9SnYv+e/v1/eOpDQZ7yAAlJgIIQ0lZS6aq/deu2p+923629/r/vmHvde5PcCiFgIDl7nLP26ma/5vjNMcbs3JSmNKUpTWlKU5rSlKY0pSlNaUpTmtKU/odTMDlP6bchPbaw4D60ve0eW1pKB1E05+K4E8Qx32zkUqlQ95lgNHLjMOy7MCzo+VAvs+M4HoyiKMqkUiO5j/V8/IG9vdFbFN6TCu/xet3pniimNKX/oTQFmN+m9PjiYl1AURWIvEYgsajzIy4IWoKXfBi7Q10vyNms8OOazpGOop69Te5+VYjS1YfdC4Ig1PMDNx6/4sIgVwjC/9KL43PxeLwp9Ml+eHP72uNzc8UP7O525G5KU/pNpynA/Dajx+bn6wKJeYHD1+r29wssTgpgAIwrApcTElE6UeCKubHbD1zQk9uwG4zvzcXB06EL0j4Ul5f7ss73jIPgRflLKYxOHAR9PWulYhdHoXt+nE3dG/ajT4bjuB1lUx/SfSvsDA5CF3blbkPSU+sNAqD3C4DOnFkKLl3ajB9ZXXVP3bxJHFOa0q9JU4D5LaYH7z1Rye+0AZUVfYyTcRjeq+vfEaeCajB275OTS7p/KhXHL47CoNbIxC4zcpX02G1lgzCK3TjXCqNqOc6uC0SKqSDYk+SzJD+FsXOlQSoUxrjFdDR6uJMK6mMXPpyN45eC2J2K0qk4E8V6N35lnApWJe4cuCguKx2vRLn0U5KIaune8BO6T7Xy4S9KTirkxsGe4mhmoqj93p0dRTGlKb06TQHmt5Aeuvf4CTH027MHvW8WOByXtNIbpcKRJI4rYTZ1yUXh/54aDi/LaUrSBGqQ0dl6PfXS3t6t+1OnhAivTG7uoMTWcuH4UvbZa5uDk8vVE1c2Gldfs1Q/vp9ycTnMnhNCXC10+08M3PhEKUgVBVwXJOl0+kH89jAIntP9cbm55MKwFAfxlu4Vm/vxjHP/cj+fPvPM9Y33vmFhYeb929sH9x87Fnzq+vX4LapXTzqH7cdodbUS3rzZnILREaQpwPwW0mtPLH+/pJKvy3RG+6lofEkc+cn1bPZHF8bjGek6e4NyefTxS5dGE+e/qbS2Vg9u3Ni7BQKn5yqSjVy8FGeK7SBekyo2l3KuKlToSR17WzseFYrZ/Ll07FqSeE7Iy1wvm9qPY3c1Pxo/G8bx+iCVen6QCY+NR6PD9njUckGMqlWNw/GuwtmMR3H25k7rhZNL1fyVzUbPIp7SlzVNAea3gB55ZDUYXR9+RZAK/lJcyqQz7eiPhYPRQRRF/fVCYXDzt4GN456F2eDl7f34+NJs+trm/mh1prhcLs60ZgaDml4/KInrTTqv9MJ4OROET0jlOpBI1ZZadWwQR8WRi6/1pb7pvOOC8XgUxQcCsLPDKPrpfDr9YhSk98fx+Ke3dhq7FuGUvixpCjBfZLr/7LFikHJLUWv0fZl8eE+QDv/px56//l8nr78k6PHHz7rgcmMtODbX6xw2/1I6l/oTUaM/zPQkj7n4U+MgeOPQxUFmHAftYOwG4yiI4rjZGI9+URJPOY7jN7og/clcJn55FEX/afeg/yWV/yl9/iQpeEpfTJqfrZ5x4/iHgjB4JEwFT338hRv/cPLqS4IeeOB8kMnE5VEu/9Aojr8tzKQfjcZxf+Di/zuK3f8nO4z+XT+V+rkoiHNBEFwSmjZzYSqfd6nN2TDTisbu5Z6LfiYajTvDUXxGQb6mNlt77PiJkzuiaffUlxlNAeaLSPfds+YELku6/MPjsetGkftbu4fNLymmqtdm5ga9+Lsl+363BJQLQRi/OxqN/olevWMoQPn4+lZjtlLa7KfdL1Sj8F1RMXMljOMfi4LUeJQOF6phanEmzLjlbP4fbg76vzoaji+kU+knUmG4e+Hi/R+9fv36LeP1lL70aaoifZHp3hMrf0jF/hd1+Z7nr978U/7plwadP72QduPUAy5M/2oQhD+Szqb/QyYff3AwaI2eeWb7VXuJHnlkNXzqqZvje08s/45CP/oD4zCYyw3H2SgMfqKbS71zr9P5S+Px6FulX/3r3mD8tw9bvenAvy8TmkowX0S67/hyTqfXxS7+DufiDyzMVp/aOWx+yTDT7Hw+5caZ3+WiaCWIov+0NE793Pufe2W0vd251Rt1N1pfb9r73cPWi/O18n8fZFPpfiaUehRcFNi8LRuG24NR9MFRNP6m0Th+fTYXvHcwGLfN85S+pImh5FP6ItFz1zb6QvQ3ZALXiKJhs90++JJqqbvDSq0fp2rjOH7tyI1e2Oxsf05guRt98uZW9/kr6//GBcGflfz83vxgHOfj4L75TP6BQjpbyKTCh1wcfFutll/+t//6B6pxfH3xyuVfPtHv3yy98x3/YpEwfvanfrjIudV6IR/HV1N7ux/Pcj+l3340VZG+iPTVT9x37zh2PzpqDx5udge/OBqPf/8zL9/cmLz+bU9rJ0+ey41Hf8e5cS9Ox3/m8uWN/cmrL5hePz//lT0X/QEXhPeNs+mHGqN+9bDd3a9W8j/4l7/nT1TnF3L3b6xfi1vNRjdfLD37zMefuvGmr3pbLRWmlt/0lrft/MxPvnNQKuYvX7703Oazz3zsmYP+ypBwn3zySQt/Sr+1NFWRvoh0fGFmNXDx14eZ1AkXxI3+YPSzOwet7cnr3/a0WisuKf3f7sbRWjB2/9d+o/0blsBudDpX3v72t354MBhcDDLh4/kwDBr9XqGQz7zucO+V39Fuba1eevGZh0ej0X1XX7n0del05itfeP7Zb201m2d//p3vevv1q9sP7+3e+KOvXH6xPOhnJFj1To/DwiuiX7d0NaXffJoCzBeJHr14LDfsDr4hHo3/aOzGqUGznxmMxr+ST+cuN7vdL4mek/la9feOxtEbBTAfjUbDXzhs91qTV78hunhv9i/VFxbO12cWXow6/RfHLj5odXuVdrdX7XU6v1QupX7k3gsP3XjsDV/x1KDfv3bfxUdf/NQnP/rO+vw97Wg0Hm1t7oVRNFgLw/G3RlH8WLmwf3VtcaF5+fru1I7zW0xTG8wXQGfP1u18iklAnyd9+Jnr/U4UpcbjeC8+lBTfHR2mBsPgxt7eYOLktz2NgvBa5IKT3SC7N0oVflPqzu/7ljNvG4/7r+8PNjqZXOrPHLv39J+Mg/DPDqLUr2ztRbvPvdjOP/ts79KP/Oh//GMz1fpf+vY/8J1/vF5f/HPjXv2H7rt4/1/5//7Hf/Mner3BH8rl428aDcd/LwyH9Wjkvv+Bhy7+no9++KfOT6KZ0m8RTW0wnyfde3x1MQ6CRefiShyMrgbjdGWQyl7OxYPq81dubp85c2Yp1e0eCLIzL1y/+Vkt+9nl+kwunfr9hUz672UHcak3jg470egPDwP3s5c2978kQGZ1dfW/p9Lptw6j8SdGw+hP7Wytf2Dy6gui3/ct92R0+neqhis6/4Mf/W+Xfo7n995/fyaKojfvbe98T7/b/PpqMfd/lYq5v1CO87sz166NX8268vVvPjcThcGpfC74hxfvf+1b9nYaf+wbfufv+He/69u+pEYDfFnRVEX6POjeE6tLguJvFbj8ozB0j4RB6g+mM6mvTrvxd6RSqfvrtfIfSqWD17pg/EQ6HZxcmK190+Ji/Vh9bubC8kJ9pT4390i1nCm6MMxnUpm3ZHLpSphOBXEu263Mz3zgXH1ptHJyMXf95vbwiUcvls+eP+FOH19Mv3J1M3rbW97gLr1yfZIS577u694YXLrEGlNfXFqsV/7gOA7+5GjsCqPhcLndajwdx/EzOsyo+oXQt37zm/7Q3u72myRIPytw+WeTx253e3tcq9U2XDyeT6XCr0+5+MFcmPkj4Wj0TLHVfuEuE8eNXrq61zt3z0IjjrLFg/32o0EYLt//4P3L/+k//6uP/OAP/uP/IZNGp/S5aSrBfA564uEzlE9hMBi/aTga/6/ZbFoAkkrlcnkXx5Ebs3DTaBzELupG4zgduHErGkWzYZhqj12QEaBcd3FQESjthi7OBGHQkJ/X5uXD6RjFwQddKnVZ7ncV0XoQuFIUxfu5XKapsC4rkrVUOv+RwMUzQRBcd0F4LE6HL2XH44HC2m8M84up0G2H425p7EbN0XiYamzu9z76/G8uABWL+VQYBH83my/+iVQ6W+n3ulvt1uHfVlr/6cTJr5teeP6d5aefet8P/sxP/tfvnJs78X3b673/49//13fekuTuvffeQFLM2u7O1uPpIP7hgnOz5XTmv1Zc6l/q9fMf2N6+6yRJVgh96cUP537x3T/zI+9+xzu/slh0L95z9tz3/a9/60feM3EypS8iTQHmc9CjD5795nzGfUUQhG9Kp7NP5PM54YHaU5aISwUuGo+dGM+1uj1hSdr1Oi2Xy6ZcfxC5TI4xdRIR9R53AgIBUiBcAVwEP3rHr/yPgxD+TcnZuBO6cUrgcaDXLELVV3xh7MKX5aImj9dcEOSDIL4qsHnNIArfE2Zyo3Gv1dXzdKvZ+sQ4Gn00m5PiNhq+rDDuGY/cZjbrhl/zoee2rpw44f5/V6/Gb/t/vSH1c7/w/l+PYTldqpS/PZPO/oNsLr8wGA7i0XDwN8ZR9L912u0vyNAbxzeKP/BX/8o/2N68+ofO3fvgj/+57/0LfzYITjcmr2/R4uLCaZXdvxt3W49X0pl8Ncj+ksri76bC1K+8f2PjVXux/vk/+Z43v/u//7dvyeWzj584/cjxN7zpDd/1wouXn/yrf+0fTiWZLyJNAeZV6LGHz9+r1vBHs8EgG8WpRYnbC/lsxmUyaRe7tJVcR8BycNi262an73KSYSTSuHQ67Srloktnsm5upuq6vZ7L6Fksh/F4KGyQBwMazlIQBFrQeMznALT0jB8jzhyCNeGTX2ZXopMLBEiSc8ZxT8BU0pNms9GqSFV7Pp8vtKNoNBzHAJY7EKp9RAy5K1x7Og7d/Zls4co4CAajcbo1joapTDDaSGXyVxVw/ud+4X29t331G/IHnXiUDcfxe973oUh5ScnxdxSKpb+RL+SPSUpzw0HvJ0aD9p9utYfr8ndXestb3vKq41F+8sf/3uLKsaX/8pM/8W/eOByGL37D27/9B9/y1m/+sSA49llTDh4+f/yxzb2DvxkNo6+bS+V6+XTqyezY/dAHdnZ+aeLkrvQNX3O6NB4W/k4cp//k8urqv33+8s3v/8AHPr4zeT2lLwJNbTCvQmuLs98vgMkPhsNfHAzElkF4ZiTw2Nxtup29hms0W67XH0piSbtiPutmqmU96zi18K4nCabX77uDRss12x0dPdftj5xUH4GPggJVPGjcOgsoBCzINDzj8BTHY72L9CQOBCSchTLWgSPJJgr1LCuJRrdjiUyRJKVgPpsJV4Rkx9Tyn1YI5yUevVXg9HiYSv/pVCrzcDpMf0s6DB8fB6m/kHHjR4RbfyQVxBeEaWvnTx97k1JxbyblLkita52759hXnVhdkLoy/nrB2RuK2VS+P+gL3vojxTVXKKSudXvR7uOPP5i+cWNz/MbHLgbXbm67h+87uZAvz/bmCm55bW1paWVx5vT61v4tMOofbp975lMfeazXa1yM49G4Xr9w/YGHvuHnJ68/jeZnq4f6FgXl7mvS8ThfcOG8Ht+42el+TrXnnmNr8enTZ/pv/bqvfvBD73/qiajf/uSJleqla+ssXTOlLwYlzeSUJvTGh06yhMBrVZn/wjjOfKrb636/GPM/NVutN3Z6gwzramfFfUv1kltYXHJSaWBqg4QwTLkRq+TqptE4cIeHhyrhlNve2ZOUIiAqFAVEJTdTK5qUkgCNCTKSaPzZ1CYDkjFSjv0j++i5PEmEuXXYazsEPDq6XXYvCVxWOpEkGD2TTxzgX6CUTmek2tm64LHSE0gkiqWySaCSZ+dGUsdGzPKWY+lrcUNHWcH1FFOn1e6W5G2u2+lkyV9b0ttwFF2vz5T/UaVSbkRxuHmws/dQqZS7piwUx9F4UeH041F0RkXysNJ3U9cfHY3i/1abrSyHweh35TLjP5bJhUpz2A6D4t/sdMc/NhxHvV963yfXv+KxB9Lv+dAnTJ1BEtrdvHZhd//w9w/7vT9YDsK12TBzRVD9p1VWv/DB7e1XXR0vjm9mvue7/+L/9MlPfOqvt1utH1de/sZ7PnKZxc+n9EWgKcDcQW986ERVRfJnxJR/bBSnPhWHmX/S7o3Wuu323987OJzD7nLmnntcvVoQqMSm9gAqYhA7jJdVomJS1+/3nNQPJyY16eT6xqbb3j10BYFMqVh2swKZYiErgIoNoAxcfDLsoxgsGHrw7wM2gOFKYMHh3fBEEo4i7XRYoRKASQuclAgDHg8yABzgkpZYAziFYcaHC1ApfdiIyIMHL84KNVIY3CtL0sdC4jA/Cg93ku56wqIhRuoROtmgvyBtrygnHbnPKzFS36IanodRIGkrvtzvDT9aKedeXyhkV4NAYSo45auncvpYGKY3htF4IxVmelLD9pSeZjaXkRoUVINR7/Ir6wen2u3OD8XD4WtnUulszoX/OeuC7124/wTqnfupJ5+iSIzOrq25l27ccD+g61954sKiwv1vSuF1pf1P/cpHL3/JjJ7+UqepinQHHcsVvlmnbxe/VYaxe0czyvxnte//emdnd01qUGplcdYt1CsuKzXHg0rK7C0wrpcoAJOxWvaRnT1wUOfHrlouuVql4iQBuH63Kzdj1x/Frj8Ymgp0SzqRa+MS+Nhf6RlSjV1OSGhAfJz1DpBBuRoNFa+BiX9mPglTBwDjr/HqQZFrwIWDdBqgEbpFxoHaZn7waj/44zn3epdWXDk9q6XCUACczqdSof6DfEboGwZhHvuSwgsyCE5BMBuE4QUFUcnns3plD0lrWs+P6fqsnL5exxtSqfgtCuisVNPvUFQPStr6zlq18NpqtXyhP4yqzU7bZYJgTRDfzOVy8x0JaCePL58qZTLDpbna/ZKUovNnT9TObmy3XpqtFKTkLindb5IW+s7Tx1eaV27uTI29XwSaAsyE3rKwEEaBmxOL/Xk3ch8UA/2Lvfag3um0vjkcj44tL8y6ekXaP8BCcy+HMCK9Sp7pPANC8KcxuTEPDDw2xs9LspidqbhYkkHMKg29gdvYOzQDMV5jAY2XHnTjg7J47J0upWqYNER4CtjC5w3vuBoOh240GkqFA/T8p8WgLFiwMA0gBC6BgJHUAWze/1iSlq4UNuETGnFOovF5IDBuRLfVL3wbyEnT8qADeEkyMXeJ/ciTdz8aKY9ykcuirpFGHyapJHkelDkET0FQV9GWFc5pFdqSHp5R3ooC06DR7irNo0Ihk7m/VCp8Y7aS/93y943lUuH3Szp6/exs+ZskyR2/dnL5XCqTnt3bO/w63T8aZtKr6Uz6ucvXt79kJpl+KdMUYCb0SqcTr+YKf9QNoqobjt/xzO7eRyVtfNto2P/m+ZlytpTPSCUKXQqJRQwKc8AIMBYA45kJZpkwjDG2VzNgPEAH4i38lxffCUtcfhy6nsK4sdM0BicOYzC5xAvXgFMkdEHdirjG6AvjogZN0sC4HCSneDRw6UzGgyCx8Y7QSIQ+t5eo/EF6kbSSawMJwFKvE4Ny8jyKFKfOCWD4ODnbncJNgGTyTD+k17vzAGZSki4IMyMFB1tRUnYQeRWoGHBb2fIwFuxPwiALaemphXzWRcrrYQ9zUVjOBmElW8zWM9nMoqTKRb0/p+9zVmXwVQr/jQL7/yWXz64ooIrCrWYymdS5Myey955ZW8/EQXFpfiba2mv4REzpN5WmADOhJxYW6qrQ36Ja/fZgHP+L7UF/EKSC766UCmdr5aJJBZ5pVWgCF0DGgADwEJMgeSSMcifxngOmG4lJIYn+LsjLv84ZeckXcu5YrSKG6bvtg46FA6PhUb9e/UHqkdoTSdY31jcmtuDcUOECZDAdoGXgZ4jGGBzixuHthCTgAHEG2IzMCf54hkd/+Hzh0Afh8zrxo4dAgffl7yDAxQflQQn33I+V1sEgMjsR6uUkSSIPLv5KZ/snQl+2k0e69u7II+ONBpLasjoXCgWXKmQTZ4SLDARgFvhsmUw2P+xj241r0s3eIJVuUdLUQ0rmG8dBvHPqxEJ8Y33vN2Xy5pRu0xRgJnS8XJbuEv9B1c5nu+PxU1vD0fF0Kvxzi/N1l1NLa2oFFVtgAmN45gisZ4bzna2wtf53MKYxsX5gLnsGF8ABCiOWKhW2B06c4orVvMvm827nsOta7Z6QS9JSVmpZKqszNlPAhk8mBg/Suk67kcIeiUuiMWAn8NF1mM4pVpgSMIIhBVieR02SAXtgPs/X3Bsj6p4wrJdpwvVKu7magJJdy/Mkr7ef4UJpMz+AD0/IPxc67F8J4DwBs5QktSySFgkz3xB5s1R6v1aulDtu/BveAdD4zeXSjhUj2tHQDO6FQh5U8elSGn3Y2MrIl8GVfQOyqXesqPeQHr9RAs3XKY7RYm12d3mu1NzYbdwWx6b0G6IpwIgeWV1NxaPRa3X5PfDezUHnx7pR/H2lQv54VdJLRgADwRSMY0F6AVjSaewvOlICCjGOVzc8eYDxFR31AsaPooHde6AxbjOGMMlI74cCmny55EozdRtjs7+3azaLbK7kglxeEgphCQbSBUky4hIBj6khQcbuR2FGgCMGD3PS9GI3EPqwTeQ4VXSRmBS3Q9yJaeluT8l9BFDJ/4hBfgZaAKQkIrnzIAFjTsBHefUAAqzAtLo1oPKsrxc88JeTX0WpsPwrrnk7GAoaAemMgFuBYNOhfHipX58nldFIEhmUSECJOkd54o8EINkx5qg9GLlyRd9K34R3pmqRNp1xyvciPyOBEWmZdNmnU2nlKp2ejcbjrxFwYbD+0I3NvaZFPKXfME0BRrTebMZrxeJXqx4+rrr33Hqvy5C335XPpApIMMZMqpwYIAEDpBhvg/HiO5WZSpxQYscwENFFwhzGmJPD3vvWVLUd/zr6kaPftpSXZCJgGacyriu1qdFqC0zSbqDrtlrsEWHIfW8wcN1uzzVbeiZGw09PjEbP1FDXAx3CJJ3Hri+g6ItfuR7YMx2KnqOvZz2BEc9J0mAc+neMFDZAShtICBdc5ARGkpxQvQhbopXiFgipHAYGPsqnzmOBmGQICsHOlITZkgQe+A0kneULRb0L3HCodBKxAEyqjEAiq0tJh5JSADTAiHKy3i0C0o0AQZcpx/SNWOlstlVGelIq5k1yGQmUKFP7ZhPpk28Uhj3X78eSfvIAjILyahrd94b2cfxfTizPHV7bmO4H95tBU4ARvX5+fiWI46/U5dtV157e6ve3VcNfv7w0V2asCuBCzaYiAixp7DGqxLSQnHlmmDGRYAAQe6+KDT8kdhA/juQ2GdDYmXoupuC2O3RRq2vif3mm6nKlisuUiq512LCpCQBLOivJQww5UMvdbDRdv9dxw/7AjYbyq+fD4cha/5Ex7sgNARy5Hejcl7uBpCPCAoi6et7Ts76eDXoD89/V/VCI0hMiIfEMFE7fJCLFqTT2dD0E0AAtHT0hT1voBAD1o1B+UM1Q3wTAyhIgZaodKh/SnkDJCTzDTE5AIPcKS6UjSa3gKpUZlxXwFJXvQECTLZQNDPJ6xyjpbL4kEMqpDAQQmYK+RV7vs67dahkYlytVuSnq8yGhCUCUBsYvQTQGUSTgU5mgZgFmSDWTt5YGSW4fzVSWnn3lbpt9T+nXTUceYGyXwoN+JID547qd3R8ONncGg4ViIffE8dUFgYRvBU2Ch7lVMdMCFD+uBOMhrSxVFHUgkVRUafUyOfxr3usd4r5u8Wz2AC51wKxDtcTWcpfEPHKUEUjlKyWF6dzhfsMklGg0lD8xd6cpaafrCtmRK+Zoy4euVIhdejxQPIBK32VSI3MfjAUwElmiYd/8DvpdJ5XQ3gFGABDXg17P9cSkAz3rCWwArL7OA0lKfYCoKwmq03U9Hc1G2wCqrWc9RvUCUgCW/ON3oPB7uh8OASqlWWALQAlVDHAovwHAonz2TXrJmHTVFqjxvm1hAOoCCQEFxu0RkpBAYaz7QACTkZpTEPimBER5qbF7B4duv9F19flFV5uZtV6qXC6nuKjm+haT7zRUORTyDC7k201UKn1jQUxa590war/n5WtbX/AyFFO6TZT4kaVTp06lZkvBQvag/Zi4+89GUfz6m4Puk1vd3lfNzVaqa8vzVkmtbQNh4kitpiq1WkxaYvR9xHekFQhwSbpxPbigQglIJqADkw4BCN2bXUaHhUsFV3gwa7sHYOQkxXRcgRa3KBUkV5Ka1HP7u7vGkCz1sDATu/NnSu7UybxrNEc2faHTlYqlsNodpUFqzTgeivlplyVR6XlXUka7jRsvjcG0zebQFQppAQbjZySN9MeSAHLyJ0VIYCe8EJPS6itv8jQcIZUwmJCEYBtRcpR/wBXblNlkKAOd7b1AEwmPmoYERzc/aaHXy6slAtScJDKBkR94J5BUmVNGgAZ+CRdwRuJIZwU2AgPAN6uw8GPqUr/ntjZvKO8Dt7x6zNXrM65WKdqgSIz0gOSw37EZ791OQ9LQUOpVWaDN0ht8H5WSDqmaPzkcDr/n59/78ZeUmCn9BunIAszrX/+6R0f93pvH/c6bCqG7VyxyPOqPZ/a7A3eglhsRemWuapU9pIXVPeNPqLDYDqjs8EdiizHjrSo6RUqhWq+MoQHMjGrvjZO4Y0AcTI8Kg7hu3B6krKVn0F2xNuvCUd/Fu00XoJ7ks+5AEsm+1KFUlh07Yjdfi9zDD1bc/RdzAgBJO+nYtdpiPJ3hU0WjeHRWEvwBAKCuKV]]

local function ensure_bomb_texture()
    if bomb_tex ~= nil then return end
    if not draw.CreateTexture then return end
    -- Decode base64 -> PNG bytes -> RGBA
    local png = common and common.DecodeBase64 and common.DecodeBase64(BOMB_BASE64)
    local rgba, w, h
    if png then
        rgba, w, h = common.DecodePNG(png)
    else
        -- Fallback: try decoding the base64 string directly if environment supports it
        rgba, w, h = common.DecodePNG and common.DecodePNG(BOMB_BASE64) or nil
    end
    if rgba and w and h then
        bomb_tex = draw.CreateTexture(rgba, w, h)
        bomb_w, bomb_h = w, h
    end
end
local function draw_bomb_icon(x, y)
    if not bomb_tex then return end
    local slot_w, slot_h = 60, 50
    local scale = math.min(slot_w / bomb_w, slot_h / bomb_h)
    local dw, dh = math.floor(bomb_w * scale), math.floor(bomb_h * scale)
    local ox = math.floor((slot_w - dw) / 2)
    local oy = math.floor((slot_h - dh) / 2)
    draw.SetTexture(bomb_tex)
    draw.Color(255, 255, 255, 255)
    draw.FilledRect(x - 8 + ox, y + oy, x - 8 + ox + dw, y + oy + dh)
    draw.SetTexture(nil)
end

-- Events (Carter behavior)
client.AllowListener("bomb_planted")
client.AllowListener("bomb_begindefuse")
client.AllowListener("bomb_abortdefuse")
client.AllowListener("bomb_exploded")
client.AllowListener("round_officially_ended")
client.AllowListener("bomb_defused")
client.AllowListener("round_start")
client.AllowListener("round_freeze_end")

local timePlanted, defusing, ended = 0, false, false
callbacks.Register("FireGameEvent", function(event)
    local name = event:GetName()
    if name == "bomb_planted" then timePlanted = globals.CurTime(); ended = false end
    if name == "bomb_begindefuse" then defusing = true; ended = false end
    if name == "bomb_abortdefuse" then defusing = false; ended = false end
    if name == "bomb_defused" or name == "bomb_exploded" or name == "round_officially_ended" then ended = true end
    if name == "round_start" or name == "round_freeze_end" then
        -- Reset planting state between rounds to avoid stale conditions
        timePlanted = 0
        defusing = false
        ended = false
    end
end)

-- Helpers
local function get_planted_c4()
    local list = entities.FindByClass and entities.FindByClass("C_PlantedC4") or nil
    if not list or not list[1] then list = entities.FindByClass and entities.FindByClass("CPlantedC4") or nil end
    if list and list[1] then return list[1] end
    return nil
end
local function safe_call(ent, method, name)
    if not ent or not method or not ent[method] then return nil end
    local ok, res = pcall(function() return ent[method](ent, name) end)
    if ok then return res end
    return nil
end

local function get_float(ent, name)
    local v = safe_call(ent, 'GetFieldFloat', name)
    if type(v) ~= 'number' then v = safe_call(ent, 'GetFieldFloat', name) end
    if type(v) ~= 'number' then v = safe_call(ent, 'GetField', name) end
    if type(v) ~= 'number' then v = safe_call(ent, 'GetField', name) end
    if type(v) == 'number' then return v end
    return 0
end
local function get_bool(ent, name)
    local v = safe_call(ent, 'GetFieldBool', name)
    if type(v) ~= 'boolean' then v = safe_call(ent, 'GetFieldBool', name) end
    if type(v) ~= 'boolean' then v = safe_call(ent, 'GetField', name) end
    if type(v) ~= 'boolean' then v = safe_call(ent, 'GetField', name) end
    if type(v) == 'boolean' then return v end
    if type(v) == 'number' then return v ~= 0 end
    return false
end

-- Map-specific bomb radius (from BombAPIV2)
local g_bombradius_map = {
    ["maps/de_ancient.vpk"]  = 650 * 3.5,
    ["maps/de_anubis.vpk"]   = 450 * 3.5,
    ["maps/de_assembly.vpk"] = 500 * 3.5,
    ["maps/de_inferno.vpk"]  = 620 * 3.5,
    ["maps/de_mills.vpk"]    = 500 * 3.5,
    ["maps/de_mirage.vpk"]   = 650 * 3.5,
    ["maps/de_nuke.vpk"]     = 650 * 3.5,
    ["maps/de_overpass.vpk"] = 650 * 3.5,
    ["maps/de_thera.vpk"]    = 500 * 3.5,
    ["maps/de_vertigo.vpk"]  = 500 * 3.5,
}
local function GetBombRadius()
    local map = engine and engine.GetMapName and engine.GetMapName() or nil
    return (map and g_bombradius_map[map]) or 1750
end

-- Damage calculation (CS2-consistent)
local function BombDamage(Bomb, Player)
    if not Bomb or not Player then return 0 end
    local ppos = Player:GetAbsOrigin()
    local bpos = Bomb:GetAbsOrigin()
    if not ppos or not bpos then return 0 end

    -- Add view offset to player's origin like BombAPIV2
    local view = (Player.GetFieldVector and Player:GetFieldVector("m_vecViewOffset")) or {x=0,y=0,z=0}
    local px = ppos.x + (view.x or 0)
    local py = ppos.y + (view.y or 0)
    local pz = ppos.z + (view.z or 0)
    local dx = bpos.x - px
    local dy = bpos.y - py
    local dz = bpos.z - pz
    local flDistance = math.sqrt(dx*dx + dy*dy + dz*dz)

    local flBombRadius = GetBombRadius()
    -- Formula from BombAPIV2
    local flDamage = (flBombRadius / 3.5) * math.exp((flDistance * flDistance) / (-2 * (flBombRadius / 3) * (flBombRadius / 3)))

    local armor = (Player.GetFieldInt and Player:GetFieldInt("m_ArmorValue")) or (Player.GetField and Player:GetField("m_ArmorValue")) or 0
    armor = tonumber(armor) or 0
    if armor == 0 then
        return math.max(flDamage, 0)
    end

    local flReducedDamage = flDamage / 2
    if armor < flReducedDamage then
        local flFraction = armor / flReducedDamage
        return math.max((flFraction * flReducedDamage) + (1 - flFraction) * flDamage, 0)
    end
    return math.max(flReducedDamage, 0)
end

-- Find the C4 weapon to detect planting state
local function get_c4_weapon()
    local bombs = entities.FindByClass("C_C4")
    if bombs == nil then return nil end
    for i = 1, #bombs do
        if not bombs[i]:GetFieldBool("m_bBombPlanted") then
            return bombs[i]
        end
    end
    return nil 
end

-- Color selection for timer bar
local function color_for_time(seconds)
    if seconds <= 5 then return 240, 20, 0 end          -- Red
    if seconds <= 10 then return 210, 150, 0 end        -- Yellow
    return 6, 176, 37                                   -- Green
end

-- Draw panel and elements identically to Carter's layout
-- HSV to RGB helper for rainbow border
local function hsv_to_rgb(h, s, v)
    h = h % 1.0
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    local r, g, b
    if i % 6 == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    else r, g, b = v, p, q end
    return math.floor(r*255), math.floor(g*255), math.floor(b*255)
end

local function draw_panel(x, y, w, h)
    -- Animated rainbow outer glow border
    local t = globals.CurTime() or 0
    local hue = (t * 0.4) % 1.0
    local segments = 20
    local thickness = 2
    for i=0,segments-1 do
        local hseg = (hue + i/segments) % 1.0
        local r,g,b = hsv_to_rgb(hseg, 1, 1)
        draw.Color(r, g, b, 180)
        -- top
        local x0 = x + math.floor(i * (w/segments))
        local x1 = x + math.floor((i+1) * (w/segments))
        draw.FilledRect(x0, y - thickness, x1, y)
        -- bottom
        draw.FilledRect(x0, y + h, x1, y + h + thickness)
        -- left
        local y0 = y + math.floor(i * (h/segments))
        local y1 = y + math.floor((i+1) * (h/segments))
        draw.FilledRect(x - thickness, y0, x, y1)
        -- right
        draw.FilledRect(x + w, y0, x + w + thickness, y1)
    end

    -- Background (no rounded edges in Carter's 10 style)
    draw.Color(20, 20, 20, 210)
    draw.FilledRect(x, y, x + w, y + h)
end

local function on_draw()
    -- Ensure window is created; leave visibility managed by the UI system
    -- If you still don't see it, press INSERT (Aimware default) to open the menu.
    ensure_fonts()
    ensure_bomb_texture()

    -- Sync GUI position with dragging paradigm (if any in host); fallback to editbox values
    local x, y = getX(), getY()

    -- Drag interaction over the panel area when menu is open
    local W, H = 125, 67
    if gui.IsMenuOpen and gui.IsMenuOpen() then
        local mx, my = input.GetMousePos()
        local hovering = mx >= x and mx <= x + W and my >= y and my <= y + H
        if hovering and input.IsButtonDown(1) then
            if not is_dragging then
                is_dragging = true
                drag_dx = mx - x
                drag_dy = my - y
            end
        else
            if is_dragging and not input.IsButtonDown(1) then
                is_dragging = false
            end
        end
        if is_dragging then
            x = mx - drag_dx
            y = my - drag_dy
            bt_x:SetValue(x)
            bt_y:SetValue(y)
        end
    end

    if ended then
        -- Hide if ended, but still keep UI position editable
        return
    end

    local bomb = get_planted_c4()
    -- If no planted bomb, show planting UI if arming C4
    if not bomb then
        -- Local-only planting: show when the local player's C4 is being armed
        local wpn = get_c4_weapon()
        if wpn then
            local arming = get_bool(wpn, "m_bStartedArming")
            local via_use = get_bool(wpn, "m_bIsPlantingViaUse")
            local armed_time = get_float(wpn, "m_fArmedTime")
            local cur = globals.CurTime()
            local plant_left = math.max(0, armed_time - cur)

            if (arming or via_use) and plant_left > 0 then
                local W, H = 125, 67
                draw_panel(x, y, W, H)
                draw_bomb_icon(x, y)

                -- Planting label aligned with damage/fatal text
                ensure_fonts()
                draw.SetFont(font_dmg)
                draw.Color(255, 225, 170, 255)
                local tstr = string.format("Planting: %.1f", plant_left)
                draw.Text(x + 41, y + 21, tstr .. "s")

                -- Progress bar (orange)
                local bar_w, bar_h = 121, 10
                local bar_x, bar_y = x + 2, y + 55
                local total_len = 2.5
                local prog = 1 - (plant_left / total_len)
                if prog ~= prog then prog = 0 end
                prog = math.max(0, math.min(1, prog))
                draw.Color(255, 170, 60, 70)
                draw.FilledRect(bar_x - 2, bar_y - 2, bar_x + math.floor(bar_w * prog) + 2, bar_y + bar_h + 2)
                draw.Color(255, 170, 60, 255)
                draw.FilledRect(bar_x, bar_y, bar_x + math.floor(bar_w * prog), bar_y + bar_h)
                return
            end
        end
        return
    end

    -- Read timers from schema/props
    local cur = globals.CurTime()
    local blow_time = get_float(bomb, "m_flC4Blow")
    local timer_length = get_float(bomb, "m_flTimerLength")
    if timer_length <= 0 then timer_length = 40 end

    local time_left = math.max(0, blow_time - cur)

    -- Base panel
    local W, H = 125, 67
    draw_panel(x, y, W, H)

    -- Bomb icon
    draw_bomb_icon(x, y)

    -- Timer label (secs with one decimal; ensure trailing .0)
    draw.SetFont(font_secs)
    draw.Color(255, 255, 255, 255)
    local tstr = string.format("%.1f", time_left)
    if not string.find(tstr, "%.") then tstr = tstr .. ".0" end
    draw.Text(x + 45, y + 8, tstr .. "s")

    -- Damage label
    local me = entities.GetLocalPlayer and entities.GetLocalPlayer() or nil
    local dmg = (me and BombDamage(bomb, me)) or 0
    local hp = (me and me.GetHealth and me:GetHealth()) or 0
    local fatal = hp > 0 and dmg >= hp
    draw.SetFont(font_dmg)
    if fatal then
        draw.Color(240, 20, 0, 255)
        draw.Text(x + 45, y + 28, "Fatal")
    else
        draw.Color(141, 141, 141, 255)
        draw.Text(x + 45, y + 28, string.format("%d damage", math.floor(0.5 + dmg)))
    end

    -- Main progress bar (121x10 at (x+2,y+55)); background transparent in Carter, but we can omit
    local bar_w, bar_h = 121, 10
    local bar_x, bar_y = x + 2, y + 55

    -- Compute progress by remaining time mapped to [0,timer_length]
    local prog_value = math.max(0, math.min(timer_length, time_left))
    local r, g, b = color_for_time(time_left)

    -- Track background (transparent)
    -- Fill progressed amount
    draw.Color(r, g, b, 70)
    draw.FilledRect(bar_x - 2, bar_y - 2, bar_x + math.floor(bar_w * ((timer_length - prog_value) / timer_length)) + 2, bar_y + bar_h + 2)
    draw.Color(r, g, b, 255)
    draw.FilledRect(bar_x, bar_y, bar_x + math.floor(bar_w * ((timer_length - prog_value) / timer_length)), bar_y + bar_h)

    -- Defuse bar below (121x4 at (x+2,y+61)) if defusing
    local being_defused = get_bool(bomb, "m_bBeingDefused") or defusing
    local def_len = get_float(bomb, "m_flDefuseLength")
    local def_end = get_float(bomb, "m_flDefuseCountDown")

    local def_bar_w, def_bar_h = 121, 4
    local def_bar_x, def_bar_y = x + 2, y + 61

    if being_defused and def_len > 0 and def_end > 0 then
        local def_left = math.max(0, def_end - cur)
        local def_prog = math.max(0, math.min(1, 1 - (def_left / def_len)))
        local can_defuse = time_left >= def_left
        local dr, dg, db = (can_defuse and 0 or 210), (can_defuse and 135 or 150), (can_defuse and 255 or 0)
        if can_defuse then dr, dg, db = 0, 135, 255 else dr, dg, db = 210, 150, 0 end
        draw.Color(dr, dg, db, 60)
        draw.FilledRect(def_bar_x - 1, def_bar_y - 1, def_bar_x + math.floor(def_bar_w * def_prog) + 1, def_bar_y + def_bar_h + 1)
        draw.Color(dr, dg, db, 255)
        draw.FilledRect(def_bar_x, def_bar_y, def_bar_x + math.floor(def_bar_w * def_prog), def_bar_y + def_bar_h)
    end
end

callbacks.Register("Draw", on_draw)
callbacks.Register("Unload", function() end)

print("[bomb_timer_ffi] Loaded Carter-style visuals for CS2 bomb timer.")
