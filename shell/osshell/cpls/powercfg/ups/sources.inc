!IF 0

Copyright (c) 1989  Microsoft Corporation

Module Name:

    sources.

Abstract:

    This file specifies the target component being built and the list of
    sources files needed to build that component.  Also specifies optional
    compiler switches and libraries that are unique for the component being
    built.


Author:

    Steve Wood (stevewo) 12-Apr-1990

NOTE:   Commented description of this file is in \nt\bak\bin\sources.tpl

!ENDIF

TARGETNAME=ups
TARGETTYPE=LIBRARY

INCLUDES=..\..\;$(BASEDIR)\private\ntos\inc;

MSC_WARNING_LEVEL=/W3 /WX

C_DEFINES=$(C_DEFINES) -D_NTSYSTEM_ -DNTOS_KERNEL=1 -DUNICODE -D_UNICODE


SOURCES=..\apcabout.c \
        ..\upscommon.c \
        ..\upsconfig.c \
        ..\upscustom.c \
        ..\upsinfo.c \
        ..\upsreg.c \
        ..\upsselect.c \
        ..\upstab.c
