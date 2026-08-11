@echo off
setlocal
cd /d "%~dp0"

set "EDEN_SOURCE=%~1"
if not defined EDEN_SOURCE set "EDEN_SOURCE=Eden - World Builder.exe"
set "EDEN_OUTPUT=%~2"
if not defined EDEN_OUTPUT set "EDEN_OUTPUT=Eden - Modded.exe"

for %%T in (as.exe ld.exe objcopy.exe gcc.exe) do (
    where %%T >nul 2>nul || (
        echo Error: %%T was not found on PATH. Install or open an MSYS2 MinGW64 shell.
        exit /b 1
    )
)

if not exist "%EDEN_SOURCE%" (
    echo Error: input executable not found: "%EDEN_SOURCE%"
    exit /b 1
)

echo [1/9] Assembling macro payload...
as -o macro-payload.o macro-payload.S || goto :failed

echo [2/9] Linking macro payload...
ld -mi386pep --image-base 0x1446c4000 -e macro_input ^
  --defsym GETKEY_IAT=0x1402e7bb8 ^
  --defsym CALLOC_IAT=0x1402e82d0 ^
  --defsym GETENV_IAT=0x1402e8300 ^
  --defsym FOPEN_IAT=0x1402e7fe0 ^
  --defsym FREAD_IAT=0x1402e8000 ^
  --defsym FWRITE_IAT=0x1402e8020 ^
  --defsym FCLOSE_IAT=0x1402e7fb0 ^
  --defsym GETMODULE_IAT=0x1402e7d58 ^
  --defsym GETPROC_IAT=0x1402e7d70 ^
  --defsym GETLAND=0x14004d9b0 ^
  --defsym IGNORE_LIQUID_STATE=0x1446c37dc ^
  --defsym WORLD_REFPTR=0x1402a8970 ^
  --defsym BUILD_BLOCK=0x140050a00 ^
  --defsym DESTROY_BLOCK=0x14004ce90 ^
  --defsym PAINT_BLOCK=0x140051570 ^
  --defsym DESTROY_RETURN=0x1400abde8 ^
  --defsym PAINT_RETURN=0x1400abf85 ^
  --defsym META=0x1446c4f00 ^
  --defsym CONFIG_CAPS_ENABLED=0x1446cc004 ^
  -o macro-payload.exe macro-payload.o || goto :failed

echo [3/9] Extracting macro payload bytes...
objcopy -O binary -j .text macro-payload.exe macro-payload.bin || goto :failed

echo [4/9] Assembling and linking HUD payload...
as -o hud-payload.o hud-payload.S || goto :failed
rem PE/COFF places .text one 0x1000 page above the image base; the extracted
rem payload itself is copied to 0x1446c7000 in the target executable.
ld -mi386pep --image-base 0x1446c6000 -e mod_hud ^
  --defsym HUD_BEGIN=0x1400ceaa0 ^
  --defsym HUD_END=0x1400cea40 ^
  --defsym STATUS_CTOR_RECT=0x1400e0810 ^
  --defsym STATUS_FONT_FIT=0x1400e08b0 ^
  --defsym STATUS_SET=0x1400e0cb0 ^
  --defsym STATUS_RENDER=0x1400e1140 ^
  --defsym GETTICK_IAT=0x1402e7db0 ^
  --defsym MOUSE_CAPTURED=0x1403128b0 ^
  --defsym FLY_MODE=0x1408f19b8 ^
  --defsym NOCLIP_STATE=0x1446c37e9 ^
  --defsym REPEAT_STATE=0x1446c37e0 ^
  --defsym RANGE_STATE=0x1446c37dd ^
  --defsym REPLACE_STATE=0x1446c37ea ^
  --defsym AUTOFILL_STATE=0x1446c37eb ^
  --defsym CLEAR_STATE=0x1446c37c0 ^
  --defsym MACRO_STATE=0x1446c4f08 ^
  --defsym IGNORE_LIQUID_STATE=0x1446c37dc ^
  --defsym CONFIG_STATUS=0x1446cc000 ^
  --defsym PANEL_ENABLED=0x1446cc003 ^
  --defsym AUTOPLACE_VALUES=0x1446cc010 ^
  --defsym RANGE_VALUES=0x1446cc030 ^
  -o hud-payload.exe hud-payload.o || goto :failed
objcopy -O binary -j .text hud-payload.exe hud-payload.bin || goto :failed

echo [5/9] Building runtime configuration payload...
as -o config-payload.o config-payload.S || goto :failed
ld -mi386pep --image-base 0x1446ca000 -e config_init ^
  --defsym GETMODULEFILENAME_IAT=0x1402e7d50 ^
  --defsym FOPEN_IAT=0x1402e7fe0 ^
  --defsym FGETS_IAT=0x1402e7fd8 ^
  --defsym FCLOSE_IAT=0x1402e7fb0 ^
  --defsym STRTOL_IAT=0x1402e8250 ^
  -o config-payload.exe config-payload.o || goto :failed
objcopy -O binary -j .text config-payload.exe config-payload.bin || goto :failed

echo [5/9] Embedding payloads in the standalone patcher...
objcopy -I binary -O pe-x86-64 -B i386:x86-64 macro-payload.bin macro-blob.o || goto :failed
objcopy -I binary -O pe-x86-64 -B i386:x86-64 hud-payload.bin hud-blob.o || goto :failed
objcopy -I binary -O pe-x86-64 -B i386:x86-64 config-payload.bin config-blob.o || goto :failed

echo [6/9] Compiling patcher...
gcc -O2 -Wall -Wextra -o eden-mod.exe eden-mod.c macro-blob.o hud-blob.o config-blob.o || goto :failed

echo [7/9] Building "%EDEN_OUTPUT%"...
eden-mod.exe "%EDEN_SOURCE%" "%EDEN_OUTPUT%" || goto :failed

echo [8/9] Verifying output exists...
if not exist "%EDEN_OUTPUT%" goto :failed

echo [9/9] Cleaning temporary build files...

call :cleanup
echo Build complete: "%EDEN_OUTPUT%"
exit /b 0

:failed
set "BUILD_ERROR=%ERRORLEVEL%"
echo Build failed with exit code %BUILD_ERROR%.
call :cleanup
exit /b %BUILD_ERROR%

:cleanup
del /q macro-payload.o macro-payload.exe macro-payload.bin macro-blob.o 2>nul
del /q hud-payload.o hud-payload.exe hud-payload.bin hud-blob.o 2>nul
del /q config-payload.o config-payload.exe config-payload.bin config-blob.o 2>nul
exit /b 0
