################################################################################
# Monitor the Tablespace IO

use strict;
use StatsView::Oracle::Monitor;
package StatsView::Oracle::TablespaceIO;
@StatsView::Oracle::TablespaceIO::ISA = qw(StatsView::Oracle::Monitor);

################################################################################

sub new($$$$)
{
my ($class, $db, $fh, $rate) = @_;
$class = ref($class) || $class;
my $self = $class->SUPER::new($db, $fh, $rate);
my $query = q(select /*+ rule */ tablespace_name, sum(phyrds), sum(phywrts)
              from dba_data_files, v$filestat
              where dba_data_files.file_id = v$filestat.file#
              group by tablespace_name);
$self->{cursor} = $db->prepare($query);
$self->header("multirow", "Tablespace IO activity",
              "Reads/Sec,Writes/Sec", "NN");
$self->{cursor}->execute();
my ($df, $r, $w);
while (($df, $r, $w) = $self->{cursor}->fetchrow())
   {
   $self->{df}{$df} = [ $r, $w ];
   }
return($self);
}

##############################################################################

sub sample($$)
{
my ($self, $ts) = @_;
$self->{cursor}->execute();
my (@data, $df, $r, $w);
while (($df, $r, $w) = $self->{cursor}->fetchrow())
   {
   my $d_r = ($r - $self->{df}{$df}[0]) / $self->{rate};
   my $d_w = ($w - $self->{df}{$df}[1]) / $self->{rate};
   $self->{df}{$df} = [ $r, $w ];
   push(@data, "$df,$d_r,$d_w");
   }
$self->data($ts, @data);
}

################################################################################
1;
