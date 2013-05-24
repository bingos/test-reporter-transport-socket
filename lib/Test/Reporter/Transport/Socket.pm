package Test::Reporter::Transport::Socket;

# ABSTRACT: Simple socket transport for Test::Reporter

use strict;
use warnings;
use Carp ();
use IO::Socket::INET;
use Storable qw[nfreeze];
use base qw[Test::Reporter::Transport];

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

  if ( ref $args{host} eq 'ARRAY' and !scalar @{ $args{host} } ) {
    Carp::confess __PACKAGE__ . " requires 'host' argument to have elements if it is an arrayref\n";
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

  my $sock;

  foreach my $host ( ( ref $self->{host} eq 'ARRAY' ? @{ $self->{host} } : $self->{host} ) ) {
    $sock = IO::Socket::INET->new(
      PeerAddr => $host,
      PeerPort => $self->{port},
      Proto    => 'tcp'
    );
    last if $sock;
  }

  unless ( $sock ) {
    Carp::confess __PACKAGE__ . ": could not connect to '$self->{host}' '$!'\n";
  }

  # Get facts about Perl config that Test::Reporter doesn't capture
  # Unfortunately we can't do this from the current perl in case this
  # is a report regenerated from a file and isn't the perl that the report
  # was run on
  my $perlv = $report->{_perl_version}->{_myconfig};
  my $config = TRTS::Config::Perl::V::summary(TRTS::Config::Perl::V::plv2hash($perlv));
  my $perl_version = $report->{_perl_version}{_version} || $config->{version};

  my $data = {
    distfile      => $report->distfile,
    grade         => $report->grade,
    osname        => $config->{osname},
    osversion     => $report->{_perl_version}{_osvers},
    archname      => $report->{_perl_version}{_archname},
    perl_version  => $perl_version,
    textreport    => $report->report
  };

  my $froze;
  eval { $froze = nfreeze( $data ); };

  Carp::confess __PACKAGE__ . ": Could not freeze data '$@'\n"
    unless $froze;

  # Thanks to Tony Cook for this

  while ( length( $froze ) ) {
    my $sent = $sock->send( $froze ) or Carp::confess "Could not send data '$!'\n";
    substr( $froze, 0, $sent, '' );
  }

  close $sock;
  return 1;
}

package TRTS::Config::Perl::V;

use strict;
use warnings;

use Config;
use Exporter;
use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
@ISA         = ("Exporter");
@EXPORT_OK   = qw( plv2hash summary myconfig signature );
%EXPORT_TAGS = (
    all => [ @EXPORT_OK  ],
    sig => [ "signature" ],
    );

#  Characteristics of this binary (from libperl):
#    Compile-time options: DEBUGGING PERL_DONT_CREATE_GVSV PERL_MALLOC_WRAP
#                          USE_64_BIT_INT USE_LARGE_FILES USE_PERLIO

# The list are as the perl binary has stored it in PL_bincompat_options
#  search for it in
#   perl.c line 1669 S_Internals_V ()
#   perl.h line 4505 PL_bincompat_options
my %BTD = map { $_ => 0 } qw(

    DEBUGGING
    NO_MATHOMS
    NO_HASH_SEED
    NO_TAINT_SUPPORT
    PERL_DISABLE_PMC
    PERL_DONT_CREATE_GVSV
    PERL_EXTERNAL_GLOB
    PERL_HASH_FUNC_SIPHASH
    PERL_HASH_FUNC_SDBM
    PERL_HASH_FUNC_DJB2
    PERL_HASH_FUNC_SUPERFAST
    PERL_HASH_FUNC_MURMUR3
    PERL_HASH_FUNC_ONE_AT_A_TIME
    PERL_HASH_FUNC_ONE_AT_A_TIME_HARD
    PERL_HASH_FUNC_ONE_AT_A_TIME_OLD
    PERL_IS_MINIPERL
    PERL_MALLOC_WRAP
    PERL_MEM_LOG
    PERL_MEM_LOG_ENV
    PERL_MEM_LOG_ENV_FD
    PERL_MEM_LOG_NOIMPL
    PERL_MEM_LOG_STDERR
    PERL_MEM_LOG_TIMESTAMP
    PERL_NEW_COPY_ON_WRITE
    PERL_PERTURB_KEYS_DETERMINISTIC
    PERL_PERTURB_KEYS_DISABLED
    PERL_PERTURB_KEYS_RANDOM
    PERL_PRESERVE_IVUV
    PERL_RELOCATABLE_INCPUSH
    PERL_USE_DEVEL
    PERL_USE_SAFE_PUTENV
    UNLINK_ALL_VERSIONS
    USE_ATTRIBUTES_FOR_PERLIO
    USE_FAST_STDIO
    USE_HASH_SEED_EXPLICIT
    USE_LOCALE
    USE_LOCALE_CTYPE
    USE_PERL_ATOF
    USE_SITECUSTOMIZE

    DEBUG_LEAKING_SCALARS
    DEBUG_LEAKING_SCALARS_FORK_DUMP
    DECCRTL_SOCKETS
    FAKE_THREADS
    FCRYPT
    HAS_TIMES
    HAVE_INTERP_INTERN
    MULTIPLICITY
    MYMALLOC
    PERLIO_LAYERS
    PERL_DEBUG_READONLY_OPS
    PERL_GLOBAL_STRUCT
    PERL_IMPLICIT_CONTEXT
    PERL_IMPLICIT_SYS
    PERL_MAD
    PERL_MICRO
    PERL_NEED_APPCTX
    PERL_NEED_TIMESBASE
    PERL_OLD_COPY_ON_WRITE
    PERL_NEW_COPY_ON_WRITE
    PERL_POISON
    PERL_SAWAMPERSAND
    PERL_TRACK_MEMPOOL
    PERL_USES_PL_PIDSTATUS
    PL_OP_SLAB_ALLOC
    THREADS_HAVE_PIDS
    USE_64_BIT_ALL
    USE_64_BIT_INT
    USE_IEEE
    USE_ITHREADS
    USE_LARGE_FILES
    USE_LOCALE_COLLATE
    USE_LOCALE_NUMERIC
    USE_LONG_DOUBLE
    USE_PERLIO
    USE_REENTRANT_API
    USE_SFIO
    USE_SOCKS
    VMS_DO_SOCKETS
    VMS_SHORTEN_LONG_SYMBOLS
    VMS_SYMBOL_CASE_AS_IS
    );

# These are all the keys that are
# 1. Always present in %Config - lib/Config.pm #87 tie %Config
# 2. Reported by 'perl -V' (the rest)
my @config_vars = qw(

    api_subversion
    api_version
    api_versionstring
    archlibexp
    dont_use_nlink
    d_readlink
    d_symlink
    exe_ext
    inc_version_list
    ldlibpthname
    patchlevel
    path_sep
    perl_patchlevel
    privlibexp
    scriptdir
    sitearchexp
    sitelibexp
    subversion
    usevendorprefix
    version

    git_commit_id
    git_describe
    git_branch
    git_uncommitted_changes
    git_commit_id_title
    git_snapshot_date

    package revision version_patchlevel_string

    osname osvers archname
    myuname
    config_args
    hint useposix d_sigaction
    useithreads usemultiplicity
    useperlio d_sfio uselargefiles usesocks
    use64bitint use64bitall uselongdouble
    usemymalloc bincompat5005

    cc ccflags
    optimize
    cppflags
    ccversion gccversion gccosandvers
    intsize longsize ptrsize doublesize byteorder
    d_longlong longlongsize d_longdbl longdblsize
    ivtype ivsize nvtype nvsize lseektype lseeksize
    alignbytes prototype

    ld ldflags
    libpth
    libs
    perllibs
    libc so useshrplib libperl
    gnulibc_version

    dlsrc dlext d_dlsymun ccdlflags
    cccdlflags lddlflags
    );

my %empty_build = (
    osname  => "",
    stamp   => 0,
    options => { %BTD },
    patches => [],
    );

sub _make_derived
{
    my $conf = shift;

    for ( [ lseektype		=> "Off_t"	],
	  [ myuname		=> "uname"	],
	  [ perl_patchlevel	=> "patch"	],
	  ) {
	my ($official, $derived) = @$_;
	$conf->{config}{$derived}  ||= $conf->{config}{$official};
	$conf->{config}{$official} ||= $conf->{config}{$derived};
	$conf->{derived}{$derived} = delete $conf->{config}{$derived};
	}

    if (exists $conf->{config}{version_patchlevel_string} &&
       !exists $conf->{config}{api_version}) {
	my $vps = $conf->{config}{version_patchlevel_string};
	$vps =~ s{\b revision   \s+ (\S+) }{}x and
	    $conf->{config}{revision}        ||= $1;

	$vps =~ s{\b version    \s+ (\S+) }{}x and
	    $conf->{config}{api_version}     ||= $1;
	$vps =~ s{\b subversion \s+ (\S+) }{}x and
	    $conf->{config}{subversion}      ||= $1;
	$vps =~ s{\b patch      \s+ (\S+) }{}x and
	    $conf->{config}{perl_patchlevel} ||= $1;
	}

    ($conf->{config}{version_patchlevel_string} ||= join " ",
	map  { ($_, $conf->{config}{$_} ) }
	grep {      $conf->{config}{$_}   }
	qw( api_version subversion perl_patchlevel )) =~ s/\bperl_//; 

    $conf->{config}{perl_patchlevel}  ||= "";	# 0 is not a valid patchlevel

    if ($conf->{config}{perl_patchlevel} =~ m{^git\w*-([^-]+)}i) {
	$conf->{config}{git_branch}   ||= $1;
	$conf->{config}{git_describe} ||= $conf->{config}{perl_patchlevel};
	}

    $conf;
    } # _make_derived

sub plv2hash
{
    my %config;
    for (split m/\n+/ => join "\n", @_) {

	if (s/^Summary of my\s+(\S+)\s+\(\s*(.*?)\s*\)//) {
	    $config{"package"} = $1;
	    my $rev = $2;
	    $rev =~ s/^ revision \s+ (\S+) \s*//x and $config{revision} = $1;
	    $rev and $config{version_patchlevel_string} = $rev;
	    my ($rel) = $config{package} =~ m{perl(\d)};
	    my ($vers, $subvers) = $rev =~ m{version\s+(\d+)\s+subversion\s+(\d+)};
	    defined $vers && defined $subvers && defined $rel and
		$config{version} = "$rel.$vers.$subvers";
	    next;
	    }

	if (s/^\s+(Snapshot of:)\s+(\S+)//) {
	    $config{git_commit_id_title} = $1;
	    $config{git_commit_id}       = $2;
	    next;
	    }

	my %kv = m/\G,?\s*([^=]+)=('[^']+?'|\S+)/gc;

	while (my ($k, $v) = each %kv) {
	    $k =~ s/\s+$//;
	    $v =~ s/,$//;
	    $v =~ m/^'(.*)'$/ and $v = $1;
	    $v =~ s/^\s+//;
	    $v =~ s/\s+$//;
	    $config{$k} = $v;
	    }
	}
    my $build = { %empty_build };
    $build->{osname} = $config{osname};
    return _make_derived ({
	build		=> $build,
	environment	=> {},
	config		=> \%config,
	derived		=> {},
	inc		=> [],
	});
    } # plv2hash

sub summary
{
    my $conf = shift || myconfig ();
    ref $conf eq "HASH" &&
	exists $conf->{config} && exists $conf->{build} or return;

    my %info = map {
	exists $conf->{config}{$_} ? ( $_ => $conf->{config}{$_} ) : () }
	qw( archname osname osvers revision patchlevel subversion version
	    cc ccversion gccversion config_args inc_version_list
	    d_longdbl d_longlong use64bitall use64bitint useithreads
	    uselongdouble usemultiplicity usemymalloc useperlio useshrplib 
	    doublesize intsize ivsize nvsize longdblsize longlongsize lseeksize
	    );
    $info{$_}++ for grep { $conf->{build}{options}{$_} } keys %{$conf->{build}{options}};

    return \%info;
    } # summary

sub signature
{
    eval { require Digest::MD5 };
    $@ and return "00000000000000000000000000000000";

    my $conf = shift || summary ();
    delete $conf->{config_args};
    return Digest::MD5::md5_hex (join "\xFF" => map {
	"$_=".(defined $conf->{$_} ? $conf->{$_} : "\xFE");
	} sort keys %$conf);
    } # signature

sub myconfig
{
    my $args = shift;
    my %args = ref $args eq "HASH"  ? %$args :
               ref $args eq "ARRAY" ? @$args : ();

    my $build = { %empty_build };

    # 5.14.0 and later provide all the information without shelling out
    my $stamp = eval { Config::compile_date () };
    if (defined $stamp) {
	$stamp =~ s/^Compiled at //;
	$build->{osname}      = $^O;
	$build->{stamp}       = $stamp;
	$build->{patches}     =     [ Config::local_patches () ];
	$build->{options}{$_} = 1 for Config::bincompat_options (),
				      Config::non_bincompat_options ();
	}
    else {
	#y $pv = qx[$^X -e"sub Config::myconfig{};" -V];
	my $pv = qx[$^X -V];
	   $pv =~ s{.*?\n\n}{}s;
	   $pv =~ s{\n(?:  \s+|\t\s*)}{\0}g;

	# print STDERR $pv;

	$pv =~ m{^\s+Built under\s+(.*)}m
	    and $build->{osname}  = $1;
	$pv =~ m{^\s+Compiled at\s+(.*)}m
	    and $build->{stamp}   = $1;
	$pv =~ m{^\s+Locally applied patches:(?:\s+|\0)(.*)}m
	    and $build->{patches} = [ split m/\0+/, $1 ];
	$pv =~ m{^\s+Compile-time options:(?:\s+|\0)(.*)}m
	    and map { $build->{options}{$_} = 1 } split m/\s+|\0/ => $1;
	}

    my @KEYS = keys %ENV;
    my %env  =
	map {      $_ => $ENV{$_} } grep m/^PERL/      => @KEYS;
    $args{env} and
	map { $env{$_} = $ENV{$_} } grep m{$args{env}} => @KEYS;

    my %config = map { $_ => $Config{$_} } @config_vars;

    return _make_derived ({
	build		=> $build,
	environment	=> \%env,
	config		=> \%config,
	derived		=> {},
	inc		=> \@INC,
	});
    } # myconfig

1;

=pod

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

This may also be an arrayref of the above. A connection will be attempted to each
item in turn until a successful connection is made.

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

  This module inlines Config::Perl::V Copyright (C) 2009-2010 H.Merijn Brand

=cut
