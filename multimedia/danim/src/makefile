!ifdef NTMAKEENV

all:

clean:

!else  # NTMAKEENV

DOMAKE=$(MAKE) /$(MAKEFLAGS: =) /nologo -f make\master.mak root SRCROOT=$(MAKEDIR) _RELEASE=$(_RELEASE)

LOGCMD=
!ifdef LOGFILE
LOGCMD= /x - 2>&1 | tee $(MAKEDIR)\$(LOGFILE)
!endif

puredirs = avserver showaxa

default: all

pure:
	for %i  in ($(puredirs)) do cd %i && $(MAKE) pure && cd ..

clean:
	$(DOMAKE) TARGET=clean

depend:
	$(DOMAKE) TARGET=depend

all:
	$(DOMAKE) TARGET=all $(LOGCMD)
	@ECHO Build complete.

maccopy:
	$(DOMAKE) TARGET=maccopy

fresh: clean depend all

beep:
   @ECHO 

!endif  #NTMAKEENV
