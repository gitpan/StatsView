################################################################################

use strict;
use POSIX qw(mktime strftime);
use StatsView::Graph;
package StatsView::Graph::Vmstat;
@StatsView::Graph::Vmstat::ISA = qw(StatsView::Graph);
   
################################################################################

sub _getline($$)
{
my ($self, $fh) = @_;
my $line;
while (defined($line = $fh->getline()) && $line =~ /<<State change>>/i) { }
return($line);
}

################################################################################

sub new()
{
my ($class, $file) = @_;
$class = ref($class) || $class;
my $self = $class->SUPER::init($file);

# Figure out what type of file we have
my $vmstat = IO::File->new($file, "r") || die("Can't open $file: $!\n");
$self->{title} = "VM Statistics";
my $line;

# Look for the start/interval line
while (defined($line = $self->_getline($vmstat)) && $line =~ /^\s*$/) { }
$line =~ /start:/i  && $line =~ /interval:/i
   || die("$self->{file} has no start/interval information\n");

$line =~ m!start:\s+(\d\d/\d\d/\d\d(?:\d\d)?)\s+(\d\d:\d\d:\d\d)!i;
$self->{date} = $1;
my ($D, $M, $Y) = split(/\//, $1);
my ($h, $m, $s) = split(/:/, $2); 
$M--;
if ($Y >= 100) { $Y -= 1900; }
elsif ($Y <= 50) { $Y += 100; }
$self->{start} = POSIX::mktime($s, $m, $h, $D, $M, $Y);
$line =~ m!interval:\s+(\d+)!i;
$self->{interval} = $1;

# Look for the first header line
while (defined($line = $self->_getline($vmstat)) && $line =~ /^\s*$/) { }

$line =~ /^\s*procs\s+memory\s+page\s+disk\s+faults\s+cpu\s*$/i
   || die("$self->{file} is not an vmstat file (1)\n");

$vmstat->close();
return($self);
}

################################################################################

sub read($)
{
my ($self) = @_;
$self->SUPER::read();

# Open the file
my $vmstat = IO::File->new($self->{file}, "r")
   || die("Can't open $self->{file}: $!\n");
my ($line1, $line2);

# Look for the first header lines
while (defined ($line1 = $self->_getline($vmstat))
       && $line1 !~ /^\s*procs\s+memory\s+page\s+disk\s+faults\s+cpu\s*$/i) { }
die("$self->{file} is not a vmstat file (2)\n") if (! $line1);
$line2 = $self->_getline($vmstat);
die("$self->{file} is not a vmstat file (3)\n") if (! $line2);

# How many headers on line2 share a header from line1
my (@one2two) = (3, 2, 7, 4, 3, 3);

# Register the column types
my (@colname, @coltype);
my @h2 = split(' ', $line2);
foreach my $h1 (split(' ', $line1))
   {
   foreach my $h (splice(@h2, 0, shift(@one2two)))
      {
      push(@colname, "$h1:$h");
      push(@coltype, $h1 eq 'cpu' ? '%' : 'N');
      }
   }
$self->define_cols(\@colname, \@coltype);

# Work out the timestamp initial values
my $s = $self->{start};
my $ds = $self->{interval};

# Read the data
while (defined($line1 = $self->_getline($vmstat)))
   {
   # Skip header lines
   next if ($line1 =~ /^\s*procs/ || $line1 =~ /^\s*r b w/);

   # Work out the timestamp
   $s += $ds;
   my $tstamp = POSIX::strftime("%d/%m/%Y %T", localtime($s));
   push(@{$self->{tstamps}}, $tstamp);

   # Read the data
   my (@value) = split(' ', $line1);
   push(@{$self->{data}}, { tstamp => $tstamp, value => [ @value ] });
   }
$vmstat->close();
}

################################################################################

sub get_data_type($;$)
{
return("2d");
}

################################################################################
1;
