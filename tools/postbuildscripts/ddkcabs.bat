@perl -x -w %0 %PROCESSOR_ARCHITECTURE% %*
@goto :eof
#!perl
# line 5
################################################################################
# 05-Jun-00 : skupec: Add fail safes to avoid hangs in post build
#                     1) delete all old lock files before we start
#                     2) set max. wait limit for new process to 30*2 seconds
#
# 01-Jul-00 : skupec: Convert to use Win32::Process to avoid sporadic hangs
#                     that are showing up in postbuild.
#
# 10-Nov-00 : skupec: Add Verbose mode
#                     No longer use \lib[fre|chk]\%arch%. Now just \lib\%arch%
#
# 11-Jan-01 : skupec: Don't ship checked versions of the tools.
#
# 10-Feb-01 : skupec: Create per-architecture cabs for tools.  Instead of just
#                     TOOL_*.cab, we now also have TOOL_*x.cab and TOOL_*i.cab
#                     (x86/ia64 respectively) IFF per-arch directories exist
#                     when cabbing is done.  TOOL_*.cab should still be the
#                     primary cab in cabs.ini so a single checkbox will install
#                     on either platform.
#
# 27-Feb-01 : skupec: Modify the cabbing of \incs to properly handle the new
#                     platform specific subdir layout.
#
# 04-Apr-01 : skupec: Add cabbing of legacy libs for Win2K DDK env
#
# 17-May-01 : skupec: Add DDK_DBG[i|x] cabs only on CHK builds
#
# 29-Sep-01 : skupec: Move OS specific files from WXP to WNET. ($OS_SUBDIR)
#
# 21-Jan-02 : skupec: Only make %_BUILDARCH%dbins cabs on %_BUILDARCH%
#
# 28-Jan-02 : skupec: Support IA-64 native tools as well as cross compiler tools
#
# 09-Apr-02 : skupec: Remove dup files from tools cabs. Add AMD64 support.
#
# 03-Jun-02 : skupec: Improve support for picking backports to legacy OSes
#
use lib $ENV{RAZZLETOOLPATH} . '\\postbuildscripts';
use BuildName;

my $ProcArc = shift;

# Only accept one parameter which must be numeric
my ($numproc, $lpCount, $force, $spoof,$verbose) = (2,0,0,0,0);
my $OS_SUBDIR = "wnet";

for ($lpCount=0; $lpCount <= ($#ARGV); $lpCount++) {
  SWITCH: {
    if ((substr($ARGV[$lpCount],0,1) eq "-") or (substr($ARGV[$lpCount],0,1) eq "/")) {
        for ($i=1;$i<length($ARGV[$lpCount]);$i++) {
            exit(Usage())    if uc(substr($ARGV[$lpCount],$i,1)) eq "?";
            exit(Usage())    if uc(substr($ARGV[$lpCount],$i,1)) eq "H";

            if (uc substr($ARGV[$lpCount],$i,1) eq "L") {
                if ($ARGV[$lpCount] =~ /:+(.*)/) {
                    if ((defined $1) and ($1 ne "")) { # handle -l:<language>
                        $lang = $1;
                    } else {                           # handle -l: where language was forgotten
                        $lang = "usa";
                    }
                    $ARGV[$lpCount] =~ s/:+(.*)//;
                } elsif (defined $ARGV[$lpCount+1]) {  # handle -l <language>
                    $lang = $ARGV[$lpCount+1];
                    splice(@ARGV,$lpCount+1,1);
                } else {                               # handle -l where language was forgotten
                    $lang = "usa"; # default
                }

                unless (uc $lang eq "USA") {           # only execute on USA
                    exit 0;
                }
                next;
            } elsif (uc substr($ARGV[$lpCount],$i,1) eq "N") {
                if (defined($ARGV[$lpCount+1]) and ($ARGV[$lpCount+1] =~ /^\d*$/)) {
                    $numproc=$ARGV[$lpCount+1];
                    splice(@ARGV,$lpCount+1,1);
                } else {
                    exit(Usage());
                }
            } elsif (uc substr($ARGV[$lpCount],$i,1) eq "F") {
                $force = 1;
            } elsif (uc substr($ARGV[$lpCount],$i,1) eq "S") {
                $spoof = 1;
            } elsif (uc substr($ARGV[$lpCount],$i,1) eq "V") {
                $verbose = 1;
            } else {
                print("-",substr($ARGV[$lpCount],$i,1)," switch ignored. Use '-?' or '-h' to get usage.\n");
            }

        }

    } else {
        print("$ARGV[$lpCount] argument ignored.\n");
    }
    1; #Last line should do nothing
  }
}


if ($spoof) {

  # Create %_NTTREE%/build_logs to hold the generated BuildName.txt file.

  mkdir ("$ENV{_NTTREE}/build_logs", 0);

  # Create & write the BuildName.txt file.

  open (BLDNAME, ">$ENV{_NTTREE}/build_logs/BuildName.txt")
      || die "Couldn't open $ENV{_NTTREE}/build_logs/BuildName.txt for writing.\n";

  # Write out the build number.

  chop ($_ = `getbldno.cmd`);
  print BLDNAME "$_.";

  # Write out the build type.

  print BLDNAME "$ENV{_BuildArch}$ENV{_BuildType}.";

  # Write out the build branch.

  print BLDNAME "$ENV{_BuildBranch}.";

  # Write out the build time.  Note that the year value [5] is years since
  # 1900, and the month [4] is 0..11.

  @_ = localtime(time);
  printf BLDNAME "%02u%02u%02u-%02u%02u\n",
      $_[5] - 100, $_[4] + 1, $_[3], $_[2], $_[1];

  close BLDNAME;
}


# Only build if (1) -f is passed, (2) %OFFICIAL_BUILD_MACHINE% is set, or (3) %__BUILDMACHINE__% == LB6RI
if (! defined $ENV{OFFICIAL_BUILD_MACHINE} && (! $force) && (uc($ENV{__BUILDMACHINE__}) ne "LB6RI") ) {
    print STDERR "Not building because this isn't an official build machine.  Use -f to force.\n";
    exit 0;
};

system("title PB_ddkcabs.bat");       # Required by postbuild. Do not remove.
print(STDERR "$0: Started. ");
use strict;
# use Win32;
use Win32::Process;

# Set %temp% as working directory
Win32::SetCwd $ENV{Temp};

my $time         = time();
my $hLogFile;
my $handle;

################################################################################
#
# Create .tmp file so postbuild.cmd knows we're running.
#
################################################################################
    open  (hLogFile, ">$ENV{TEMP}\\ddkcabs.tmp") || die("Can't open $ENV{TEMP}\\ddkcabs.tmp for writing: $!\n");
    print (hLogFile "1");
    close (hLogFile);

################################################################################
#
# Find the correct logfile to use
#
################################################################################
    # Either use the defined log file
    if (defined $ENV{LOGFILE}) {
        $handle="$ENV{LOGFILE}";
    # or use our default log file.
    } else {
        $handle="$ENV{TEMP}\\ddkcabs.log";
    }
    print(STDERR "Writing log to $handle.\n");

################################################################################
#
# Test for all conditions that require us to terminate early.
#
################################################################################
    # If %_DDK_NOCAB% is defined, don't make CABS
    if (defined $ENV{_DDK_NOCAB} ) {
        logmsg("_DDK_NOCAB is set. Not making CABS.");
        unlink("$ENV{TEMP}\\ddkcabs.tmp");
        exit(0);
    }

    # If any of the needed environment variables aren't defined, output an
    #   error and abort the cabbing process
    foreach ("_NTDRIVE","_NTROOT","_BUILDARCH","_BUILDTYPE","_NTTREE","RazzleToolPath","PROCESSOR_ARCHITECTURE","NUMBER_OF_PROCESSORS") {
        unless (defined $ENV{$_}) {
            logerror("Aborting: \%$_\% is not defined.");
            unlink("$ENV{TEMP}\\ddkcabs.tmp");
            exit(0);
        }
    }

    # Don't build on AXP64 or Alpha
    if ($ENV{_BuildArch} =~ /^(axp64|alpha)/i) {
            unlink("$ENV{TEMP}\\ddkcabs.tmp");
            logmsg("DDK unsupported on $ENV{_BuildArch}. Exiting.");
            exit(0);
    }

################################################################################
#
# Global Variables
#
################################################################################

    my $bldno         = build_number;
    logdebug("$numproc processes per processor");
    my $MAX_PROCESSES = $ENV{NUMBER_OF_PROCESSORS}*$numproc;
    my @Processes;

    my $exe = "$ENV{WINDIR}\\system32\\cmd.exe";
    my $global_param  = " /c start /min /wait cabarc.exe -s 6144 -m lzx:21 -i 1 N ";

    my $INCREMENTAL   = 0;     # Full build by default
    my %MAKECAB;

    my @dir_list1;
    my @dir_list2;
    my $dir;
    my $dir2;
    my $file;

    my $cabname;
    my $samplename;
    my $friendlyname;
    my $kit;

    my $i;

    sub TRUE   {return(1);} # BOOLEAN TRUE
    sub FALSE  {return(0);} # BOOLEAN FALSE

    my $CABDEBUG = FALSE;
       $CABDEBUG = TRUE   if (defined($ENV{_CABDEBUG}));

    my $bindir;
    my $sdkincs = "$ENV{_NTTREE}\\ddk_flat\\inc";
    # Directory to look for .lib's in
    my $libdir = "lib\\$OS_SUBDIR";

    if (uc($ENV{_BuildArch}) eq "IA64") {
        $libdir .= "\\ia64";
    } elsif (uc($ENV{_BuildArch}) eq "AMD64") {
        $libdir .= "\\amd64";
    } else {
        $libdir .= "\\i386";
    }

################################################################################
#
# Determine if we should build incrementally
#
################################################################################
if ( -e "$ENV{_NTTREE}\\build_logs\\bindiff.txt" ) {

    $INCREMENTAL = TRUE;

    open(hFile, "$ENV{_NTTREE}\\build_logs\\bindiff.txt");
    @dir_list1 = <hFile>;
    close(hFile);

    # Pass over the array of changed files once and determine which CABs
    #   need re-built.
    foreach $file (@dir_list1) {

        # Ignore files we don't care about.
        next unless ($file =~ /\\ddk_flat\\/);
        chomp $file;
        # The easy checks
        $MAKECAB{DDKINCS} =TRUE if ($file =~ /\\ddk_flat\\inc\\ddk\\/);
        $MAKECAB{DDKLIBS} =TRUE if ($file =~ /\\ddk_flat\\$libdir\\/);
        $MAKECAB{DDKBINS} =TRUE if ($file =~ /\\ddk_flat\\bin\\/);
        $MAKECAB{DDKDOCS} =TRUE if ($file =~ /\\ddk_flat\\help\\/);
        $MAKECAB{DDKTOOLS}=TRUE if ($file =~ /\\ddk_flat\\tools\\/);
        $MAKECAB{DDKDBG}  =TRUE if ($file =~ /\\ddk_flat\\debug\\/);

        $MAKECAB{IFSTOOLS}=TRUE if ($file =~ /\\ifs_flat\\tools\\/);
        $MAKECAB{IFSLIBS} =TRUE if ($file =~ /\\ifs_flat\\$libdir\\/);
        $MAKECAB{IFSINCS} =TRUE if ($file =~ /\\ifs_flat\\incs\\/);
        $MAKECAB{IFSDOCS} =TRUE if ($file =~ /\\ifs_flat\\help\\/);

        #$MAKECAB{HALTOOLS}=TRUE if ($file =~ /\\hal_flat\\tools\\/);
        $MAKECAB{HALLIBS} =TRUE if ($file =~ /\\hal_flat\\$libdir\\/);
        $MAKECAB{HALINCS} =TRUE if ($file =~ /\\hal_flat\\incs\\/);
        $MAKECAB{HALBINS} =TRUE if ($file =~ /\\hal_flat\\bins\\/);
        #$MAKECAB{HALDOCS} =TRUE if ($file =~ /\\hal_flat\\help\\/);

        #$MAKECAB{PDKTOOLS}=TRUE if ($file =~ /\\processor_flat\\tools\\/);
        $MAKECAB{PDKLIBS} =TRUE if ($file =~ /\\processor_flat\\$libdir\\/);
        $MAKECAB{PDKINCS} =TRUE if ($file =~ /\\processor_flat\\incs\\/);
        #$MAKECAB{PDKDOCS} =TRUE if ($file =~ /\\processor_flat\\help\\/);

        # The moderate checks
        if ($file =~ /\\ddk_flat\\inc\\(.*)/) {
            $i = $1;
        if ($i =~ /^\\wnet^/) {
                $MAKECAB{SDKINCS}=TRUE;
        } elsif ($i =~ /^\\[atl..|mfc..|crt]/) {
                $MAKECAB{CMNINCS}=TRUE;
            }
        }

        if ($file =~ /\\ddk_flat\\(.*)/) {
            $i = $1;
            $MAKECAB{COREDDK}=TRUE unless ($i =~ /\\/);
        }
        
        if ($file =~ /\\hal_flat\\src\\hals\\(.*)/) {
            $i = $1;
            $MAKECAB{COREHAL}=TRUE unless ($i =~ /\\/);
        }

        if ($file =~ /\\processor_flat\\src\\processor\\(.*)/) {
            $i = $1;
            $MAKECAB{COREPDK}=TRUE unless ($i =~ /\\/);
        }

        $file =~ s/^[A-Z]:\\binaries\.(ia64|x86|amd64)(chk|fre)\\(ddk|ifs|hal|processor)_flat\\//i;

        if ($file =~ /^tools\\(.*?)\\/) {
            $dir = $1;
            $cabname=sprintf("%s_%s\n","TOOL",lc(substr($dir,0,6)));
            chomp $cabname;
            $MAKECAB{$cabname} = TRUE;
        }

        next unless ($file =~ /^src\\(.*?)\\(.*?)\\/);
        $dir = $1;
        $dir2 = $2;
        $cabname=sprintf("%s_%s\n",uc(substr($dir,0,4)),lc(substr($dir2,0,6)));
        chomp $cabname;
        $MAKECAB{$cabname} = TRUE;
    }

}

# --------------------------------------------------------------------------
# Make the samples CABs.  One cab per 2nd level directory under src.  Name of each cab is
#   the first 4 character of the first level directory + the first 6 of the second level
#   directory.
# --------------------------------------------------------------------------
SAMPLES:{

    foreach $kit ("ddk","ifs", "hal", "processor") {
        mkdir("$ENV{_NTTREE}\\${kit}_cd\\common", 777) unless (-e "$ENV{_NTTREE}\\${kit}_cd\\common");
        opendir(hDIR, "$ENV{_NTTREE}\\${kit}_flat\\src"); # Get the first level directories
        @dir_list1=readdir(hDIR);
        closedir(hDIR);

        foreach $dir (@dir_list1) {
            # Skip . & .. as well as non-directory files (which shouldn't be there anyhow).
            next unless ((-d "$ENV{_NTTREE}\\${kit}_flat\\src\\$dir") and ($dir ne ".") and ($dir ne ".."));
            chomp $dir;
            opendir(hDIR, "$ENV{_NTTREE}\\${kit}_flat\\src\\$dir"); # Get the second level directories
            @dir_list2=readdir(hDIR);
            closedir(hDIR);
   
            foreach $dir2 (@dir_list2) {
                # Skip . & .. as well as non-directory files (which shouldn't be there anyhow).
                next unless ((-d "$ENV{_NTTREE}\\${kit}_flat\\src\\$dir\\$dir2") and ($dir2 ne ".") and ($dir2 ne ".."));

                chomp $dir2;

                $cabname=sprintf("%s_%s\n",uc(substr($dir,0,4)),lc(substr($dir2,0,6)));
                chomp $cabname;
                next if (($INCREMENTAL) and (! defined $MAKECAB{$cabname}));
                # Create a complete listing of files under the second level directory
                system("dir $ENV{_NTTREE}\\${kit}_flat\\src\\$dir\\$dir2 /s/b/a-d > ${dir}${dir2}.ddk.ini 2>nul");

                # Create the .ini 
                CreateCAB ("${dir}${dir2}.ddk.ini","$cabname","Samples","$dir", "$kit", "$bldno");
            }
        }
    }
}

# --------------------------------------------------------------------------
DDKINCS: {
    if ($INCREMENTAL) {
        last DDKINCS unless (  defined $MAKECAB{DDKINCS} );
    }
        
    # List all files under \inc\ddk\...
    system("dir $ENV{_NTTREE}\\ddk_flat\\inc\\ddk\\$OS_SUBDIR /s/b/a-d > ddkincs.ddk.ini 2>nul");
    system("dir $ENV{_NTTREE}\\ddk_flat\\inc\\ddk\\wdm\\$OS_SUBDIR /s/b/a-d >> ddkincs.ddk.ini 2>nul");

    # Create the .ini
    CreateCAB(  "ddkincs.ddk.ini","DDKINCS","Build_Environment",
                "DDK_Include_Files", "DDK", $bldno);

    #
    # Handle backport incs
    #

    # W2K specific
    if ( -e "$ENV{_NTTREE}\\ddk_flat\\inc\\w2k" ) {
        system("dir $ENV{_NTTREE}\\ddk_flat\\inc\\w2k /s/b/a-d > w2kincs.ddk.ini 2>nul");
    }

    if ( -e "$ENV{_NTTREE}\\ddk_flat\\inc\\ddk\\w2k" ) {
        system("dir $ENV{_NTTREE}\\ddk_flat\\inc\\ddk\\w2k /s/b/a-d >> w2kincs.ddk.ini 2>nul");
    }

    if ( -e "$ENV{_NTTREE}\\ddk_flat\\inc\\ddk\\wdm\\w2k" ) {
        system("dir $ENV{_NTTREE}\\ddk_flat\\inc\\ddk\\wdm\\w2k /s/b/a-d >> w2kincs.ddk.ini 2>nul");
    }

    # WXP specific
    if ( -e "$ENV{_NTTREE}\\ddk_flat\\inc\\wxp" ) {
        system("dir $ENV{_NTTREE}\\ddk_flat\\inc\\wxp /s/b/a-d > wxpincs.ddk.ini 2>nul");
    }

    if ( -e "$ENV{_NTTREE}\\ddk_flat\\inc\\ddk\\wxp" ) {
        system("dir $ENV{_NTTREE}\\ddk_flat\\inc\\ddk\\wxp /s/b/a-d >> wxpincs.ddk.ini 2>nul");
    }

    if ( -e "$ENV{_NTTREE}\\ddk_flat\\inc\\ddk\\wdm\\wxp" ) {
        system("dir $ENV{_NTTREE}\\ddk_flat\\inc\\ddk\\wdm\\wxp /s/b/a-d >> wxpincs.ddk.ini 2>nul");
    }

    # Make the cabs
    if ( -e "w2kincs.ddk.ini" ) {
        # Create the .ini
        CreateCAB(  "w2kincs.ddk.ini","W2K_INCS","Build_Environment",
                    "W2K_Include_Files","DDK",$bldno);
    }

    if ( -e "wxpincs.ddk.ini" ) {
        # Create the .ini
        CreateCAB(  "wxpincs.ddk.ini","WXP_INCS","Build_Environment",
                    "WXP_Include_Files","DDK",$bldno);
    }
}

# --------------------------------------------------------------------------
IFSINCS: {
    if ($INCREMENTAL) {
        last IFSINCS unless (  defined $MAKECAB{IFSINCS} );
    }

    system("dir $ENV{_NTTREE}\\ifs_flat\\inc /s/b/a-d > ifsincs.ddk.ini 2>nul");

    # Create the .ini
    CreateCAB(  "ifsincs.ddk.ini","IFSINCS","Build_Environment",
                "IFS_Include_Files","IFS",$bldno);
}

# --------------------------------------------------------------------------
PDKINCS: {
    if ($INCREMENTAL) {
        last PDKINCS unless (  defined $MAKECAB{PDKINCS} );
    }

    system("dir $ENV{_NTTREE}\\processor_flat\\inc /s/b/a-d > pdkincs.ddk.ini 2>nul");

    # Create the .ini
    CreateCAB(  "pdkincs.ddk.ini","PDKINCS","Build_Environment",
                "PDK_Include_Files","processor",$bldno);
}

# --------------------------------------------------------------------------
HALINCS: {
    if ($INCREMENTAL) {
        last HALINCS unless (  defined $MAKECAB{HALINCS} );
    }

    system("dir $ENV{_NTTREE}\\HAL_flat\\inc /s/b/a-d > HALincs.ddk.ini 2>nul");

    # Create the .ini
    CreateCAB(  "HALincs.ddk.ini","HALINCS","Build_Environment",
                "HAL_Include_Files","HAL",$bldno);
}

# --------------------------------------------------------------------------
HALBINS: {
    if ($INCREMENTAL) {
        last HALBINS unless (  defined $MAKECAB{HALBINS} );
    }

    # List all files under \inc\ddk\...
    system("dir $ENV{_NTTREE}\\HAL_flat\\bin /s/b/a-d > HALbins.ddk.ini 2>nul");

    # Create the .ini
    CreateCAB(  "HALbins.ddk.ini","HALBINS","Build_Environment",
                "HAL_Binary_Files","HAL",$bldno);
}

# --------------------------------------------------------------------------
DDKDBG: {
    if ($INCREMENTAL) {
        last DDKDBG unless (  defined $MAKECAB{DDKDBG} );
    }

    # Make DBG cabs only on CHK builds
    last DDKDBG if (uc $ENV{_BuildType} ne "CHK");

    my $plat = substr($ENV{_BUILDARCH}, 0, 1);

    system("dir $ENV{_NTTREE}\\ddk_flat\\debug /s/b/a-d > ddkdbg.ddk.ini 2>nul");

    # Create the .ini
    CreateCAB(  "ddkdbg.ddk.ini","DDK_DBG${plat}","Build_Environment",
                "Extra_Debug_Files","DDK",$bldno);
}

# --------------------------------------------------------------------------
DDKTOOLS: {
    if ($INCREMENTAL) {
        last DDKTOOLS unless (  defined $MAKECAB{DDKTOOLS} );
    }

    # We don't want to ship checked versions of the tools
    last DDKTOOLS if (uc $ENV{_BuildType} eq "CHK");

    opendir(hDIR, "$ENV{_NTTREE}\\DDK_flat\\tools"); # Get the first level directories
    @dir_list1=readdir(hDIR);
    closedir(hDIR);

    foreach $dir (@dir_list1) {
        # Skip . & .. as well as non-directory files (which shouldn't be there anyhow).
        next unless ((-d "$ENV{_NTTREE}\\DDK_flat\\tools\\$dir") and ($dir ne ".") and ($dir ne ".."));
        chomp $dir;
        $cabname=sprintf("%s_%s\n","TOOL",lc substr($dir,0,6) );
        chomp $cabname;
        next if (($INCREMENTAL) and (! defined $MAKECAB{$cabname}));

        ##
        ## Need to handle tools on the per-arch basis.  Can't just look for \%arch, since
        ## the tools may also have files in root. (.htm's, etc).  Instead, break we'll
        ## break this into 4 cabs per tool, TOOL_%tool%, TOOL_%tool%x (x86), TOOL_%tool%i (ia64)
        ## TOOL_%tool%a (AMD64)
        ##

        # At tools\\$dir, now, we need all the sub dirs
        my @subs = `dir $ENV{_NTTREE}\\DDK_flat\\tools\\$dir /s/b/ad`;
        my $sub;
        my $plat = substr($ENV{_BUILDARCH}, 0, 1);

        # Drop in an empty file as placeholder so we can force the general cab for this tool
        # to be built.
        system("echo. >$ENV{_NTTREE}\\DDK_flat\\tools\\$dir\\.empty");

        # Make sure we're not appending to old .ini's
        unlink("TOOLS${dir}${plat}.ddk.ini") if (-e "TOOLS${dir}${plat}.ddk.ini");
        unlink("TOOLS${dir}.ddk.ini")        if (-e "TOOLS${dir}.ddk.ini");

        # Now, create the .ini for the common cab
        foreach (`dir $ENV{_NTTREE}\\DDK_flat\\tools\\$dir /b/a-d`) {
            chomp;
            system("echo $ENV{_NTTREE}\\DDK_flat\\tools\\$dir\\$_ >> TOOLS${dir}.ddk.ini");
        }

        # For every subdir, if it ends in %arch%, create the arch specific cab, otherwise
        # create the general cab.
        foreach $sub (@subs) {
            chomp $sub;
            if ($sub =~ /DDK_flat\\.*\\$ENV{_BUILDARCH}/i) {
                system("dir $sub /s/b/a-d >> TOOLS${dir}${plat}.ddk.ini 2>nul");
            } elsif ( uc($ENV{_BUILDARCH}) eq "X86" ) {
                # i386 is a valid alias of x86
                if ($sub =~ /DDK_flat\\.*\\i386/i) {
                    system("dir $sub /s/b/a-d >> TOOLS${dir}${plat}.ddk.ini 2>nul");
                }
            }
        }

        # Create the cabs
        CreateCAB ("TOOLS${dir}.ddk.ini","${cabname}","Build_Environment","${dir}_TOOL", "ddk", "$bldno");
        CreateCAB ("TOOLS${dir}${plat}.ddk.ini","${cabname}${plat}","Build_Environment","${dir}_TOOL", "ddk", "$bldno")
            if (-e "TOOLS${dir}${plat}.ddk.ini"); # May not have arch-specific cab
    }
}

# --------------------------------------------------------------------------
IFSTOOLS: {
    if ($INCREMENTAL) {
        last IFSTOOLS unless (  defined $MAKECAB{IFSTOOLS} );
    }

    # List all files under \inc\ddk\...
    system("dir $ENV{_NTTREE}\\IFS_flat\\tools /s/b/a-d > ifstools.ddk.ini 2>nul");

    # Create the .ini
    CreateCAB(  "ifstools.ddk.ini","IFSTOOLS","Build_Environment",
                "Development_Tools","IFS",$bldno);
}

# -- Common Includes -------------------------------------------------------
if ( (! $INCREMENTAL ) || ($INCREMENTAL && defined $MAKECAB{CMNINCS}) ) {
    @dir_list1=();
    #
    # Look for all ATL21 specific headers
    #
    opendir(hDIR, "$sdkincs\\atl21");
    @dir_list2 = readdir(hDIR);
    closedir(hDIR);

    foreach (@dir_list2) {
        $_ = "atl21\\$_";
    }

    push(@dir_list1, @dir_list2);
    undef(@dir_list2);


    #
    # Look for all ATL30 specific headers
    #
    opendir(hDIR, "$sdkincs\\atl30");
    @dir_list2 = readdir(hDIR);
    closedir(hDIR);

    foreach (@dir_list2) {
        $_ = "atl30\\$_";
    }

    push(@dir_list1, @dir_list2);
    undef(@dir_list2);

    #
    # Look for all MFC42 specific headers
    #
    opendir(hDIR, "$sdkincs\\mfc42");
    @dir_list2 = readdir(hDIR);
    closedir(hDIR);

    foreach (@dir_list2) {
        $_ = "mfc42\\$_";
    }

    push(@dir_list1, @dir_list2);
    undef(@dir_list2);

    #
    # Look for all CRT headers
    #
    opendir(hDIR, "$sdkincs\\crt");
    @dir_list2 = readdir(hDIR);
    closedir(hDIR);

    foreach (@dir_list2) {
        $_ = "crt\\$_";
    }

    push(@dir_list1, @dir_list2);
    undef(@dir_list2);

    opendir(hDIR, "$sdkincs\\crt\\sys");
    @dir_list2 = readdir(hDIR);
    closedir(hDIR);

    foreach (@dir_list2) {
        $_ = "crt\\sys\\$_";
    }

    push(@dir_list1, @dir_list2);
    undef(@dir_list2);

    opendir(hDIR, "$sdkincs\\crt\\gl");
    @dir_list2 = readdir(hDIR);
    closedir(hDIR);

    foreach (@dir_list2) {
        $_ = "crt\\gl\\$_";
    }

    push(@dir_list1, @dir_list2);
    undef(@dir_list2);

    open(cmn1, ">cmn.ddk.ini");

    for ($i=0;$i<=$#dir_list1;$i++) {
        next if ($dir_list1[$i] =~ /\.$/);
        next if (-d "$sdkincs\\$dir_list1[$i]");

        print(cmn1 "$sdkincs\\$dir_list1[$i]\n");
    }
    close(cmn1);

    # Create the .ini
    CreateCAB(  "cmn.ddk.ini","CMNINCS","Build_Environment",
                "Common_Include_Files","DDK",$bldno);

}
# --------------------------------------------------------------------------
SDKINCS: {
    if ($INCREMENTAL) {
        last SDKINCS unless (  defined $MAKECAB{SDKINCS} );
    }

    # List all files under \inc\.
    opendir(hDIR, "$sdkincs");
    @dir_list1 = readdir(hDIR);
    closedir(hDIR);

    #
    # Look for all OS specific headers
    #
    opendir(hDIR, "$sdkincs\\$OS_SUBDIR");
    @dir_list2 = readdir(hDIR);
    closedir(hDIR);

    foreach (@dir_list2) {
        $_ = "$OS_SUBDIR\\$_";
    }

    push(@dir_list1, @dir_list2);
    undef(@dir_list2);

    opendir(hDIR, "$sdkincs\\crt\\$OS_SUBDIR");
    @dir_list2 = readdir(hDIR);
    closedir(hDIR);

    foreach (@dir_list2) {
        $_ = "crt\\$OS_SUBDIR\\$_";
    }

    push(@dir_list1, @dir_list2);
    undef(@dir_list2);

    open(sdk1, ">sdk1.ddk.ini");
    open(sdk2, ">sdk2.ddk.ini");
    open(sdk3, ">sdk3.ddk.ini");

    for ($i=0;$i<=$#dir_list1;$i++) {
        next if ($dir_list1[$i] =~ /\.$/);
        next if (-d "$sdkincs\\$dir_list1[$i]");

        if (($i%3) == 0) {
            print(sdk1 "$sdkincs\\$dir_list1[$i]\n");
        } elsif (($i%3) == 1) {
            print(sdk2 "$sdkincs\\$dir_list1[$i]\n");
        } else {
            print(sdk3 "$sdkincs\\$dir_list1[$i]\n");
        }
    }
    close(sdk1);
    close(sdk2);
    close(sdk3);

    # CAB 1
    # Create the .ini
    CreateCAB(  "sdk1.ddk.ini","SDKINCS1","Build_Environment",
                "SDK_Include_Files","DDK",$bldno);

    # CAB 2
    # Create the .ini
    CreateCAB(  "sdk2.ddk.ini","SDKINCS2","Build_Environment",
                "SDK_Include_Files","DDK",$bldno);

    # CAB 3
    # Create the .ini
    CreateCAB(  "sdk3.ddk.ini","SDKINCS3","Build_Environment",
                "SDK_Include_Files","DDK",$bldno);
}

# --------------------------------------------------------------------------
DDKLIBS: {
    if ($INCREMENTAL) {
        last DDKLIBS unless (  defined $MAKECAB{DDKLIBS} );
    }

    my $libsub;
    if (uc($ENV{_BuildArch}) eq "IA64") {
        $libsub = "ia64";
    } elsif (uc($ENV{_BuildArch}) eq "AMD64") {
        $libsub = "amd64";
    } else {
        $libsub = "i386";
    }

    #
    # Handle backport libs
    #


    # only make the W2K cabs on x86 machines
    if ((uc($ENV{_BuildArch}) ne "IA64") && (uc($ENV{_BuildArch}) ne "AMD64")) {
        # W2K specific
        if ( -e "$ENV{_NTTREE}\\ddk_flat\\lib\\w2k" ) {
            # List all files under \lib\w2k\...
            system("dir $ENV{_NTTREE}\\ddk_flat\\lib\\w2k /s/b/a-d > w2klibs.ddk.ini 2>nul");
        }

        # Make the cabs
        if ( -e "w2klibs.ddk.ini" ) {
            # Create the .ini
            CreateCAB(  "w2klibs.ddk.ini","W2K_LIBS","Build_Environment",
                        "W2K_Library_Files","DDK",$bldno);
        }
    }

    # WXP specific
    if ( -e "$ENV{_NTTREE}\\ddk_flat\\lib\\wxp" ) {
        # List all files under \lib\wxp\...
        system("dir $ENV{_NTTREE}\\ddk_flat\\lib\\wxp /s/b/a-d > wxplibs.ddk.ini 2>nul");
    }

    if ( -e "wxplibs.ddk.ini" ) {
        if (uc($ENV{_BUILDARCH})  eq "IA64") {
            $cabname="XPILIB";
        } elsif (uc($ENV{_BUILDARCH})  eq "AMD64") {
            $cabname="XPALIB";
        } else {
            $cabname="XPXLIB";
        }

        # Create the .ini
        CreateCAB(  "wxplibs.ddk.ini","$cabname","Build_Environment",
                    "Wxp_Library_Files","DDK",$bldno);

    }

    if (uc($ENV{_BUILDARCH})  eq "IA64") {
        $cabname="IA6dLIB";
    } elsif (uc($ENV{_BUILDARCH})  eq "AMD64") {
        $cabname="A64dLIB";
    } else {
        $cabname="X86dLIB";
    }
    
    $samplename  ="$ENV{_BuildArch}_Libraries";
    $friendlyname="$ENV{_BuildArch}_Libraries";
 
    # List all files under \tools
    opendir(hDIR, "$ENV{_NTTREE}\\ddk_flat\\$libdir");
    @dir_list1=readdir hDIR;
    closedir(hDIR);
    open(LIBS1, ">libs1.ddk.ini");
    open(LIBS2, ">libs2.ddk.ini");
    open(LIBS3, ">libs3.ddk.ini");

    for ($i=0;$i<=$#dir_list1;$i++) {
        next if ($dir_list1[$i] =~ /^\./);

        if (($i % 3) == 0) {
            print(LIBS1 "$ENV{_NTTREE}\\ddk_flat\\$libdir\\$dir_list1[$i]\n");
        } elsif (($i % 3) == 1) {
            print(LIBS2 "$ENV{_NTTREE}\\ddk_flat\\$libdir\\$dir_list1[$i]\n");
        } else {
            print(LIBS3 "$ENV{_NTTREE}\\ddk_flat\\$libdir\\$dir_list1[$i]\n");
        }
    }
    close(LIBS1);
    close(LIBS2);


    #
    # handle files that are not processor-specific
    # put them all in the libs3 cab since we expect very few
    #
    opendir(hDIR, "$ENV{_NTTREE}\\ddk_flat\\lib\\wnet");
    @dir_list1=readdir hDIR;
    for ($i=0;$i<=$#dir_list1;$i++) {
        next if (-d "$ENV{_NTTREE}\\ddk_flat\\lib\\wnet\\$dir_list1[$i]");
        next if ($dir_list1[$i] =~ /^\./);
        print(LIBS3 "$ENV{_NTTREE}\\ddk_flat\\lib\\wnet\\$dir_list1[$i]\n");
    }
    closedir(hDIR);

    close(LIBS3);

    # CAB 1
    # Create the .ini
    CreateCAB(  "libs1.ddk.ini","${cabname}1","Build_Environment",
                "${samplename}","DDK",$bldno);

    # CAB 2
    # Create the .ini
    CreateCAB(  "libs2.ddk.ini","${cabname}2","Build_Environment",
                "$samplename","DDK",$bldno);

    # CAB 3
    # Create the .ini
    CreateCAB(  "libs3.ddk.ini","${cabname}3","Build_Environment",
                "$samplename","DDK",$bldno);

}
# --------------------------------------------------------------------------
IFSLIBS: {
    if ($INCREMENTAL) {
        last IFSLIBS unless (  defined $MAKECAB{IFSLIBS} );
    }

    if (uc($ENV{_BUILDARCH})  eq "IA64") {
        $cabname="IA6iLIB";
    } elsif (uc($ENV{_BUILDARCH})  eq "AMD64") {
        $cabname="A64iLIB";
    } else {
        $cabname="X86iLIB";
    }
    
    # List all files under \inc\ddk\...
    system("dir $ENV{_NTTREE}\\ifs_flat\\$libdir /s/b/a-d > ifslibs.ddk.ini 2>nul");

    # Create the .ini
    CreateCAB(  "ifslibs.ddk.ini","${cabname}1","Build_Environment",
                "Library_Files","IFS",$bldno);
}
# --------------------------------------------------------------------------
PDKLIBS: {
    if ($INCREMENTAL) {
        last PDKLIBS unless (  defined $MAKECAB{PDKLIBS} );
    }

    if (uc($ENV{_BUILDARCH})  eq "IA64") {
        $cabname="IA6pLIB";
    } elsif (uc($ENV{_BUILDARCH})  eq "AMD64") {
        $cabname="A64pLIB";
    } else {
        $cabname="X86pLIB";
    }

    if (uc($ENV{_BuildType}) eq "CHK" ) {
        $cabname .= "c";
    } else {
        $cabname .= "f";
    }
    
    # List all files under \inc\ddk\...
    system("dir $ENV{_NTTREE}\\processor_flat\\$libdir /s/b/a-d > pdklibs.ddk.ini 2>nul");

    # Create the .ini
    CreateCAB(  "pdklibs.ddk.ini","${cabname}1","Build_Environment",
                "Library_Files","processor",$bldno);
}

# --------------------------------------------------------------------------
HALLIBS: {
    if ($INCREMENTAL) {
        last HALLIBS unless (  defined $MAKECAB{HALLIBS} );
    }

    if (uc($ENV{_BUILDARCH})  eq "IA64") {
        $cabname="IA6hLIB";
    } elsif (uc($ENV{_BUILDARCH})  eq "AMD64") {
        $cabname="A64hLIB";
    } else {
        $cabname="X86hLIB";
    }
    
    # List all files under \inc\ddk\...
    system("dir $ENV{_NTTREE}\\hal_flat\\$libdir /s/b/a-d > hallibs.ddk.ini 2>nul");

    # Create the .ini
    CreateCAB(  "hallibs.ddk.ini","${cabname}1","Build_Environment",
                "Library_Files","HAL",$bldno);
}

# --------------------------------------------------------------------------
DDKBINS: {
    if ($INCREMENTAL) {
        last DDKBINS unless (  defined $MAKECAB{DDKBINS} );
    }

    $bindir ="$ENV{_NTTREE}\\ddk_flat\\bin";

    # List all files under bin
    opendir(hDIR, "$bindir"); # Get the first level directories
    @dir_list1=readdir(hDIR);
    closedir(hDIR);
    open(hDIR, ">cmnbins.ddk.ini");

    foreach $dir (@dir_list1) {
        # Skip . & .. as well as files.
        next if  ( -d "$bindir\\$dir");
        next if (($dir eq ".") or ($dir eq ".."));
        print(hDIR "$bindir\\$dir\n");
    }
    close(hDIR);

    system("dir $ENV{_NTTREE}\\ddk_flat\\bin\\wppconfig /s/b/a-d  >>cmnbins.ddk.ini 2>nul");

    # Create the .ini
    CreateCAB(  "cmnbins.ddk.ini","CMNBINS","Build_Environment",
                "Comon_Build_Tools","DDK",$bldno);

    if (uc($ENV{_BUILDARCH})  eq "IA64") {
        $cabname="IA6dBIN";
    } elsif (uc($ENV{_BUILDARCH})  eq "AMD64") {
        $cabname="A64dBIN";
    } else {
        $cabname="X86bBIN";
    }

    $samplename  ="$ENV{_BuildArch}_$ENV{_BuildType}_Binaries";
    $friendlyname="$ENV{_BuildArch}_$ENV{_BuildType}_Binaries";

    if (uc($ENV{_BUILDARCH})  eq "X86") {
        # List all files under bin\x86
         @dir_list1=`dir $bindir\\x86 /s/b/a-d`;

        open(hDIR, ">x86bins.ddk.ini");

        foreach $dir (@dir_list1) {
            print(hDIR "$dir\n");
        }
        close(hDIR);

        # Create the .ini
        CreateCAB(  "x86bins.ddk.ini","X86dBINS","Build_Environment",
                    "X86_Build_Tools","DDK",$bldno);

    }

    # Cross compiler tools
    if (uc($ENV{_BUILDARCH})  eq "X86") {
        opendir(hDIR, "$bindir\\win64\\x86");
        @dir_list1=readdir(hDIR);
        closedir(hDIR);

        open(hDIR, ">xcomp_bins.ddk.ini");
        foreach $dir (@dir_list1) {
            # Skip . & .. as well as directory files (which shouldn't be there anyhow).
            next unless ((! -d "$bindir\\win64\\x86\\$dir") and ($dir ne ".") and ($dir ne ".."));
            print(hDIR "$bindir\\win64\\x86\\$dir\n");
        }
        close(hDIR);

        # Create the .ini
        CreateCAB(  "xcomp_bins.ddk.ini","XCmpdBINS","Build_Environment",
                    "CrossCompile_Build_Tools","DDK",$bldno);

        # AMD64 cross compiler tools
        opendir(hDIR, "$bindir\\win64\\x86\\amd64");
        @dir_list1=readdir(hDIR);
        closedir(hDIR);

        open(hDIR, ">axcomp_bins.ddk.ini");
        foreach $dir (@dir_list1) {
            # Skip . & .. as well as directory files (which shouldn't be there anyhow).
            next unless ((! -d "$bindir\\win64\\x86\\amd64\\$dir") and ($dir ne ".") and ($dir ne ".."));
            print(hDIR "$bindir\\win64\\x86\\amd64\\$dir\n");
        }
        close(hDIR);


        # Create the .ini
        CreateCAB(  "axcomp_bins.ddk.ini","A64xdBINS","Build_Environment",
                    "AMD64_CrossCompile_Build_Tools","DDK",$bldno);

    }

    if (uc($ENV{_BUILDARCH})  eq "IA64") {
        # List all files under bin\ia64
        opendir(hDIR, "$bindir\\ia64"); # Get the first level directories
        @dir_list1=readdir(hDIR);
        closedir(hDIR);
        open(hDIR, ">ia64bins.ddk.ini");

        foreach $dir (@dir_list1) {
            # Skip . & .. as well as directory files (which shouldn't be there anyhow).
            next unless ((! -d "$bindir\\ia64\\$dir") and ($dir ne ".") and ($dir ne ".."));
            print(hDIR "$bindir\\ia64\\$dir\n");
        }
        close(hDIR);

        # Create the .ini
        CreateCAB(  "ia64bins.ddk.ini","IA6dBINS","Build_Environment",
                    "IA64_Build_Tools","DDK",$bldno);

    }

    if (uc($ENV{_BUILDARCH})  eq "AMD64") {
        # no native amd64 tools yet
    }
}

# --------------------------------------------------------------------------
COREDDK: {
    if ($INCREMENTAL) {
        last COREDDK unless (  defined $MAKECAB{COREDDK} );
    }

    system("dir $ENV{_NTTREE}\\ddk_flat        /b/a-d  >  core.ddk.ini 2>nul");

    # Create the .ini
    CreateCAB(  "core.ddk.ini","COREDDK","Build_Environment",
                "DDK_Core_Files","DDK",$bldno);
}

# --------------------------------------------------------------------------
COREPDK: {
    if ($INCREMENTAL) {
        last COREPDK unless (  defined $MAKECAB{COREPDK} );
    }

    last COREPDK unless (-e "$ENV{_NTTREE}\\processor_flat\\src\\processor");

    @dir_list1=`dir $ENV{_NTTREE}\\processor_flat\\src\\processor /b/a-d`;
    foreach (@dir_list1) {
    next if (m/^\s*$/);
    chomp;
    system("echo $ENV{_NTTREE}\\processor_flat\\src\\processor\\$_ >> pdkcore.ddk.ini");
    }

    # Create the .ini
    CreateCAB(  "pdkcore.ddk.ini","COREPDK","Build_Environment",
                "PDK_Core_Files","processor",$bldno);
}

# --------------------------------------------------------------------------
COREHAL: {
    if ($INCREMENTAL) {
        last COREHAL unless (  defined $MAKECAB{COREHAL} );
    }

    last COREHAL unless (-e "$ENV{_NTTREE}\\hal_flat\\src\\hals");

    @dir_list1=`dir $ENV{_NTTREE}\\hal_flat\\src\\hals /b/a-d`;
    foreach (@dir_list1) {
       next if (m/^\s*$/);
       chomp;
       system("echo $ENV{_NTTREE}\\hal_flat\\src\\hals\\$_ >> halcore.ddk.ini");
    }

    @dir_list1=`dir $ENV{_NTTREE}\\hal_flat /b/a-d`;
    foreach (@dir_list1) {
       next if (m/^\s*$/);
       chomp;
       system("echo $ENV{_NTTREE}\\hal_flat\\\\$_ >> halcore.ddk.ini");
    }

    # Create the .ini
    CreateCAB(  "halcore.ddk.ini","COREHAL","Build_Environment",
                "HAL_Core_Files","HAL",$bldno);
}

# --------------------------------------------------------------------------
COREIFS: {
    if ($INCREMENTAL) {
        last COREIFS unless (  defined $MAKECAB{COREIFS} );
    }

    last COREIFS unless (-e "$ENV{_NTTREE}\\ifs_flat");

    @dir_list1=`dir $ENV{_NTTREE}\\ifs_flat\\src\\filesys /b/a-d`;
    foreach (@dir_list1) {
    next if (m/^\s*$/);
        chomp;
        system("echo $ENV{_NTTREE}\\ifs_flat\\src\\filesys\\$_ >> ifscore.ddk.ini");
    }

    # Create the .ini
    CreateCAB(  "ifscore.ddk.ini","COREIFS","Build_Environment",
                "IFS_Core_Files","IFS",$bldno);
}

# --------------------------------------------------------------------------
DDKDOCS: {
    if ($INCREMENTAL) {
        last DDKDOCS unless (  defined $MAKECAB{DDKDOCS} );
    }

    # Make the Docs
    opendir(hDir, "$ENV{_NTTREE}\\ddk_flat\\help")||warn("Can't open $ENV{_NTTREE}\\ddk_flat\\help: $!\n");
    @dir_list1=readdir(hDir);
    closedir(hDir);

    my @general_cab;
    foreach $file (@dir_list1) {
        next if ($file =~ /^\./);
        next if ($file =~ /\.chi$/); # Don't use .chi, use .chm below
        next if (-d "$ENV{_NTTREE}\\ddk_flat\\help\\$file");
        
        if ($file =~ /\.chm$/i) {
            # We have a .chm
            $file =~ s/\.chm$//i; # Remove the extension
            system("dir $ENV{_NTTREE}\\ddk_flat\\help\\$file.* /s/b/a-d > $file.ddk.ini 2>nul");
            $file=uc($file); # Force uppercase

            # Create the .ini
            CreateCAB(  "$file.ddk.ini","$file","Documentation",
                        "${file}_Doc","DDK",$bldno);
        } else {
            system("dir $ENV{_NTTREE}\\ddk_flat\\help\\$file /s/b/a-d >> general_docs.ddk.ini 2>nul");
        }
    }
    CreateCAB("general_docs.ddk.ini","CMNDOCS", "Documentation",     "Common_Docs_Files", "DDK",$bldno);
}

# --------------------------------------------------------------------------
IFSDOCS: {
    if ($INCREMENTAL) {
        last IFSDOCS unless (  defined $MAKECAB{IFSDOCS} );
    }

    # Make the Docs
    opendir(hDir, "$ENV{_NTTREE}\\ifs_flat\\help")||warn("Can't open $ENV{_NTTREE}\\ifs_flat\\help: $!\n");
    @dir_list1=readdir(hDir);
    closedir(hDir);

    foreach $file (@dir_list1) {
        next if ($file =~ /^\./);
        next if ($file =~ /\.chi$/); # Don't use .chi, use .chm below
        next if (-d "$ENV{_NTTREE}\\ifs_flat\\help\\$file");
        
        if ($file =~ /\.chm$/i) {
            # We have a .chm
            $file =~ s/\.chm$//i; # Remove the extension
            system("dir $ENV{_NTTREE}\\ifs_flat\\help\\$file.* /s/b/a-d > $file.ddk.ini 2>nul");
            $file=uc($file); # Force uppercase

            # Create the .ini
            CreateCAB(  "$file.ddk.ini","$file","Documentation",
                        "${file}_Doc","IFS",$bldno);
        } else {
            logdebug("Not including \\help\\$file\n");
        }
    }
}                                      

    # Don't exit until all subprocesses have completed.
    WaitForAllProcesses();
    
    if (-e "$ENV{_NTTREE}\\ddk_cd\\common\\cabs.in_") {
    system("copy $ENV{_NTTREE}\\ddk_cd\\common\\cabs.in_ $ENV{_NTTREE}\\ddk_cd\\common\\cabs.ini >nul");
        open(hF, ">>$ENV{_NTTREE}\\ddk_cd\\common\\cabs.ini");
        print(hF "Build=$bldno\n");
        close(hF);
    }
    if (-e "$ENV{_NTTREE}\\ifs_cd\\common\\cabs.in_") {
    system("copy $ENV{_NTTREE}\\ifs_cd\\common\\cabs.in_ $ENV{_NTTREE}\\ifs_cd\\common\\cabs.ini >nul");
        open(hF, ">>$ENV{_NTTREE}\\ifs_cd\\common\\cabs.ini");
        print(hF "Build=$bldno\n");
        close(hF);
    }
    if (-e "$ENV{_NTTREE}\\hal_cd\\common\\cabs.in_") {
    system("copy $ENV{_NTTREE}\\hal_cd\\common\\cabs.in_ $ENV{_NTTREE}\\hal_cd\\common\\cabs.ini >nul");
        open(hF, ">>$ENV{_NTTREE}\\hal_cd\\common\\cabs.ini");
        print(hF "Build=$bldno\n");
        close(hF);
    }

    if (-e "$ENV{_NTTREE}\\processor_cd\\common\\cabs.in_") {
    system("copy $ENV{_NTTREE}\\processor_cd\\common\\cabs.in_ $ENV{_NTTREE}\\processor_cd\\common\\cabs.ini >nul");
        open(hF, ">>$ENV{_NTTREE}\\processor_cd\\common\\cabs.ini");
        print(hF "Build=$bldno\n");
        close(hF);
    }

    $time = time() - $time;
    logmsg("Total run time: $time seconds.\n");
    print(STDERR "$0: Finished.\n\n");

    END {
        # Delete .tmp file so postbuild.cmd knows the script has finished
        unlink ("$ENV{TEMP}\\ddkcabs.tmp");

    }

# --------------------------------------------------------------------------
# Creates a CAB and INF from a list of files
# --------------------------------------------------------------------------
sub CreateCAB {
    print(".") unless ($verbose);   # Print something so the user knows the script is still running

    my $filelist        = shift;
    my $cabname         = shift;
    my $groupname       = shift;
    my $samplename      = shift;
    my $kit             = shift;
    my $bldno           = shift;

    my $FileIndex       = -1;
    my $friendlyname    = $samplename;
    my $GroupIndex      = -1;
    my $InfCopyFileList = "InfFiles";
    my $PrevCommand     = "";
    my $PrevDestDir     = "";
    my $TotalSize       = 0;    

    my @files;

    my $file;
    my $FileProcessed;
    my $hFILE;
    my $NewSection;
    my $source_file;
    my $source_dir;
    my $dest_dir;
    my $ERRORLEVEL;
    my $FileSize;
    my $CabFileName;

    chomp($cabname);

    unless (-e $filelist) {
        logerror("$filelist did not exist - cannot build cab.");
        return(5);
    }
    
    # These files get rolled into the INF once the entire filelist
    # is processed.
    open(hFILE, ">${cabname}_DestDirsFiles")
        || die("Couldn't write to ${cabname}_DestDirsFile: $!\n");
    printf(hFILE "[DestinationDirs]\n");
    close(hFILE);

    open(hFILE, ">${cabname}_SourceFiles")
        || die("Couldn't write to ${cabname}_SourceFiles: $!\n");
    printf(hFILE "\n");
    close(hFILE);

    open(hFILE, ">${cabname}_SourceDisk")
        || die("Couldn't write to ${cabname}_SourceDisk: $!\n");
    printf(hFILE "[SourceDisksFiles]\n");
    close(hFILE);

    #
    # Process the filelist
    #
    open(hFILE, "$filelist");
    @files=<hFILE>;
    close(hFILE);

    # For every file in the list, split it up into the format expected by genddkcab.bat:
    #   $source_dir, $source_file, $dest_dir, $dest_file, $command
    foreach $file (@files) {
        chomp($file);

        $file        =~ m/^(.*)\\.*$/;
        # source_dir is %_NTTREE%\[ddk|hal|ifs]_flat + dest_dir
        if (! defined($1)) {
            $source_dir  =  "$ENV{_NTTREE}\\ddk_flat";
        } else {
            $source_dir  =  $1;
        }

        $file        =~ m/^.*\\(.*)$/;
        # source_file is filename
        if (! defined($1)) {
            $source_file  =  $file;
        } else {
            $source_file =  $1;
        }

        $file        =~ m/^.*_flat(\\.*\\).*$/;
        # dest_dir is dir less %_NTTREE%\[ddk|hal|ifs]_flat
        if (! defined($1)) {
            $dest_dir= "\\";
        } else {
            $dest_dir=  $1;
        }

        $FileProcessed=FALSE;

        # Optimization to not generate excessive install sections in the inf.
        $NewSection=TRUE;
        $NewSection=FALSE if (uc($dest_dir) eq uc($PrevDestDir));

        $PrevDestDir=$dest_dir;

        if ($NewSection) {
            $GroupIndex+=1;
            open(hDDF, ">>${cabname}_DestDirsFiles");
            printf(hDDF "Files_${GroupIndex}=49000,\"$dest_dir\"\n");
            close(hDDF);

            $InfCopyFileList="${InfCopyFileList},Files_${GroupIndex}";
            open(hDDF, ">>${cabname}_SourceFiles");
            printf(hDDF "[Files_${GroupIndex}]\n");
            close(hDDF);
        }

        if (! -e "$source_dir\\$source_file") {
            logerror("489: File $source_dir\\$source_file does not exist");
            next;
        }

        # Move on to the next file number
        $FileIndex += 1;

        # Generate the name of the file within the cabfile.
        $CabFileName="${cabname}_FILE_${FileIndex}";

        # process the source file into the temporary cabfile name
        $ERRORLEVEL=system("COPY $source_dir\\$source_file $CabFileName >nul 2>nul");

        # check for errors
        if ($ERRORLEVEL) {
            logerror("545: COPY of file $source_dir\\$source_file failed (ErrorLevel $ERRORLEVEL)");
        }

        # Get the size of the file, so the size requirements of the cab can be computed.
        $FileSize = (stat("$CabFileName"))[7];
        printf("adding $CabFileName size $FileSize\n") if ($CABDEBUG);
        $TotalSize += $FileSize;

        # Write the DestinationFileName, CabFileName into the inf so the files
        # can be extracted and installed properly.
        open(hDDF, ">>${cabname}_SourceDisk")
            || die("Couldn't write to ${cabname}_SourceDisk: $!\n");;
        printf(hDDF "${CabFileName}=1,,$FileSize\n");
        close(hDDF);

        open(hDDF, ">>${cabname}_SourceFiles");
        printf(hDDF "$source_file,$CabFileName,,\n");
        close(hDDF);

    }

    # If there were not files, just leave
    if ($FileIndex == -1) {
        logerror("241: No files in the cab ($cabname)");
        unlink("$filelist")               ||die("$!\n");;
        unlink("${cabname}_SourceFiles")  ||die("$!\n");;
        unlink("${cabname}_SourceDisk")   ||die("$!\n");;
        unlink("${cabname}_DestDirsFiles")||die("$!\n");;
        return(15);
    }

    if ($verbose) {
        print STDERR "Creating $cabname\n";
    }

    # Create the INF
    CreateINF($cabname, $friendlyname, $InfCopyFileList, $FileIndex, $TotalSize);

    # start cabarc
    CreateNewProcess($cabname, $kit);

    # Delete the temporary file list
    unlink("$filelist");
    return(1);
}

# --------------------------------------------------------------------------
# Builds the installation inf
# --------------------------------------------------------------------------
sub CreateINF {
    my $CabName         = shift;
    my $FriendlyName    = shift;
    my $InfCopyFileList = shift;
    my $FileIndex       = shift;
    my $TotalSize       = shift;

    my @lines;

    open(hFILE, ">>${CabName}.inf")||return(25);
    print hFILE<<EOF;
[Version]
AdvancedInf = 2
Signature =\"\$CHICAGO\$\"
SetupClass = Base

[DefaultInstall]
CopyFiles=${InfCopyFileList}
CustomDestination= PDCDest
RequiredEngine = setupapi;
AddReg = RegVersion,DocKey

[DefaultUninstall]
DelFiles=${InfCopyFileList}
CustomDestination= PDCDest
DelReg = RegVersion,DocKey

EOF

    open(hADDFILE, "<${CabName}_DestDirsFiles");
    @lines=<hADDFILE>;
    close(hADDFILE);
    foreach (@lines) {
        printf(hFILE "$_");
    }
    unlink("${CabName}_DestDirsFiles")||die("$!\n");;

    print hFILE<<EOF;
InfFiles=17,\"msddk\\${bldno}\"
DefaultDestDir=49000,\"${CabName}\"

[RegVersion]
\"HKLM\",\"SOFTWARE\\Microsoft\\WINDDK\\Restart\\Cabs\",\"${CabName}\",0,\"done\"

[PDCDest]
49000,49001,49002=SDKCust, 17

[SDKCust]
;if key below exists, use this string to seed install path
\"HKLM\", \"Software\\Microsoft\\WINDDK\", \"SFNDirectory\",,\"%DefaultDir%\"

[DocKey]

[InfFiles]
${CabName}.inf

EOF

    open(hADDFILE, "<${CabName}_SourceFiles");
    @lines=<hADDFILE>;
    close(hADDFILE);
    foreach (@lines) {
        printf(hFILE "$_");
    }
    unlink("${CabName}_SourceFiles")||die("$!\n");;

    printf(hFILE "\n");
    printf(hFILE "[SourceDisksNames]\n");
    printf(hFILE "1=\"${CabName}.cab\",${CabName}.cab,0\n");

    open(hADDFILE, "<${CabName}_SourceDisk");
    @lines=<hADDFILE>;
    close(hADDFILE);
    foreach (@lines) {
        printf(hFILE "$_");
    }
    unlink("${CabName}_SourceDisk")||die("$!\n");

    $FileIndex++;

    printf(hFILE "\n\n");
    printf(hFILE "[Strings]\n");
    printf(hFILE "FriendlyName=${FriendlyName}\n");
    printf(hFILE "AppKey=SOFTWARE\\Microsoft\\WINDDK\n");
    printf(hFILE "FileCount=${FileIndex}\n");
    printf(hFILE "TotalSize=${TotalSize}\n");

    close(hFILE);

    return(0);
}

# --------------------------------------------------------------------------
# Starts a new process once there is room in the process table
# --------------------------------------------------------------------------
sub CreateNewProcess {
    my $CabName    = shift;
    my $kit        = shift;
    my $ERRORLEVEL = 0;
    my $ExitCode   = 0;
    my $i;

    # Limit total running processes- label/goto construct needed because otherwise
    # all processes are tested for instead of just finding the first one that has
    # finished.
    top:
    while (@Processes >= $MAX_PROCESSES) {
        for ($i=0;$i<=$#Processes;$i++) {
            $Processes[$i][0]->GetExitCode( $ExitCode );
            if ($ExitCode != 259 ) {
                # Do post processes commands before removing it
                $ERRORLEVEL= system("move /Y $Processes[$i][1].CAB $ENV{_NTTREE}\\$Processes[$i][2]_cd\\Common >nul 2>nul");
                logerror("341: $Processes[$i][1].CAB could not be placed") if ($ERRORLEVEL);
                $ERRORLEVEL= system("move /Y $Processes[$i][1].INF $ENV{_NTTREE}\\$Processes[$i][2]_cd\\Common >nul 2>nul");
                logerror("342: $Processes[$i][1].INF could not be placed") if ($ERRORLEVEL);
                $ERRORLEVEL=system("del /f $Processes[$i][1]_FILE_* 2>nul");
                splice(@Processes,$i,1);
                $i--; # Decrement count since the array changed
                goto top;
            }
        }
        sleep(2);
    }

    # Create the new process
    Win32::Process::Create($i, $exe, "$exe $global_param ${CabName}.cab ${CabName}_FILE_*",
                            0, DETACHED_PROCESS, "$ENV{TEMP}");
    # Update the process table
    push(@Processes, [$i,$CabName,$kit]);
}

# --------------------------------------------------------------------------
# Waits for all currently running processes to finish
# --------------------------------------------------------------------------
sub WaitForAllProcesses {
    my $i;
    my $ERRORLEVEL = 0;

    for ($i=0;$i<=$#Processes;$i++) {
        # Wait for current process to end
        print(".") unless ($verbose);
        $Processes[$i][0]->Wait( INFINITE );
        # Do post processes commands
        $ERRORLEVEL= system("move /Y $Processes[$i][1].CAB $ENV{_NTTREE}\\$Processes[$i][2]_cd\\Common >nul 2>nul");
        $ERRORLEVEL+=system("move /Y $Processes[$i][1].INF $ENV{_NTTREE}\\$Processes[$i][2]_cd\\Common >nul 2>nul");
        logerror(__LINE__.": $Processes[$i][1] could not be placed") if ($ERRORLEVEL);
        $ERRORLEVEL=system("del /f $Processes[$i][1]_FILE_* 2>nul");
    }
    print("\n");
}

# --------------------------------------------------------------------------
# Error logging routines
# --------------------------------------------------------------------------
sub logdebug {  my($errormsg)="DEBUG_MSG : @_";
                logprint($errormsg);
                return(TRUE);}

sub logerror {  my($errormsg)="ERROR_MSG : @_";
                logprint($errormsg);
                return(TRUE);}

sub logmsg   {  my($errormsg)="BUILD_MSG : @_";
                logprint($errormsg);
                return(TRUE);}

sub logprint {  open(hLogFile,">>$handle")||warn("@_\n");
                printf(hLogFile "$0 : @_\n");
                close(hLogFile);
                return(TRUE);}

# --------------------------------------------------------------------------
# Program description and usage
# --------------------------------------------------------------------------
sub Usage {
    print "
     Usage: $0 [-n <N>] [-f] [-l <language>] [-s] [-v]

     This tool requires a Razzle window.

     Generates CABs for the Kernelmode Development Kits.  N, which is
     optional, indicates the number of processes to start per processor.
     The default value is 2.

     By default, $0 will exit early if the environment variable
     OFFICAL_BUILD_MACHINE is not defined.  To override this behavior,
     and for CAB generation, use -F.

     -L is used, and any language other than 'usa' is passed, CAB
     generation will not take place.

     -V turns on verbose mode.  See what cabs are being built.

     -S spoofs full postbuild. (DDKCabs.bat otherwise relies upon build_number.cmd)

     Dependencies:
     o The following environment variables are expected to be defined:
       %_NTDRIVE%, %_NTROOT%, %_BUILDARCH%, %_BUILDTYPE%, %_NTTREE%,
       %RazzleToolPath%, %NUMBER_OF_PROCESSORS%, %TEMP%, and
       %PROCESSOR_ARCHITECTURE%.

     o The following directory trees are assumed to exist:
        1) %_NTTREE%\\ddk_cd
        2) %_NTTREE%\\ddk_flat
        3) %_NTTREE%\\ifs_cd
        4) %_NTTREE%\\ifs_flat
        5) %_NTTREE%\\hal_cd
        6) %_NTTREE%\\hal_flat

    ";

    return(30);
}

__END__
:endofperl
