@echo off

nasm -f bin ph_implant.asm -o ph_implant.x64.bin
nasm -f bin ph_implant_hooked_func.asm -o ph_implant_hooked_func.x64.bin
python ..\..\..\maldev_tools\transform\transform_file.py -i ph_implant.x64.bin -o ..\..\dropper\ph_implant.x64.bin.h -vn ph_implant_x64
python ..\..\..\maldev_tools\transform\transform_file.py -i ph_implant_hooked_func.x64.bin -o ..\..\dropper\ph_implant_hooked_func.x64.bin.h -vn ph_implant_hooked_func_x64