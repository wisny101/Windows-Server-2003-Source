!IF 0

Copyright (c) 1994-1996  Microsoft Corporation

Module Name:

    armmk.inc

Abstract:

        This module contains the ARM specific build controls.  It is included
        by makefile.def.

Revision History:

!ENDIF

DELAYLOAD_SUPPORTED=1
!ifndef DELAYLOAD_VERSION
DELAYLOAD_VERSION=0x0200
!endif

#
# ARM option control
#
UMBASE=$(UMBASE:*=arm)
UMLIBS=$(UMLIBS:*=arm)
NTRES=$(NTRES:*=arm)
UMRES=$(UMRES:*=arm)
UMOBJS=$(UMOBJS:*=arm)
LINKLIBS=$(LINKLIBS:*=arm)
GDI_DRIVER_LIBS=$(GDI_DRIVER_LIBS:*=arm)
DLLBASE=$(DLLBASE:*=arm)
DLLDEF=$(DLLDEF:*=arm)
MACHINE_TARGETLIBS=$(MACHINE_TARGETLIBS:*=arm)
!ifdef USE_MSHTML_PDB_RULES
MACHINE_TARGETLIBS=$(MACHINE_TARGETLIBS:????????=*)
!endif
TARGET=$(TARGET:*=arm)
DYNLINK_LIB=$(DYNLINK_LIB:*=arm)
TARGETEXEFILES=$(TARGETEXEFILES:*=arm)
TARGETLIBFILES=$(TARGETLIBFILES:*=arm)
TARGETOBJFILES=$(TARGETOBJFILES:*=arm)
UMOBJFILES=$(UMOBJFILES:*=arm)
UMEXEFILES=$(UMEXEFILES:*=arm)
HEADERFILE=$(HEADERFILE:*=arm)
HEADEROBJNAME=$(HEADEROBJNAME:*=arm)
HEADEROBJ=$(HEADEROBJ:*=arm)
PRECOMPILED=$(PRECOMPILED:*=arm)
PRECOMPILED_CXX=$(PRECOMPILED_CXX:*=arm)
PRECOMPILED_TARGET=$(PRECOMPILED_TARGET:*=arm)
MFC_STATIC_LIB=$(MFC_STATIC_LIB:*=arm)
CRT_LIB_PATH=$(CRT_LIB_PATH:*=arm)
SDK_LIB_PATH=$(SDK_LIB_PATH:*=arm)
DDK_LIB_PATH=$(DDK_LIB_PATH:*=arm)
IFSKIT_LIB_PATH=$(IFSKIT_LIB_PATH:*=arm)
HALKIT_LIB_PATH=$(HALKIT_LIB_PATH:*=arm)
PROCESSOR_LIB_PATH=$(PROCESSOR_LIB_PATH:*=arm)
ORDER=$(ORDER:*=arm)
OBJLIBFILES=$(OBJLIBFILES:*=arm)
MISCFILES=$(MISCFILES) $(ARM_MISCFILES)
SOURCES=$(SOURCES) $(ARM_SOURCES)

ADDITIONAL_ATL_LIBS = $(ADDITIONAL_ATL_LIBS) $(SDK_LIB_PATH)\atlarm.lib

!ifdef NTTARGETFILES
NTTARGETFILES=$(NTTARGETFILES:*=arm)
!endif
!ifdef NTTARGETFILE0
NTTARGETFILE0=$(NTTARGETFILE0:*=arm)
!endif
!ifdef NTTARGETFILE1
NTTARGETFILE1=$(NTTARGETFILE1:*=arm)
!endif

!ifdef PROJECT_LIB_PATH
PROJECT_LIB_PATH=$(PROJECT_LIB_PATH:*=arm)
!endif

ENTRY_SUFFIX=
GDI_ENTRY_SUFFIX=

DEFAULT_STACKRESERVE=0x40000
DEFAULT_STACKCOMMIT=0x1000

ADDITIONAL_ATL_LIBS = $(ADDITIONAL_ATL_LIBS)

!IFDEF ARM_WARNING_LEVEL
MSC_WARNING_LEVEL=$(ARM_WARNING_LEVEL)
!ENDIF

MSC_WARNING_LEVEL=$(MSC_WARNING_LEVEL) /WX

!ifdef ARM_PERFFLAGS
PERFFLAGS = $(ARM_PERFFLAGS)
!endif

# Set MSC_OPTIMIZATION.
# Order of precedence:
#   Platform specific override
#   Environment variable
#   System Default

!if defined(ARM_OPTIMIZATION)
MSC_OPTIMIZATION=$(ARM_OPTIMIZATION)
!elseif !defined(MSC_OPTIMIZATION)
MSC_OPTIMIZATION=$(DEFAULT_MSC_OPT)
!endif

DBGFLAGS=$(DBGFLAGS) $(MSC_OPTIMIZATION)

WIN32_LIBS=$(WIN32_LIBS) $(LIBRARY_PATH)\ntdll.lib

!IFDEF ARM_CPPFLAGS
MSC_CPPFLAGS=$(ARM_CPPFLAGS)
!ENDIF

!ifdef NO_STRING_POOLING
STRING_POOLING =
!else
!ifdef NO_READONLY_STRINGS
STRING_POOLING = /Gf
!else
STRING_POOLING = /GF
!endif
!endif

!ifdef USE_NATIVE_EH
EH_FLAGS=/GX
!if "$(USE_NATIVE_EH)" == "ASYNC"
EH_FLAGS=$(EH_FLAGS) /EHa
!endif
!else
EH_FLAGS=/GX-
!endif

! ifdef USE_RTTI
RTTI_FLAGS=/GR
! else
RTTI_FLAGS=/GR-
! endif


!ifdef USE_INCREMENTAL_COMPILING
C_INCREMENTAL_FLAG = /Gi
USE_PDB_TO_COMPILE = 1
!else
C_INCREMENTAL_FLAG = /Gi-
!undef USE_PDB_TO_COMPILE
!endif

!ifndef ARM_CPU_OPTIMIZATION
ARM_CPU_OPTIMIZATION=
!endif

STDFLAGS= /c /Zel /Zp8 /Gy $(CBSTRING) $(MSC_WARNING_LEVEL) $(MSC_CALL_TYPE) \
          $(ERATTA_FLAGS) $(ARM_CPU_OPTIMIZATION) $(C_INCREMENTAL_FLAG) $(EH_FLAGS) \
          $(RTTI_FLAGS) $(STRING_POOLING)

!if $(FREEBUILD)
ASM_DBG_DEFINES=-DDBG=0
!else
ARM_ADBGFLAGS=$(ARM_ADBGFLAGS) /Zi
!endif

# @@BEGIN_DDKSPLIT
!IFDEF NTBBT
DBGFLAGS=$(DBGFLAGS) /Zi
ARM_ADBGFLAGS=$(ARM_ADBGFLAGS) /Zi
LINKER_FLAGS=$(LINKER_FLAGS) -debug:full -debugtype:cv,fixup,pdata
!ENDIF
# @@END_DDKSPLIT

!ifndef USE_PDB_TO_COMPILE
DBGFLAGS=$(DBGFLAGS:/Zi=-Z7)
DBGFLAGS=$(DBGFLAGS:-Zi=-Z7)
!else
! ifndef USE_MSHTML_PDB_RULES
!  if "$(TARGETTYPE)" == "LIBRARY"
DBGFLAGS=$(DBGFLAGS) /Fd$(TARGETPATH)\$(TARGET_DIRECTORY)\$(TARGETNAME).pdb
!  else
DBGFLAGS=$(DBGFLAGS) /Fd$(MAKEDIR)\$(_OBJ_DIR)\ARM^\
!  endif
! else
!  ifndef TARGETPDB
TARGETPDB=$(TARGETNAME)
!  endif
!  ifndef ROOT
ROOT=$(MAKEDIR)
!  endif
DBGFLAGS=$(DBGFLAGS) /Fd$(ROOT)\$(_OBJ_DIR)\arm\$(TARGETPDB).pdb
! endif
!endif

!ifndef NO_BROWSER_INFO
! ifdef BROWSER_INFO
DBGFLAGS=$(DBGFLAGS) /FR$(MAKEDIR)\$(_OBJ_DIR)\arm^\
! endif
!endif

#
# arm option control
#

!IF "$(HALTYPE)" == ""
HALDEF=
!ELSE
HALDEF=-D$(HALTYPE)=1
!ENDIF

STD_DEFINES=-D_ARM_ -DARM $(HALDEF) $(MSC_CALL_DEFINE) $(STD_DEFINES)

CDEFINES=$(STD_DEFINES) $(TARGET_DBG_DEFINES) \
              $(LIBC_DEFINES) $(C_DEFINES) $(NET_C_DEFINES) $(MFC_DEFINES)
CFLAGS=$(ARM_FLAGS) $(NTARMFLAGS) $(STDFLAGS) $(DBGFLAGS) $(PERFFLAGS) $(USER_C_FLAGS)
ARM_ASMFLAGS=$(ARM_ADBGFLAGS) $(STD_DEFINES) $(ASM_DBG_DEFINES)\
              $(TARGET_DBG_DEFINES) $(ASM_DEFINES)

ARM_CDEFINES=$(CDEFINES)
ARM_CFLAGS=$(CFLAGS)

CC_NAME = clarm -nologo

C_COMPILER_NAME     = $(CC_NAME)
CXX_COMPILER_NAME   = $(CC_NAME)
C_PREPROCESSOR_NAME = $(CC_NAME)
!ifndef ARM_ASSEMBLER_NAME
ARM_ASSEMBLER_NAME  = armasm
!endif

GLOBAL_C_FLAGS = -Iarm\ -I. $(INCPATH1) $(CDEFINES) $(CFLAGS)

NP_COMPILER_FLAGS = $(GLOBAL_C_FLAGS) $(COMPILER_WARNINGS)

C_COMPILER_FLAGS = $(NP_COMPILER_FLAGS) $(PRECOMPILED)
CXX_COMPILER_FLAGS = $(NP_COMPILER_FLAGS) $(PRECOMPILED_CXX) $(MSC_CPPFLAGS) $(NTCPPFLAGS)
C_PREPROCESSOR_FLAGS = $(GLOBAL_C_FLAGS) -EP -Tc

C_PREPROCESSOR = $(C_PREPROCESSOR_NAME) $(C_PREPROCESSOR_FLAGS)
C_ASM_PREPROCESSOR = $(C_PREPROCESSOR_NAME) $(ASM_DEFINES) $(C_PREPROCESSOR_FLAGS)
C_COMPILER     = $(C_COMPILER_NAME) $(C_COMPILER_FLAGS)
NP_C_COMPILER  = $(C_COMPILER_NAME) $(NP_COMPILER_FLAGS)
CXX_COMPILER   = $(CXX_COMPILER_NAME) $(CXX_COMPILER_FLAGS)

ARM_ASSEMBLER=$(ARM_ASSEMBLER_NAME) -c -coff -Cx -nologo -Iarm\ -I. $(INCPATH1) $(ARM_ASMFLAGS)

ECHO_MSG=$(C_COMPILER) $<
ECHO_MSG_P=$(NP_C_COMPILER) $**
ECHO_CXX_MSG=$(CXX_COMPILER) $<

ECHO_PRECOMPILED_MSG1=$(C_COMPILER_NAME) $(C_COMPILER_FLAGS) /Yl$(TARGETNAME) /Yc$(?F) $(HEADERFILE) \
               $(HEADEROBJ) $(PRECOMPILED_FLAG) $(PRECOMPILED_SOURCEFILE)
	       
ECHO_PRECOMPILED_MSG2=$(C_COMPILER_NAME) $(C_COMPILER_FLAGS) /Yl$(TARGETNAME) /Yc$(?F) $(HEADERFILE) \
               $(HEADEROBJ) $(PRECOMPILED_FLAG)

{}.c{}.asm:
    $(C_COMPILER_NAME) @<< /Fa $(MAKEDIR)\$(<F)
$(C_COMPILER_FLAGS: =
)
$(C_COMPILER_FLAGS:##= )
<<NOKEEP


{..\arm\}.asm{}.lst:
    $(ARM_ASSEMBLER) /Fl$@ /Fo$(_OBJ_DIR)\arm\$(@B).obj $(MAKEDIR)\$<

{arm\}.asm{}.lst:
    $(ARM_ASSEMBLER) /Fl$@ /Fo$(MAKEDIR)\$(_OBJ_DIR)\arm\$(@B).obj $(MAKEDIR)\$<

{..\arm\}.asm{$(_OBJ_DIR)\arm\}.obj:
    $(ARM_ASSEMBLER) -Fo$(MAKEDIR)\$@ $(MAKEDIR)\$<

{arm\}.asm{$(_OBJ_DIR)\arm\}.obj:
    $(ARM_ASSEMBLER) -Fo$(MAKEDIR)\$@ $(MAKEDIR)\$<

{$(O)\}.asm{$(O)\}.obj:
    $(ARM_ASSEMBLER) -Fo$(MAKEDIR)\$@ $(MAKEDIR)\$<

!IFDEF _NTARMLIBS
_NTLIBS=$(_NTARMLIBS)
!ENDIF

COPYDST=$(ARMCOPYDST)
LIB_COPY=ntarmcp.cmd

!IF "$(NTDEBUGTYPE)" == "windbg" || "$(NTDEBUGTYPE)" == "both"
NTTEST_LINK_OPTIONS=-entry:KiSystemStartup
!ELSE
NTTEST_LINK_OPTIONS=-base:0x80100000 -entry:KiSystemStartup
!ENDIF

LINKER_FLAGS=$(LINKER_FLAGS) /opt:nowin98

DRIVER_ALIGNMENT=0x0080
KERNEL_ALIGNMENT=0x1000
