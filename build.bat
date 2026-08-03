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

echo [1/6] Assembling macro payload...
as -o macro-payload.o macro-payload.S || goto :failed

echo [2/6] Linking macro payload...
ld -mi386pep --image-base 0x1446c4000 -e macro_input ^
  --defsym GETKEY_IAT=0x1402e7bb8 ^
  --defsym CALLOC_IAT=0x1402e82d0 ^
  --defsym WORLD_REFPTR=0x1402a8970 ^
  --defsym BUILD_BLOCK=0x140050a00 ^
  --defsym DESTROY_BLOCK=0x14004ce90 ^
  --defsym PAINT_BLOCK=0x140051570 ^
  --defsym DESTROY_RETURN=0x1400abde8 ^
  --defsym PAINT_RETURN=0x1400abf85 ^
  --defsym META=0x1446c4f00 ^
  -o macro-payload.exe macro-payload.o || goto :failed

echo [3/6] Extracting payload bytes...
objcopy -O binary -j .text macro-payload.exe macro-payload.bin || goto :failed

echo [4/6] Embedding payload in the standalone patcher...
objcopy -I binary -O pe-x86-64 -B i386:x86-64 macro-payload.bin macro-blob.o || goto :failed

echo [5/6] Compiling patcher...
gcc -O2 -Wall -Wextra -o eden-mod.exe eden-mod.c macro-blob.o || goto :failed

echo [6/6] Building "%EDEN_OUTPUT%"...
eden-mod.exe "%EDEN_SOURCE%" "%EDEN_OUTPUT%" || goto :failed

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
exit /b 0
