!if "$(NTMAKEENV)" != ""
#
# Please leave this- it is benign for the nmake world, but essential
# for an NT build
#
!include ..\..\makefile.def
!else

# NOTE: NMAKE Ver 1.5 or higher needed

!ifndef ROOT
# Set this to point to the root of the Nashville tree
ROOT     = ..\..\..
!endif

C1032      = 1
MAKE       = $(ROOT)\dev\tools\c1032\bin\nmake
MSDEVMK    = iexpress.mak
CFG_RETAIL = "iexpress - Win32 Release" # Name of retail configuration
CFG_DEBUG  = "iexpress - Win32 Debug"   # Name of debug configuration

!include $(ROOT)\dev\vcwrap.mk

# If you want to add dirs to the include path, do this *after*
# including vcwrap.mk:
INCLUDE = $(INCLUDE);$(ROOT)\setup\iexpress\common
LIB = $(LIB);$(ROOT)\dev\msdev\lib
!endif
