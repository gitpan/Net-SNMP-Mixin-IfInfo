package Net::SNMP::Mixin::IfInfo;

use strict;
use warnings;

#
# store this package name in a handy variable,
# used for unambiguous prefix of mixin attributes
# storage in object hash
#
my $prefix = __PACKAGE__;

#
# this module import config
#
use Carp ();
use Net::SNMP::Mixin::Util qw/idx2val/;

#
# this module export config
#
my @mixin_methods;

BEGIN {
  @mixin_methods = ( qw/ get_if_entries /);
}

use Sub::Exporter -setup => {
  exports   => [@mixin_methods],
  groups    => { default => [@mixin_methods], },
};

#
# SNMP oid constants used in this module
#
use constant {
  IF_DESCR                    => '1.3.6.1.2.1.2.2.1.2',
  IF_TYPE                     => '1.3.6.1.2.1.2.2.1.3',
  IF_ADMIN_STATUS             => '1.3.6.1.2.1.2.2.1.7',
  IF_OPER_STATUS              => '1.3.6.1.2.1.2.2.1.8',
  IF_X_NAME                   => '1.3.6.1.2.1.31.1.1.1.1',
  IF_X_ALIAS                  => '1.3.6.1.2.1.31.1.1.1.18',
};

=head1 NAME

Net::SNMP::Mixin::IfInfo - mixin class for interface related infos

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

  use Net::SNMP;
  use Net::SNMP::Mixin qw/mixer init_mixins/;

  my $session = Net::SNMP->session( -hostname => 'foo.bar.com' );

  $session->mixer('Net::SNMP::Mixin::IfInfo');
  $session->init_mixins;
  snmp_dispatcher()   if $session->nonblocking;
  die $session->error if $session->error;

  my $if_entries = $session->get_if_entries;
  foreach my $if_index ( sort { $a <=> $b } keys %$if_entries ) {
    my $ifAdminStatus = $if_entries->{$if_index}->{ifAdminStatus} || 0;
    my $ifOperStatus  = $if_entries->{$if_index}->{ifOperStatus}  || 0;
    my $ifType        = $if_entries->{$if_index}->{ifType}        || 0;
    my $ifName        = $if_entries->{$if_index}->{ifName}        || '';
    my $ifDescr       = $if_entries->{$if_index}->{ifDescr}       || '';
    my $ifAlias       = $if_entries->{$if_index}->{ifAlias}       || '';

    printf "%5d  %1d/%1d  %-10.10s %-25.25s %-26.26s\n",
      $if_index, $ifAdminStatus, $ifOperStatus,
      $ifName,   $ifDescr,       $ifAlias;
  }

=head1 DESCRIPTION

A mixin class for basic interface related infos from the ifTable and ifXTable.

This mixin supports the quasi static information from both tables together in one hash, see below. 

=head1 MIXIN METHODS

=head2 B<< OBJ->get_if_entries >>

Returns parts ot the ifTable and ifXTable as a hash reference. The key is the common ifIndex into the ifTable and ifXtable:

  {
    INTEGER => {    # ifIndex as key

      ifName        => DisplayString,    # an ifXTable entry
      ifAlias       => DisplayString,    # an ifXTable entry

      ifDescr       => DisplayString,    # an ifTable entry
      ifType        => IANAifType,       # an ifTable entry
      ifAdminStatus => INTEGER,          # an ifTable entry
      ifOperStatus  => INTEGER,          # an ifTable entry
    }
  }

=cut

sub get_if_entries {
  my $session = shift;
  Carp::croak "'$prefix' not initialized,"
    unless $session->{$prefix}{__initialized};

  # stash for return values
  my $if_entries = {};

  # get the ifIndexes
  my @ifIndexes = keys %{ $session->{$prefix}{ifDescr} };

  foreach my $ifIndex ( @ifIndexes ) {
    my $row = {};

    $row->{ifDescr} =
      $session->{$prefix}{ifDescr}{$ifIndex};

    $row->{ifType} =
      $session->{$prefix}{ifType}{$ifIndex};

    $row->{ifAdminStatus} =
      $session->{$prefix}{ifAdminStatus}{$ifIndex};

    $row->{ifOperStatus} =
      $session->{$prefix}{ifOperStatus}{$ifIndex};

    $row->{ifName} =
      $session->{$prefix}{ifName}{$ifIndex};

    $row->{ifAlias} =
      $session->{$prefix}{ifAlias}{$ifIndex};

    $if_entries->{$ifIndex} = $row;
  }

  return $if_entries;
}

=head1 INITIALIZATION

=head2 B<< OBJ->_init($reload) >>

Fetch basic interface related snmp values from the host. Don't call this method direct!

=cut

sub _init {
  my ($session, $reload) = @_;

  die "$prefix already initalized and reload not forced.\n"
    if $session->{$prefix}{__initialized} && not $reload;

  # populate the object with needed mib values
  #
  # map between ifIndexes -> ifDescr, ...
  _fetch_if_entries($session);
  return if $session->error;

  return 1;
}

=head1 PRIVATE METHODS

Only for developers or maintainers.

=head2 B<< _fetch_if_entries($session) >>

Get some MIB values from the ifTable and ifXTable needed by all
other modules.

=cut

sub _fetch_if_entries {
  my $session = shift;
  my $result;

  # fetch all some entries from ifTable and ifXTable
  $result = $session->get_entries(
    -columns => [
      IF_DESCR,  IF_TYPE, IF_ADMIN_STATUS, IF_OPER_STATUS,
      IF_X_NAME, IF_X_ALIAS,
    ],

    # define callback if in nonblocking mode
    $session->nonblocking ? ( -callback => \&_if_entries_cb ) : (),
  );

  return unless defined $result;
  return 1 if $session->nonblocking;

  # call the callback funktion in blocking mode by hand
  _if_entries_cb($session);

}

=head2 B<< _if_entries_cb($session) >>

The callback for _fetch_if_entries

=cut

sub _if_entries_cb {
  my $session = shift;
  my $vbl     = $session->var_bind_list;

  return unless defined $vbl;

  # mangle result table to get plain idx->value
  $session->{$prefix}{ifDescr}       = idx2val( $vbl, IF_DESCR );
  $session->{$prefix}{ifType}        = idx2val( $vbl, IF_TYPE );
  $session->{$prefix}{ifAdminStatus} = idx2val( $vbl, IF_ADMIN_STATUS );
  $session->{$prefix}{ifOperStatus}  = idx2val( $vbl, IF_OPER_STATUS );
  $session->{$prefix}{ifName}        = idx2val( $vbl, IF_X_NAME );
  $session->{$prefix}{ifAlias}       = idx2val( $vbl, IF_X_ALIAS );

  $session->{$prefix}{__initialized}++;
}

=head1 SEE ALSO

L<< Net::SNMP::Mixin::Dot1dBase >> for a mapping between ifIndexes and dot1dBasePorts.

=head1 REQUIREMENTS

L<< Net::SNMP >>, L<< Net::SNMP::Mixin >>

=head1 BUGS, PATCHES & FIXES

There are no known bugs at the time of this release. However, if you spot a bug or are experiencing difficulties that are not explained within the POD documentation, please submit a bug to the RT system (see link below). However, it would help greatly if you are able to pinpoint problems or even supply a patch. 

Fixes are dependant upon their severity and my availablity. Should a fix not be forthcoming, please feel free to (politely) remind me by sending an email to gaissmai@cpan.org .

  RT: http://rt.cpan.org/Public/Dist/Display.html?Name=Net-SNMP-Mixin-IfInfo

=head1 AUTHOR

Karl Gaissmaier <karl.gaissmaier at uni-ulm.de>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Karl Gaissmaier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

unless ( caller() ) {
  print __PACKAGE__ . " compiles and initializes successful.\n";
}

1;

# vim: sw=2
