use ExtUtils::MakeMaker;
use POSIX qw(uname);

# Check this is Solaris
my ($sys, $rel) = (POSIX::uname())[0,2];
if ($sys ne "SunOS" || $rel !~ /^(5.5.1|5.6|5.7)$/)
   {
   warn("WARNING: StatsView has only been tested on 2.5.1, 2.6 & 2.7\n",
        "It probably won't work on $sys $rel\n\n");
   }

# Check GNUPlot is installed, and is the correct version
if (! grep(-x "$_/gnuplot", split(":", $ENV{PATH})))
   {
   warn("WARNING: GNUPlot not found on your \$PATH\n",
        "StatsView won't work unless you have GNUPlot installed.\n",
        "A copy can be found in the gnuplot_src subdirectory\n\n");
   }
my $hdr = `gnuplot 2>&1 <<EOF\nshow version\nEOF`;
my ($ver) = $hdr =~ /version\s*([\d.]*)/;
my ($plev) = $hdr =~ /patchlevel\s*(.*)/;
if ($ver < 3.6 && $plev !~ /beta/)
   {
   warn("WARNING: Incorrect version of GNUPlot found\n",
        "StatsView won't work unless you have GNUPlot beta 3.6 installed.\n",
        "A copy can be found in the gnuplot_src subdirectory\n\n");
   }

WriteMakefile(
   'NAME'         => 'StatsView',
   'VERSION_FROM' => 'scripts/sv',
   'DIR'          => [ 'graph', 'oracle' ],
   'EXE_FILES'    => [ 'scripts/sv',  'scripts/svdc', 'scripts/oar' ],
);
