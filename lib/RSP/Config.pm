package RSP::Config;

use Moose;
use namespace::autoclean;
use RSP;
use Cwd qw(getcwd);

use Scalar::Util qw(weaken);
use Try::Tiny;
use Moose::Util::TypeConstraints;
use Set::Object;

BEGIN {
    subtype 'ExistantDirectory',
        as 'Str',
        where { -d $_ },
        message { "Directory '$_' does not exist." };
}
use RSP::Config::Host;

has _config => (is => 'ro', lazy_build => 1, isa => 'HashRef', init_arg => 'config');
sub _build__config {
    return RSP->config;
}

has root => (is => 'ro', lazy_build => 1, isa => 'ExistantDirectory');
sub _build_root {
    my ($self) = @_;
    my $root = $self->_config->{_}{root} // getcwd();
    $root or die "Root not supplied and unable to work out current working directory";
    return $root;
}

has extensions => (is => 'ro', lazy_build => 1, isa => 'ArrayRef[ClassName]');
sub _build_extensions {
    my ($self) = @_;
    my $extensions_string = $self->_config->{_}{extensions} // '';
    my @extensions = map {
            'RSP::Extension::' .  $_;
        } split(/,/, $extensions_string);

    my $available_set = Set::Object->new(@{ $self->available_extensions });
    for my $class (@extensions){
        if(!$available_set->contains($class)){
            die "Could not load extension '$class', was not supplied in available extensions list";
        }
    }

    return [@extensions];
}

has available_extensions => (is => 'ro', lazy_build => 1, isa => 'ArrayRef[ClassName]');
sub _build_available_extensions {
    my ($self) = @_;
    my $extensions_string = $self->_config->{_}{available_extensions} // '';
    my @extensions = map {
            'RSP::Extension::' .  $_;
        } split(/,/, $extensions_string);

    for my $class (@extensions){
        eval { Class::MOP::load_class($class) };
        die "Could not load extension '$class': $@" if $@;
    }

    return [@extensions];
}

has host_class => (is => 'ro', isa => 'ClassName', lazy_build => 1);
sub _build_host_class {
    my ($self) = @_;
    my $host_class = $self->_config->{_}{host_class} ? $self->_config->{_}{host_class} : 'RSP::Config::Host';
    Class::MOP::load_class($host_class);
    return $host_class;
}

has _hosts => (is => 'ro', lazy_build => 1, isa => 'HashRef');
sub _build__hosts {
    my ($self) = @_;
    
    my $hosts = {};
    my $config = $self->_config;

    for my $host (map { $_=~ /^host:(.+?)$/ ? $1 : () } keys %{$config}){
        $hosts->{$host} = $self->_build_host_obj($host => $config->{"host:$host"});
    }

    return $hosts;
}

sub _build_host_obj {
    my ($self, $host, $conf) = @_;
    
    my $host_conf =  RSP::Config::Host->new({ config => $conf, global_config => $self, hostname => $host });
    
    if((my $engine = $host_conf->js_engine) ne 'none'){
        
        my $class = "RSP::JS::Engine::$engine";
        try {
            Class::MOP::load_class($class);
        } catch {
            die "Could not load class '$class' for JS Engine '$engine': $_";
        };
       
        my @roles = $class->applicable_host_config_roles;
        use Moose::Util;
        Moose::Util::apply_all_roles($host_conf, @roles) if scalar(@roles);
    }

    $host_conf->meta->make_immutable;
    return $host_conf;
}

sub host {
    my ($self, $host) = @_;

    my $conf = $self->_hosts->{$host};
    if(!$conf){
        # If we don't have a config supplied from the config file, we'll use defaults
        $conf = $self->_build_host_obj($host => {});
        $self->_hosts->{$host} = $conf;
    }

    return $conf;
}

# XXX - this should probably use default_oplimit in the config file, keeping it as oplimit for back-compat
has oplimit => (is => 'ro', isa => 'Int', lazy_build => 1);
sub _build_oplimit {
    my ($self) = @_;
    return $self->_config->{rsp}{oplimit} ? $self->_config->{rsp}{oplimit} : 100_000; 
}

has hostroot => (is => 'ro', lazy_build => 1, isa => 'ExistantDirectory');
sub _build_hostroot {
    my ($self) = @_;
    my $root = $self->_config->{rsp}{hostroot};

    # handle the scenario where the user uses a path relative to the RSP root
    if ( substr( $root, 0, 1 ) eq '/' ) {
        return $root;
    } else {
        $root = File::Spec->catfile( $self->root, $root);
    }
    return $root;
}

has log_dispatcher => (is => 'rw', lazy_build => 1, isa => 'Log::Dispatch', 
    handles => [qw(log debug info notice warning error critical alert emergency)]);
sub _build_log_dispatcher {
    my ($self) = @_;
    my $path = File::Spec->catfile($self->root, $self->_config->{rsp}{logging_config});
    if(!-e $path){
        die "Cannot locate logging config file: $!";
    }

    use Log::Dispatch::Config;
    Log::Dispatch::Config->configure($path);
    return Log::Dispatch::Config->instance;
}

1;

__END__

=head1 NAME 

RSP::Config - Base configuration for RSP

=head1 SYNOPSIS

  use RSP::Config;
  my $conf = RSP::Config->new();

  -- or --

  my $conf = RSP::Config->new(config => { ... });

=head1 DESCRIPTION

This module provides an object encapsulation around the 'rsp.conf' to provide
a sanitized wrapper for use by RSP. For example, the 'root' path if incorrect
will throw an exception if the path doesn't exist.

=head1 CONFIGURATION

  # contents of rsp.conf
  root=/Users/scott/devel/joyent/rsp
  extensions=Console,DataStore,FileSystem,HTTP,Image,Import,JSONEncoder

  [rsp]
  hostroot=application_repos
  oplimit=100000

=head1 OPTIONS

=head2 root

This is the path in which the RSP application runs. If not supplied, it will
default to the current working directory.

=head2 extensions

This is a comma seperated list of extensions to load into the RSP application.

=head2 [rsp] -> hostroot

This is the path used to look for directories containing a javascript
application. The path can either be an absolute path, or relative under
the application root.

=head2 [rsp] -> oplimit

This is the default number of Javascript engine operations to be allowed
by only one execution. If not supplied RSP uses a defalt of 100,000

=head1 METHODS

=head2 root

  my $path = $conf->root;

Returns an absolute path. Throws and exception if the path does not exist.

=head2 extensions

  my $extensions = $conf->extensions;
  print join ', ', @$extensions;

Returns an arrayref of full class names for listed extensions. It will also load
those classes if not already loaded.

=head2 hostroot

  my $hosts_path = $conf->hostroot;

Returns and absolute path to listed hostroot. Throws and exception if the
path does not exist.

=head2 oplimit

  my $limit = $conf->oplimit;

Returns the configured oplimit as an integer.

=head1 AUTHOR

Scott McWhirter, C<<scott DOT mcwhirter -at- joyent DOT com>>

=head1 COPYRIGHT

Copyright (c) 2009, Joyent Inc.

=head1 LICENCE

Please refer to the LICENCE file in this distribution for details.

=cut

