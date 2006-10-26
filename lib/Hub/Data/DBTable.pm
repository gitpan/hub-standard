package Hub::Data::DBTable;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub qw(:lib);
use DBI;

our $VERSION        = '3.01048';
our @EXPORT     = qw//;
our @EXPORT_OK  = qw//;

# ------------------------------------------------------------------------------
# new - Constructor.
# new LIST
#
# Parameters are passed to the standard initialization method L<refresh>.
# ------------------------------------------------------------------------------

sub new {
    my $self = shift;
    my $class = ref( $self ) || $self;
    my $obj = bless {}, $self;
    $obj->refresh( @_ );
    return $obj;
}#new

# ------------------------------------------------------------------------------
# refresh - Return instance to initial state.
# refresh LIST
#
# Called implictly by L<new>, and when persistent interpreters (such as
# mod_perl) would have called L<new>.
# ------------------------------------------------------------------------------

sub refresh {
    my ($self,$opts) = Hub::objopts( \@_ );
    $$self{'tname'} ||= shift;
    $$self{'struct'} = Hub::mkinst( 'HashFile', Hub::spath( 'db-struct.hf' ) );
    $$self{'keys'} = $$self{'struct'}->getv($$self{'tname'});
    $$self{'cmds'} = Hub::mkinst( 'HashFile', Hub::spath( 'db-commands.hf' ) );
    unless( $$self{'dbh'} ) {
        eval {
            $$self{'dbh'} = DBI->connect(
                $$Hub{'/sys/dbi/connect/dsn'},
                $$Hub{'/sys/dbi/connect/user'},
                $$Hub{'/sys/dbi/connect/clave'}, { RaiseError => 1, AutoCommit => 0 } );
        };
        if( $@ ) {
            undef $$self{'dbh'};
            Hub::lerr( "Cannot connect to database" );
        }#if
    }#unless
}#refresh

# ------------------------------------------------------------------------------
# select - Select records from the table
# select [options]
# select query
#
# OPTIONS
#
#   -cmd        The command (which is read from db-commands.hf)
#   -data       The data used to populate the query
#
# Using the -cmd option allows you to store your SQL queries in the external
# file "db-commands.hf" rather than passing in the query.
# ------------------------------------------------------------------------------

sub select {
    my ($self,$opts) = Hub::objopts( \@_ );
    my $data = $$opts{'data'} || {};
    my $query = $$opts{'cmd'} ?  $$self{'cmds'}->getv($$opts{'cmd'}) : shift;
    my $rows = ();
    eval {
        $rows = $$self{'dbh'}->selectall_arrayref( Hub::populate( $query, $data ) );
    };
    if( $@ ) {
        Hub::lerr( $@ );
    }
    return $rows;
}#select

# ------------------------------------------------------------------------------
# insert - Insert a record
# insert -data => \%hash, [options]
#
# options:
#   -nonull Convert undefined (NULL) values to ''
#   -forcenull  Convert empty ('') values to undefined (NULL)
#
# Where the keys of the data hash match the column names.
# ------------------------------------------------------------------------------
sub insert {
    my ($self,$opts) = Hub::objopts( \@_ );
    my $result = 0;
    my $data = $$opts{'data'} || {};
    if( $$opts{'nonull'} ) {
        Hub::lmsg( "Converting undefined (null) values to empty strings", "sql" );
        map { $$data{$_} = '' unless defined $$data{$_} } @{$$self{'keys'}};
    } elsif( $$opts{'forcenull'} ) {
        Hub::lmsg( "Converting empty (or zero) values to undefined", "sql" );
        map { undef $$data{$_} unless $$data{$_} } @{$$self{'keys'}};
    }
    $$self{'sth'} = $$self{'dbh'}->prepare( 'INSERT INTO ' . $$self{'tname'} . ' (' .
        join( ',', @{$$self{'keys'}} ) . ') VALUES (' . join(',', map { "?" } @{$$self{'keys'}}) . ')' );
    if( $$self{'dbh'}->errstr() ) {
        Hub::lerr( $$self{'dbh'}->errstr() );
        $$self{'last_err'} = $$self{'dbh'}->errstr();
    } else {
        Hub::ldmp( "Insert data:", $data, "-level=sql" );
        eval {
            $$self{'sth'}->execute( @$data{@{$$self{'keys'}}} );
        };
        if( $@ ) {
            $$self{'last_err'} = $@;
            Hub::lerr( $@ );
            $$self{'dbh'}->rollback();
        } else {
            $$self{'dbh'}->commit();
            $result = 1;
        }
    }
    return $result;
}#insert

# ------------------------------------------------------------------------------
# do - Execute an SQL query
# do [options]
# do query
#
# Uses the same -cmd and -data processing as L<select>
# ------------------------------------------------------------------------------

sub do {
    my ($self,$opts) = Hub::objopts( \@_ );
    my $data = $$opts{'data'} || {};
    my $query = $$opts{'cmd'} ?  $$self{'cmds'}->getv($$opts{'cmd'}) : shift;
    my $result = ();
    eval {
        $result = $$self{'dbh'}->do( Hub::populate( $query, $data ) );
    };
    if( $@ ) {
        $$self{'last_err'} = $@;
        $$self{'dbh'}->rollback();
    } else {
        $$self{'dbh'}->commit();
    }
    return $result;
}#do

# ------------------------------------------------------------------------------
# select_all - Select all columns from a table
# select_all -by => \@columns, -using => \%column_to_value_hash
# select_all [options]
#
# In the first form:
#
#   -by => [ "pkey" ], -using => { pkey => 1001 }
#
# Will build the where clause by extracing the key/val from "-using" for each
# column name in "-by".
#
# Or, each option is a WHERE condition.  For instance, the option:
#
#   -pkey => 1001
#
# Would add "WHERE pkey = '1001'" to the select query.
# ------------------------------------------------------------------------------

sub select_all {
    my ($self,$opts) = Hub::objopts( \@_ );
    my $query = "SELECT * FROM $$self{'tname'}";
    my $where = {};
    if( $$opts{'by'} ) {
        foreach my $col_name ( @{$$opts{'by'}} ) {
            $where->{$col_name} = $$opts{'using'}{$col_name};
        }
    } elsif( %$opts ) {
        $where = $opts;
    }
    if( %$where ) {
        $query .= " WHERE";
        foreach my $col_name ( keys %$where ) {
            substr( $query, -5 ) ne 'WHERE' and $query .= " AND";
            $query .= " $col_name = '" . $$where{$col_name} . "'";
        }
    }
    Hub::lmsg( "select_all query: $query", 'sql' );
    my $r_rows = [];
    my $rows = $$self{'dbh'}->selectall_arrayref( $query );
    if( defined $rows && @$rows ) {
        my $r_row = {};
        foreach my $row ( @$rows ) {
            for my $idx ( 0 .. $#{$$self{'keys'}} ) {
                $$r_row{ $self->{'keys'}[$idx] } = $$row[$idx];
            }
        }
        push @$r_rows, $r_row;
    }
    return $r_rows;
}#select_all

# ------------------------------------------------------------------------------
# update - Update an existion record
#
# update -by => \@names, -set => \@names, -using => \%data, [options]
#
# where:
#   -by     Column names for the WHERE clause
#   -set    Column names for the SET clause (otherwise all columns)
#   -using  Data for -by and -set clauses
# options:
#   -nonull     Convert undefined (NULL) values to ''
#   -forcenull  Convert empty ('') values to undefined (NULL)
# ------------------------------------------------------------------------------

sub update {
    my ($self,$opts) = Hub::objopts( \@_ );
    my $result = 0;
    my $query = "UPDATE $$self{'tname'}";
    my $where = {};
    my @cols = ();
    if( $$opts{'by'} ) {
        foreach my $col_name ( @{$$opts{'by'}} ) {
            $where->{$col_name} = $$opts{'using'}{$col_name};
        }
    }
    $$opts{'set'} ||= [ keys %{$$opts{'using'}} ];
    if( @{$$opts{'set'}} ) {
        $query .= " SET";
        foreach my $col_name ( @{$$opts{'set'}} ) {
            unless( grep /\A$col_name\Z/, keys %$where ) {
                substr( $query, -3 ) ne 'SET' and $query .= ", ";
                if( $$opts{'bind'} ) {
                    $query .= " $col_name = ?";
                } else {
                    $query .= " $col_name = '" . _esc($$opts{'using'}{$col_name}) . "'";
                }
                push @cols, $col_name;
            }
        }
    }
    if( %$where ) {
        $query .= " WHERE";
        foreach my $col_name ( keys %$where ) {
            substr( $query, -5 ) ne 'WHERE' and $query .= " AND";
            $query .= " $col_name = '" . $$where{$col_name} . "'";
        }
    }
    my $data = $$opts{'using'} || {};
    Hub::lmsg( "update query: $query", 'sql' );
    Hub::lmsg( "      values: " . join(',',@$data{@cols}), 'sql' )
        if $$opts{'bind'};
    $$self{'sth'} = $$self{'dbh'}->prepare( $query );
    eval {
        my $data = $$opts{'data'} || {};
        if( $$opts{'nonull'} ) {
            Hub::lmsg( "Converting undefined (null) values to empty strings", "sql" );
            map { $$data{$_} = '' unless defined $$data{$_} } @cols;
        } elsif( $$opts{'forcenull'} ) {
            Hub::lmsg( "Converting empty (or zero) values to undefined", "sql" );
            map { undef $$data{$_} unless $$data{$_} } @cols;
        }
        if( $$opts{'bind'} ) {
            $$self{'sth'}->execute( @$data{@cols} );
        } else {
            $$self{'sth'}->execute();
        }#if
    };
    if( $@ ) {
        $$self{'last_err'} = $@;
        Hub::lerr( $@ );
        $$self{'dbh'}->rollback();
    } else {
        $$self{'dbh'}->commit();
        $result = 1;
    }
    return $result;
}#update

sub _esc {
    $_[0] =~ s/([\W])/\\$1/g;
    return $_[0];
}

# ------------------------------------------------------------------------------
# DESTROY - Called implicitly by the framework.
# Disconnect nicely.
# ------------------------------------------------------------------------------

sub DESTROY {
    my ($self,$opts) = Hub::objopts( \@_ );
    defined $$self{'dbh'} and $$self{'dbh'}->disconnect();
}#DESTROY

# ------------------------------------------------------------------------------

'???';
