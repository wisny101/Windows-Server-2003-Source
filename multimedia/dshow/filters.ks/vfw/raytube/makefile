##########################################################################
#
#       Microsoft Confidential
#       Copyright (C) Microsoft Corporation 1997
#       All Rights Reserved.
#
##########################################################################

!IFDEF WIN95_BUILD

BLDROOT = ..\..\..\..\..
ROOT=$(BLDROOT)
WANT_C1132=TRUE

MSDEVMK     = raytube.mak

CFG_RETAIL  = "raytube - Win32 Memphis Release" 
CFG_DEBUG   = "raytube - Win32 Memphis Debug"

!include $(ROOT)\dev\vcwrap.mk


#
# Note: when then .mak exported by the VC use the absolute path {$(INCLUDE)},
#       these following MUST uncommented. If relative path is used (..\..\*.h)
#       these following INCLUDEs are not needed.
#
# A snapshot (May 6th, 1997) of the ever changing AvtiveMovie include files

INCLUDE=$(INCLUDE);$(BLDROOT)\dev\tools\c32\inc
INCLUDE=$(INCLUDE);$(BLDROOT)\dev\msdev\include
#INCLUDE=$(INCLUDE);$(BLDROOT)\dev\tools\c32\mfc\include

INCLUDE=$(INCLUDE);$(BLDROOT)\wdm10\ddk\inc
INCLUDE=$(INCLUDE);$(BLDROOT)\wdm10\image\inc

INCLUDE=$(INCLUDE);$(BLDROOT)\dev\tools\amovsdk.20\classes\base
INCLUDE=$(INCLUDE);$(BLDROOT)\dev\tools\amovsdk.20\include


#LIB=$(LIB);$(BLDROOT)\dev\tools\amovsdk.20\lib;$(BLDROOT)\wdm10\ddk\lib\i386

!ELSE

#
# DO NOT EDIT THIS FILE!!!  Edit .\sources. if you want to add a new source
# file to this component.  This file merely indirects to the real make file
# that is shared by all the driver components of the Windows NT DDK
#

!INCLUDE $(NTMAKEENV)\makefile.def


!ENDIF
