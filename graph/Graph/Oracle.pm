################################################################################

use strict;
use Time::Local;
use StatsView::Graph;
package StatsView::Graph::Oracle;
@StatsView::Graph::Oracle::ISA = qw(StatsView::Graph);
   
################################################################################

sub new()
{
my ($class, $file) = @_;
$class = ref($class) || $class;
my $self = $class->SUPER::init($file);

# Figure out what type of file we have
my $oracle = IO::File->new($file, "r") || die("Can't open $file: $!\n");
my $line;

# Look for the header line
while (defined($line = $oracle->getline()) && $line =~ /^\s*$/) { }
$line =~ /Oracle Statistics File/
   || die("$self->{file} is not a Oracle Statistics file (1)\n");

# Read in all the categories
my $title;
while (defined($line = $oracle->getline()) && $line !~ /^\s*Data\s*$/)
   {
   if ($line =~ /^Title:\s*(.*)/)
      {
      $title = $1;
      $line = $oracle->getline();
      my ($tag, $type) = $line =~ /Statistics:\s*(\w+)\s+(\w+)/;
      $type = ($type eq 'singlerow') ? '2d' : '3d';
      $self->{info}->{$title} = { tag => $tag, type => $type};
      push(@{$self->{category}}, $title)
      }
   }
$oracle->close();
return($self);
}

################################################################################

sub read($$)
{
my ($self, $category) = @_;
$self->SUPER::read($category);

# Open the file
my $oracle = IO::File->new($self->{file}, "r")
   || die("Can't open $self->{file}: $!\n");
$self->{title} = "Oracle Statistics";
my $line;

while (defined($line = $oracle->getline()) && $line =~ /^\s*$/) { }
$line =~ /Oracle Statistics File created on (\d\d\/\d\d\/\d\d(?:\d\d)?)/
   || die("$self->{file} is not a Oracle Statistics file (2)\n");
$self->{date} = $1;

# Look for the header for the category
my ($tag, $type) = @{$self->{info}->{$category}}{qw(tag type)};
my ($headings, $formats);
while (defined($line = $oracle->getline()) && $line !~ /^\s*Data\s*$/)
   {
   if ($line =~ /Title:\s*$category/)
      {
      $line = $oracle->getline();   # Skip Statistics: line
      $line = $oracle->getline();
      ($headings) = $line =~ /Headings:\s*(.*)/;
      $line = $oracle->getline();
      ($formats) = $line =~ /Formats:\s*(.*)/;
      }
   }

# Define the column types - N = numeric, % = percentage
my @colname = split(',', $headings);
my @coltype = split('', $formats);
$self->define_cols(\@colname, \@coltype);
$self->{title} = $category;

# Read in the data values
while (defined($line = $oracle->getline()))
   {
   chomp($line);
   if ($line =~ /^$tag\s+(.*)/)
      {
      my $tstamp = $1;
      push(@{$self->{tstamps}}, $tstamp);
      if ($type eq '2d')
         {
         $line = $oracle->getline(); chomp($line);
         my @value = split(',', $line);
         push(@{$self->{data}}, { tstamp => $tstamp, value => [ @value ] });
         }
      else
         {
         while (defined($line = $oracle->getline()) && $line !~ /^\s*$/)
            {
            chomp($line);
            my ($inst, @value) = split(',', $line);
            push(@{$self->{data}{$inst}},
                 { tstamp => $tstamp, value => [ @value ] });
            $self->{instance}{$inst} = $self->{index_3d}++
               if (! exists($self->{instance}->{$inst}));
            }
         }
      }
   }

$oracle->close();
}

################################################################################

sub get_data_type($;$)
{
my($self, $category) = @_;
return($self->{info}->{$category}->{type});
}

################################################################################
1;
