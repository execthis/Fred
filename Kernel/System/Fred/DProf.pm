# --
# Kernel/System/Fred/DProf.pm
# Copyright (C) 2001-2007 OTRS GmbH, http://otrs.org/
# --
# $Id: DProf.pm,v 1.1 2007-09-26 06:08:30 tr Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

package Kernel::System::Fred::DProf;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '$Revision: 1.1 $';
$VERSION =~ s/^\$.*:\W(.*)\W.+?$/$1/;

=head1 NAME

Kernel::System::Fred::DProf

=head1 SYNOPSIS

handle the DProf profiling data

=over 4

=cut

=item new()

create a object

    use Kernel::Config;
    use Kernel::System::Log;

    my $ConfigObject = Kernel::Config->new();
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
    );

=cut

sub new {
    my $Type  = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    for my $Object (qw(ConfigObject LogObject)) {
        $Self->{$Object} = $Param{$Object} || die "Got no $Object!";
    }
    return $Self;
}

=item DataGet()

Get the data for this fred module. Returns true or false.
And add the data to the module ref.

    $BackendObject->DataGet(
        ModuleRef => $ModuleRef,
    );

=cut

sub DataGet {
    my $Self       = shift;
    my %Param      = @_;
    my @Lines;

    # check needed stuff
    for my $NeededRef (qw(HTMLDataRef ModuleRef)) {
        if ( !$Param{$NeededRef} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $NeededRef!",
            );
            return;
        }
    }

    # in this two cases it makes no sense to generate the profiling list
    if (${$Param{HTMLDataRef}} !~ /\<body.*?\>/ ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'This page deliver the HTML by many separate output calls.'
                . ' Please use the usual way to interpret SmallProf',
        );
        return 1;
    }
    if (${$Param{HTMLDataRef}} =~ /Fred-Setting/) {
        return 1;
    }

    # catch the needed profiling data
    my $Path       = $Self->{ConfigObject}->Get('Home') . "/bin/cgi-bin/";
    system "cp $Path/tmon.out $Path/DProf.out";

    my $Config_Ref = $Self->{ConfigObject}->Get('Fred::DProf');
    my @ProfilingResults;
    if (!$Config_Ref->{FunctionTree}) {
        my $ShownLines = $Config_Ref->{ShownLines} < 40 ? $Config_Ref->{ShownLines} : 40;
        my $Options = "-F -O $ShownLines";
        $Options .=   $Config_Ref->{OrderBy} eq 'Name'  ? ' -a'
                    : $Config_Ref->{OrderBy} eq 'Calls' ? ' -l'
                    :                                    '';
        if (open my $Filehandle, "dprofpp $Options $Path/DProf.out |") {
            while ( my $Line = <$Filehandle> ) {
                if ( $Line =~ /^\s*?([^\s]+?)\s+?([^\s]+?)\s+?([^\s]+?)\s+?([^\s]+?)\s+?([^\s]+?)\s+?([^\s]+?)\s+?([^\s]+?)$/ ) {
                    push @ProfilingResults, [ $1, $2, $3, $4, $5, $6, $7 ];
                }
            }
            close $Filehandle;
        }

        shift @ProfilingResults;

        my $TotalTime = 0;
        for my $Time (@ProfilingResults) {
            if ($Time->[1] ne '-') {
                $TotalTime += $Time->[1];
            }
        }

        if ($TotalTime) {
            for my $Time (@ProfilingResults) {
                if ($Time->[1] ne '-') {
                    $Time->[0] = int($Time->[1] / $TotalTime * 10000) / 100;
                }
            }
        }
        ${ $Param{ModuleRef} }{Data} = \@ProfilingResults;
        ${ $Param{ModuleRef} }{TotalTime} = $TotalTime;
    }
    else {
        if (open my $Filehandle, "dprofpp -FT $Path/DProf.out |") {
            my $Counter = 0;
            while ( my $Line = <$Filehandle> ) {
                $Counter++;
                push @ProfilingResults, [$Counter, $Line];
            }
            close $Filehandle;
        }
        ${ $Param{ModuleRef} }{FunctionTree} = \@ProfilingResults;
    }

    return 1;
}

=item ActivateModuleTodos()

Do all jobs which are necessary to activate this special module.

    $FredObject->ActivateModuleTodos(
        ModuleName => $ModuleName,
    );

=cut

sub ActivateModuleTodos {
    my $Self  = shift;
    my @Lines = ();
    my $File  = $Self->{ConfigObject}->Get('Home') . "/bin/cgi-bin/index.pl";

    # check if it is an symlink, because it can be development system which use symlinks
    if ( -l "$File" ) {
        die 'Can\'t manipulate $File because it is a symlink!';
    }

    # to use DProf I have to manipulate the index.pl file
    open my $Filehandle, '<', $File || die "Can't open $File !\n";
    while ( my $Line = <$Filehandle> ) {
        push @Lines, $Line;
    }
    close $Filehandle;

    open my $FilehandleII, '>', $File || die "Can't write $File !\n";
    print $FilehandleII "#!/usr/bin/perl -w -d:DProf\n";
    print $FilehandleII "# FRED - manipulated\n";
    for my $Line (@Lines) {
        print $FilehandleII $Line;
    }
    close $FilehandleII;

    # create a info for the user
    $Self->{LogObject}->Log(
        Priority => 'error',
        Message  => 'FRED manipulated the $File!',
    );

    return 1;
}

=item DeactivateModuleTodos()

Do all jobs which are necessary to deactivate this special module.

    $FredObject->DeactivateModuleTodos(
        ModuleName => $ModuleName,
    );

=cut

sub DeactivateModuleTodos {
    my $Self  = shift;
    my @Lines = ();
    my $File  = $Self->{ConfigObject}->Get('Home') . "/bin/cgi-bin/index.pl";

    # check if it is an symlink, because it can be development system which use symlinks
    if ( -l "$File" ) {
        die 'Can\'t manipulate $File because it is a symlink!';
    }

    # read the index.pl file
    open my $Filehandle, '<', $File || die "Can't open $File !\n";
    while ( my $Line = <$Filehandle> ) {
        push @Lines, $Line;
    }
    close $Filehandle;

    # remove the manipulated lines
    if ( $Lines[0] =~ /#!\/usr\/bin\/perl -w -d:DProf/ ) {
        shift @Lines;
    }
    if ( $Lines[0] =~ /# FRED - manipulated/ ) {
        shift @Lines;
    }

    # save the index.pl file
    open my $FilehandleII, '>', $File || die "Can't write $File !\n";
    for my $Line (@Lines) {
        print $FilehandleII $Line;
    }
    close $FilehandleII;
    $Self->{LogObject}->Log(
        Priority => 'error',
        Message  => 'FRED manipulated the $File!',
    );

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (http://otrs.org/).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see http://www.gnu.org/licenses/gpl.txt.

=cut

=head1 VERSION

$Revision: 1.1 $ $Date: 2007-09-26 06:08:30 $

=cut