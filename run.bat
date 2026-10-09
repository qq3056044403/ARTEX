@echo off
chcp 65001 >nul 2>&1
rem ARTEX 一键启动（本机部署版）
rem 先拉起 PostgreSQL（若未运行），再跑 artex.exe
rem NORMA_SHELL 强制走 Git Bash，否则 worker 的 Linux 风格命令全被 PowerShell 拒掉

setlocal
set "ROOT=E:\AIgongzuo\projects\artex-fork"
set "PGROOT=E:\AIgongzuo\tools\postgres"
set "PGDATA=%PGROOT%\data"
set "PGBIN=%PGROOT%\pgsql\bin"
set "PGPORT=5433"

rem --- 关键：让 worker 的 Bash 工具走 Git Bash 而不是 PowerShell ---
set "NORMA_SHELL=C:\Program Files\Git\bin\bash.exe"
if not exist "%NORMA_SHELL%" (
    echo [artex] 警告: Git Bash 未找到 ^(%NORMA_SHELL%^)，将回退到 PowerShell 1>&2
)

rem --- bash 非交互模式（bash -c）只读 BASH_ENV 指向的脚本，不读 .bashrc ---
rem --- 这个脚本把 nmap 等工具加进 PATH，否则 worker 里 nmap: command not found ---
set "BASH_ENV=E:\AIgongzuo\tools\artex_env.sh"
if not exist "%BASH_ENV%" (
    echo [artex] 警告: BASH_ENV 脚本未找到 ^(%BASH_ENV%^)，worker 里 nmap 等工具将不在 PATH 1>&2
)

cd /d "%ROOT%"

rem --- 1. 确保 PostgreSQL 在跑 ---
"%PGBIN%\pg_ctl.exe" -D "%PGDATA%" -o "-p %PGPORT%" status >nul 2>&1
if errorlevel 1 (
    echo [artex] 启动 PostgreSQL ^(%PGPORT%^)...
    "%PGBIN%\pg_ctl.exe" -D "%PGDATA%" -l "%PGROOT%\pg.log" -o "-p %PGPORT%" -w start
    if errorlevel 1 (
        echo [artex] PostgreSQL 启动失败，见 %PGROOT%\pg.log 1>&2
        exit /b 1
    )
) else (
    echo [artex] PostgreSQL 已在运行
)

rem --- 2. 守护循环跑 artex ---
set "BIN=artex.exe"
if not exist "%BIN%" (
    echo [artex] 找不到 %BIN% 1>&2
    exit /b 1
)

set "RESTART_CODE=75"
set "MAX_DELAY=60"
set /a delay=1

:loop
"%BIN%" %*
set "code=!ERRORLEVEL!"

if "!code!"=="0" (
    echo [artex] 正常退出
    exit /b 0
)

if "!code!"=="%RESTART_CODE%" (
    echo [artex] 请求重启（应用新版本）...
    set /a delay=1
    goto loop
)

echo [artex] 异常退出 ^(code=!code!^)，!delay!s 后重启 1>&2
set /a pings=!delay!+1
ping -n !pings! 127.0.0.1 >nul 2>&1
set /a delay=!delay!*2
if !delay! gtr %MAX_DELAY% set /a delay=%MAX_DELAY%
goto loop
