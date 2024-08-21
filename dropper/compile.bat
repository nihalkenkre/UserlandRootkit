@echo off

cl /nologo /W3 /MT /GS- /O2 /DNDEBUG dropperDLL.c /link /DLL /out:dropperDLL.dll

del *.obj, *.lib, *.exp