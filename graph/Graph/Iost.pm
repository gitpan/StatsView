################################################################################

use strict;
use POSIX qw(mktime strftime);
use StatsView::Graph;
package StatsView::Graph::Iost;
@StatsView::Graph::Iost::ISA = qw(StatsView::Graph);
   
################################################################################

sub new()
{
my ($class, $file) = @_;
$class = ref($class) || $class;
my $self = $class->SUPER::init($file);

# Figure out what type of file we have
my $iost = IO::File->new($file, "r") || die("Can't open $file: $!\n");

# Look for the header line
my $line;
while (defined($line = $iost->getline()) && $line =~ /^\s*$/) { }
$line =~ /iost\+ started on/ || die("$self->{file} is not a iost+ file (1)\n");
$self->{title} = "Iost+ Statistics";

$iost->close();
return($self);
}

################################################################################

sub read($)
{
my ($self) = @_;
$self->SUPER::read();

# Open the file
my $iost = IO::File->new($self->{file}, "r")
   || die("Can't open $self->{file}: $!\n");

# Look for the header line & get the date
my $line;
while (defined($line = $iost->getline()) && $line =~ /^\s*$/) { }
$line =~ /iost\+ started on (\d\d)\/(\d\d)\/(\d\d\d\d) (\d\d):(\d\d):(\d\d)/
   || die("$self->{file} is not a iost+ file (1)\n");
my ($D, $M, $Y, $h, $m, $s) = ($1, $2, $3, $4, $5, $6);
$self->{date} = "$D/$M/$Y";
$m--; $Y -= 1900;
my $last_t = POSIX::mktime($s, $m, $h, $D, $M, $Y);

# Define the column types - N = numeric, % = percentage
$self->define_cols(['Read op/sec', 'Write op/sec',
                    'Read Kb/sec', 'Write Kb/sec',
                    'WaitQ/qlen', 'WaitQ/res_t', 'WaitQ/svc_t', 'WaitQ/%ut',
                    'ActiveQ/qlen', 'ActiveQ/res_t', 'ActiveQ/svc_t',
                    'ActiveQ/%ut'],
                   [ qw(N N N N N N N % N N N %) ]);

while (defined($line = $iost->getline()))
   {
   # Look for the start of the next sample point (a timestamp)
   next if ($line !~ /^(\d\d):(\d\d):(\d\d)/);
   ($h, $m, $s) = ($1, $2, $3);
   my $t = POSIX::mktime($s, $m, $h, $D, $M, $Y);

   # Look for day rollover & save timestamp
   if ($t < $last_t)
      {
      $D++;
      $t = POSIX::mktime($s, $m, $h, $D, $M, $Y);
      }
   $last_t = $t;
   my $tstamp = POSIX::strftime("%d/%m/%Y %T", $s, $m, $h, $D, $M, $Y);
   push(@{$self->{tstamps}}, $tstamp);

   # Skip the next header line
   $iost->getline();

   # Read the data & save away
   while (defined($line = $iost->getline()) && $line !~ /^\s*$|TOTAL|:\//)
      {
      my (@value) = split(' ', $line);
      my $inst = pop(@value);

      push(@{$self->{data}{$inst}}, { tstamp => $tstamp, value => [ @value ] });
      $self->{instance}{$inst} = $self->{index_3d}++
         if (! exists($self->{instance}->{$inst}));
      }
   }
$iost->close();
}

################################################################################

sub get_data_type($;$)
{
return("3d");
}

################################################################################
1;
