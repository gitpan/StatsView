################################################################################

use strict;
use POSIX qw(mktime strftime);
use StatsView::Graph;
package StatsView::Graph::Vxstat;
@StatsView::Graph::Vxstat::ISA = qw(StatsView::Graph);
   
%StatsView::Graph::Vxstat::m2n =
   ( Jan =>  0, Feb =>  1, Mar =>  2, Apr =>  3, May =>  4, Jun =>  5,
     Jul =>  6, Aug =>  7, Sep =>  8, Oct =>  9, Nov => 10, Dec => 11 );

################################################################################

sub new()
{
my ($class, $file) = @_;
$class = ref($class) || $class;
my $self = $class->SUPER::init($file);

# Figure out what type of file we have
my $vxstat = IO::File->new($file, "r") || die("Can't open $file: $!\n");
$self->{title} = "Veritas Statistics";
my $line;

# Look for the header lines
while (defined($line = $vxstat->getline()) && $line =~ /^\s*$/) { }
$line =~ /OPERATIONS\s+BLOCKS\s+AVG TIME\(ms\)/
   || die("$self->{file} is not a vxstat file (1)\n");
$line = $vxstat->getline();
$line =~ /TYP NAME\s+READ\s+WRITE\s+READ\s+WRITE\s+READ\s+WRITE/
   || die("$self->{file} is not a vxstat file (2)\n");

# Find the first 2 timestamps and calculate the interval
while (defined($line = $vxstat->getline()) && $line !~ /\d\d:\d\d:\d\d/) { }
my @d = split(/\s+|:/, $line);
$d[1] = $StatsView::Graph::Vxstat::m2n{$d[1]};
$d[6] -= 1900;
my $t1 = POSIX::mktime(@d[5,4,3,2,1,6]);
while (defined($line = $vxstat->getline()) && $line !~ /\d\d:\d\d:\d\d/) { }
@d = split(/\s+|:/, $line);
$d[1] = $StatsView::Graph::Vxstat::m2n{$d[1]};
$d[6] -= 1900;
my $t2 = POSIX::mktime(@d[5,4,3,2,1,6]);
$self->{interval} = $t2 - $t1;

$vxstat->close();
return($self);
}

################################################################################

sub read($)
{
my ($self) = @_;
$self->SUPER::read();

# Open the file
my $vxstat = IO::File->new($self->{file}, "r")
   || die("Can't open $self->{file}: $!\n");
my $line;

# Look for the header lines
while (defined($line = $vxstat->getline()) && $line =~ /^\s*$/) { }
$line =~ /OPERATIONS\s+BLOCKS\s+AVG TIME\(ms\)/
   || die("$self->{file} is not a vxstat file (3)\n");
$line = $vxstat->getline();
$line =~ /TYP NAME\s+READ\s+WRITE\s+READ\s+WRITE\s+READ\s+WRITE/
   || die("$self->{file} is not a vxstat file (4)\n");

# Define the column types - N = numeric, % = percentage
$self->define_cols(['Read op/sec', 'Write op/sec',
                    'Read blk/sec', 'Write blk/sec',
                    'Avg read (ms)', 'Avg write (ms)' ],
                   [ qw(N N N N N N) ]);

# Skip to the start of the second timestamp -
# the data after the first is info from the last reboot to the present
while (defined ($line = $vxstat->getline()) && $line !~ /\d\d:\d\d:\d\d/) { }
die("$self->{file} is not a vxstat file (5)\n") if (! $line);
while (defined ($line = $vxstat->getline()) && $line !~ /^\s*$/) { }
die("$self->{file} is not a vxstat file (6)\n") if (! $line);

my $interval = $self->{interval};
while (defined($line = $vxstat->getline()))
   {
   my @d = split(/\s+|:/, $line);
   $d[1] = $StatsView::Graph::Vxstat::m2n{$d[1]} + 1;
   my $tstamp = sprintf("%.2d/%.2d/%.4d %.2d:%.2d:%.2d", @d[2,1,6,3,4,5]);
   push(@{$self->{tstamps}}, $tstamp);

   # Read the data
   while (defined($line = $vxstat->getline()) && $line !~ /^\s*$/)
      {
      my (@value) = split(' ', $line);
      my $inst = shift(@value) . " " . shift(@value);

      # Scale values to be in units of a second
      @value[0..3] = map({ $_ / $interval } @value[0..3]);

      # Save the data
      push(@{$self->{data}{$inst}}, { tstamp => $tstamp, value => [ @value ] });
      $self->{instance}{$inst} = $self->{index_3d}++
         if (! exists($self->{instance}->{$inst}));
      }
   }
$vxstat->close();
}

################################################################################

sub get_data_type($;$)
{
return("3d");
}

################################################################################
1;
