################################################################################

use strict;
use POSIX qw(mktime);
use StatsView::Graph;
package StatsView::Graph::Mpstat;
@StatsView::Graph::Mpstat::ISA = qw(StatsView::Graph);
   
################################################################################

sub getline($$)
{
my ($self, $fh) = @_;
my $line;
while (defined($line = $fh->getline()) &&
       index($line, "<<State change>>") != -1)
   { }
return($line);
}

################################################################################

sub new($$$)
{
my ($class, $file, $fh) = @_;
$class = ref($class) || $class;

# Look for the start/interval line
my $line;
while (defined($line = $class->getline($fh)) && $line =~ /^\s*$/) { }
$line =~ /start:/i  && $line =~ /interval:/i || return(undef);

# Look for the first header line
while (defined($line = $class->getline($fh)) && $line =~ /^\s*$/) { }
$line =~ /^\s*CPU\s+minf\s+mjf\s+/i || return(undef);

my $self = $class->SUPER::init($file);
$self->{category} = [ "Average Values", "Total Values", "Per CPU Values" ];
return($self);
}

################################################################################

sub read($$)
{
my ($self, $category) = @_;
$self->SUPER::read();

# Open the file
my $mpstat = IO::File->new($self->{file}, "r")
   || die("Can't open $self->{file}: $!\n");
$self->{title} = "Mpstat $category";

# Look for the start/interval line
my $line;
while (defined($line = $self->getline($mpstat)) && $line =~ /^\s*$/) { }
$line =~ /start:/i  && $line =~ /interval:/i
   || die("$self->{file} is not a mpstat file (1)\n");
$line =~ m!interval:\s+(\d+)!i;
$self->{interval} = $1;
$line =~ m!start:\s+(\d\d/\d\d/\d\d(?:\d\d)?)\s+(\d\d:\d\d:\d\d)!i;
my ($D, $M, $Y) = split(/\//, $1);
my ($h, $m, $s) = split(/:/, $2);
$M--;
if ($Y >= 100) { $Y -= 1900; }
elsif ($Y <= 50) { $Y += 100; }
$self->{start} = POSIX::mktime($s, $m, $h, $D, $M, $Y, 0, 0, -1)
               + $self->{interval};

# Look for the first header lines
while (defined ($line = $self->getline($mpstat))
       && $line !~ /^\s*CPU\s+minf\s+mjf\s+/i) { }
die("$self->{file} is not a mpstat file (2)\n") if (! $line);

# Register the column types
my (@colname, @coltype);
@colname = split(' ', $line);
shift(@colname);   # lose CPU column
my $cpu_end   = $#colname;
my $cpu_begin = $cpu_end - 3;
@coltype = (('N') x $cpu_begin, ("%") x 4);
$self->define_cols(\@colname, \@coltype);

# Skip the first data segment, which is the values since the last reboot
while (defined ($line = $self->getline($mpstat))
       && $line !~ /^CPU\s+minf\s+mjf/i) { }
die("$self->{file} is not a mpstat file (3)\n") if (! $line);

# Read the data
my $tstamp = $self->{start};
my $interval = $self->{interval};

if ($category eq "Average Values" || $category eq "Total Values")
   {
   my $want_avg = $category eq "Average Values" ? 1 : 0;
   while (defined($line))
      {
      # Read the data
      my $ncpu = 0;
      my @value = (0) x scalar(@colname);
      while (defined($line = $self->getline($mpstat))
             && $line !~ /^CPU\s+minf\smjf/i)
         {
         my (@v) = split(' ', $line);
         shift(@v);   # lose CPU number
         @value = map($_ += shift(@v), @value);
         $ncpu++;
         }
      if ($want_avg)
         { @value = map($_ /= $ncpu, @value); }
      else   # Always have to average the CPU averages anyway
         { @value[$cpu_begin .. $cpu_end] =
           map($_ /= $ncpu, @value[$cpu_begin .. $cpu_end]); }
      push(@{$self->{data}}, { tstamp => $tstamp, value => [ @value ] });
      $tstamp += $interval;
      }
   }

# Per CPU Values
else
   {
   while (defined($line))
      {
      # Read the data
      while (defined($line = $self->getline($mpstat))
             && $line !~ /^CPU\s+minf\smjf/i)
         {
         my (@value) = split(' ', $line);
         my $inst = "CPU " . shift(@value);
         $self->define_inst($inst);
         push(@{$self->{data}{$inst}}, { tstamp => $tstamp,
                                         value => [ @value ] });
         }
      $tstamp += $interval;
      }
   }

$self->{finish} = $tstamp - $interval;
$mpstat->close();
}

################################################################################

sub get_data_type($;$)
{
my ($self, $category) = @_;
return($category eq "Per CPU Values" ? "3d" : "2d");
}

################################################################################
1;
