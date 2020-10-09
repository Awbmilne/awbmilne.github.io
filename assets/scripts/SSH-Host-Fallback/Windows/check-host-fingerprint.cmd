REM @echo off

REM GET UNIQUE TEMP FILE
:uniqLoop
set "temp_file=%tmp%\ssh_host_key_verification~%RANDOM%.tmp"
if exist "%temp_file%" goto :uniqLoop

REM SCAN HOST KEYS INTO TEMP FILE
ssh-keyscan %1 > %temp_file% 2>%1

REM CHECK IF ANY FINGERPRINTS MATCH PROVIDED
FOR /F "USEBACKQ tokens=2" %%G IN (`ssh-keygen -lf %temp_file%`) DO IF /I "%2"=="%%G" GOTO MATCH

:NOMATCH
    EXIT /b 2
    GOTO :EOF

:MATCH
    EXIT /b 0
    GOTO :EOF
