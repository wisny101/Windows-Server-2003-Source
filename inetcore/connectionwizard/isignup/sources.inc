
GETCONN_DIR     = ..\..

!include $(GETCONN_DIR)\common.inc

MAJORCOMP=GETCONN
MINORCOMP=ISIGNUP

TARGETNAME=ISIGNUP
TARGETTYPE=PROGRAM
TARGETPATH=obj
UMTYPE=windows
UMENTRY=winmain

NOT_LEAN_AND_MEAN=1
RCNOFONTMAP=1
C_DEFINES = -DICW32 -DNASHVILLE

!if "$(BUILD_PRODUCT)" == "NT"
C_DEFINES       = $(C_DEFINES) -DNT
!endif

!if !defined(NOT_UNICODE)
C_DEFINES       = $(C_DEFINES) -DUNICODE -D_UNICODE
!endif

USE_MSVCRT40=1

SOURCES= \
    ..\isignup.rc   \
    ..\isignupx.cpp

TARGETLIBS= \
    $(SDK_LIB_PATH)\user32.lib        \
    $(SDK_LIB_PATH)\kernel32.lib

