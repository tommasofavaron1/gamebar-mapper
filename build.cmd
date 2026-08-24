@echo off
setlocal
set "MSBUILD=C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"

if not exist "%MSBUILD%" (
    echo MSBuild non trovato: %MSBUILD%
    exit /b 1
)

"%MSBUILD%" "%~dp0WidgetSampleCS.csproj" /restore /t:Build /p:Configuration=Release /p:Platform=x64 /p:AppxBundle=Never /p:BaseIntermediateOutputPath=obj-native\ /nologo /verbosity:minimal
exit /b %ERRORLEVEL%