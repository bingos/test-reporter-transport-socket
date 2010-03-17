package Test::Reporter::Transport::Socket;

use strict;
use warnings;
use Carp ();
use Config::Perl::V ();
use IO::Socket::INET;
use Storable qw[nfreeze];
use base qw[Test::Reporter::Transport];
use vars qw[$VERSION];

$VERSION ='0.04';

my @required_args = qw/host port/;

sub new {
  my $class = shift;
  Carp::confess __PACKAGE__ . " requires transport args in key/value pairs\n"
    if @_ % 2;
  my %args = @_;
  $args{lc $_} = delete $args{$_} for keys %args;
 
  for my $k ( @required_args ) {
    Carp::confess __PACKAGE__ . " requires $k argument\n"
      unless exists $args{$k};
  }

  return bless \%args => $class;
}

sub send {
  my ($self, $report) = @_;

  unless ( eval { $report->distfile } ) {
    Carp::confess __PACKAGE__ . ": requires the 'distfile' parameter to be set\n"
      . "Please update your CPAN testing software to a version that provides \n"
      . "this information to Test::Reporter.  Report will not be sent.\n";
  }

  # Open the socket to the given host:port
  # confess on failure.

  my $sock = IO::Socket::INET->new(
    PeerAddr => $self->{host},
    PeerPort => $self->{port},
    Proto    => 'tcp'
  );

  unless ( $sock ) {
    Carp::confess __PACKAGE__ . ": could not connect to '$self->{host}' '$!'\n";
  }

  # Get facts about Perl config that Test::Reporter doesn't capture
  # Unfortunately we can't do this from the current perl in case this
  # is a report regenerated from a file and isn't the perl that the report
  # was run on
  my $perlv = $report->{_perl_version}->{_myconfig};
  my $config = Config::Perl::V::summary(Config::Perl::V::plv2hash($perlv));

  my $data = {
    distfile      => $report->distfile,
    grade         => $report->grade,
    osname        => $config->{osname},
    osversion     => $report->{_perl_version}{_osvers},
    archname      => $report->{_perl_version}{_archname},
    perl_version  => $config->{version},
    textreport    => $report->report
  };

  my $froze;
  eval { $froze = nfreeze( $data ); };

  Carp::confess __PACKAGE__ . ": Could not freeze data '$@'\n"
    unless $froze;

  my $foo = $sock->send( $froze );
  
  close $sock;
  return 1;
}

1;

__END__

=head1 NAME

Test::Reporter::Transport::Socket - Simple socket transport for Test::Reporter

=head1 SYNOPSIS

    my $report = Test::Reporter->new(
        transport => 'Socket',
        transport_args => [
          host     => 'metabase.relay.example.com',
          port     => 58008,
        ],
    );

    # use space-separated in a CPAN::Reporter config.ini
    transport = Socket host metabase.relay.example.com ...

=head1 DESCRIPTION

This is a L<Test::Reporter::Transport> that sends test report data serialised
over a TCP socket.

The idea is to keep dependencies in the tester perl to a bear minimum and offload
the bulk of submission to a Metabase instance to a relay.

=head1 USAGE

See L<Test::Reporter> and L<Test::Reporter::Transport> for general usage
information.

=head2 Transport arguments

Unlike most other Transport classes, this class requires transport arguments
to be provided as key-value pairs:

    my $report = Test::Reporter->new(
        transport => 'Socket',
        transport_args => [
          host     => 'metabase.relay.example.com',
          port     => 58008,
        ],
    );

Arguments include:

=over

=item C<host> (required)

The name or IP address of a host where we want to send our serialised data.

=item C<port>

The TCP port on the above C<host> to send our serialised data.

=back

=head1 METHODS

These methods are only for internal use by Test::Reporter.

=head2 new

    my $sender = Test::Reporter::Transport::Socket->new( %params );

The C<new> method is the object constructor.

=head2 send

    $sender->send( $report );

The C<send> method transmits the report.

=head1 AUTHORS

  David A. Golden (DAGOLDEN)
  Richard Dawe (RICHDAWE)
  Chris Williams (BINGOS)

=head1 COPYRIGHT AND LICENSE

  Portions Copyright (c) 2009 by Richard Dawe
  Portions Copyright (c) 2009-2010 by David A. Golden
  Portions Copyright (c) 2010 by Chris Williams

Licensed under the same terms as Perl itself (the "License").
You may not use this file except in compliance with the License.
A copy of the License was distributed with this file or you may obtain a
copy of the License from http://dev.perl.org/licenses/

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut
