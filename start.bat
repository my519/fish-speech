@echo off
chcp 65001

set USE_MIRROR=true
set PYTHONPATH=%~dp0
set PYTHON_CMD=python
if exist "fishenv" (
    set PYTHON_CMD=%cd%\fishenv\env\python
)

set API_FLAG_PATH=%~dp0API_FLAGS.txt
set KMP_DUPLICATE_LIB_OK=TRUE

setlocal enabledelayedexpansion

set "HF_ENDPOINT=https://huggingface.co"
set "no_proxy="
if "%USE_MIRROR%" == "true" (
    set "HF_ENDPOINT=https://hf-mirror.com"
    set "no_proxy=localhost, 127.0.0.1, 0.0.0.0"
)
echo "HF_ENDPOINT: !HF_ENDPOINT!"
echo "NO_PROXY: !no_proxy!"

echo "%CD%"| findstr /R /C:"[!#\$%&()\*+,;<=>?@\[\]\^`{|}~\u4E00-\u9FFF ] " >nul && (
    echo.
    echo There are special characters in the current path, please make the path of fish-speech free of special characters before running. && (
        goto end
    )
)

%PYTHON_CMD% .\tools\download_models.py

set "API_FLAGS="
set "flags="

if exist "%API_FLAG_PATH%" (
    for /f "usebackq tokens=*" %%a in ("%API_FLAG_PATH%") do (
        set "line=%%a"
        if not "!line:~0,1!"=="#" (
            set "line=!line: =<SPACE>!"
            set "line=!line:\=!"
            set "line=!line:<SPACE>= !"
            if not "!line!"=="" (
                set "API_FLAGS=!API_FLAGS!!line! "
            )
        )
    )
)


if not "!API_FLAGS!"=="" set "API_FLAGS=!API_FLAGS:~0,-1!"

set "flags="

echo !API_FLAGS! | findstr /C:"--api" >nul 2>&1
if !errorlevel! equ 0 (
    echo.
    echo Start HTTP API...
    set "mode=api"
    goto process_flags
)

echo !API_FLAGS! | findstr /C:"--infer" >nul 2>&1
if !errorlevel! equ 0 (
    echo.
    echo Start WebUI Inference...
    set "mode=infer"
    goto process_flags
)


:process_flags
for %%p in (!API_FLAGS!) do (
    if not "%%p"=="--!mode!" (
        set "flags=!flags! %%p"
    )
)

if not "!flags!"=="" set "flags=!flags:~1!"

echo Debug: flags = !flags!

rem 禁用 CUDA 相关功能
set CUDA_VISIBLE_DEVICES=-1
set PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:32
set TORCH_USE_CUDA_DSA=0
set TRITON_DISABLE_CUDA=1

rem 设置设备类型
set "DEVICE=cpu"
echo Checking available devices...

rem 检查 Intel GPU
wmic path win32_VideoController get name | findstr /i "Intel" >nul
if %errorlevel% equ 0 (
    rem 进一步检查是否支持 XPU
    %PYTHON_CMD% -c "import intel_extension_for_pytorch as ipex" >nul 2>&1
    if %errorlevel% equ 0 (
        echo Intel GPU detected and IPEX is available
        set "DEVICE=xpu"
        set "SYCL_DEVICE_FILTER=gpu"
        set "INTEL_EXTENSION_FOR_PYTORCH_CPU_FALLBACK=0"
    ) else (
        echo Intel GPU detected but IPEX is not installed
        echo Installing IPEX...
        %PYTHON_CMD% -m pip install intel-extension-for-pytorch
        if %errorlevel% equ 0 (
            set "DEVICE=xpu"
            set "SYCL_DEVICE_FILTER=gpu"
            set "INTEL_EXTENSION_FOR_PYTORCH_CPU_FALLBACK=0"
        ) else (
            echo Failed to install IPEX, falling back to CPU mode
        )
    )
) else (
    echo No Intel GPU detected, using CPU mode
)

echo Using device: %DEVICE%

rem 检查 webui 目录是否存在
if not exist "fish_speech\webui" (
    echo Creating webui directory...
    mkdir "fish_speech\webui"
)

if "!mode!"=="api" (
    %PYTHON_CMD% -m tools.api_server !flags! --device %DEVICE% --no-cuda
) else if "!mode!"=="infer" (
    %PYTHON_CMD% -m tools.webui !flags! --device %DEVICE% --no-cuda
)

echo.
echo Next launch the page...
if exist "fish_speech\webui\manage.py" (
    %PYTHON_CMD% fish_speech\webui\manage.py
) else (
    echo Warning: manage.py not found in fish_speech\webui directory
    echo Please make sure the web interface files are properly installed
)


:end
endlocal
pause
