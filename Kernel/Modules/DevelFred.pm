# --
# Kernel/Modules/DevelFred.pm - a special developer module
# Copyright (C) 2001-2007 OTRS GmbH, http://otrs.org/
# --
# $Id: DevelFred.pm,v 1.1 2007-09-21 07:44:58 tr Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

package Kernel::Modules::DevelFred;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '$Revision: 1.1 $';
$VERSION =~ s/^\$.*:\W(.*)\W.+?$/$1/;

#use Kernel::System::XML;
use Kernel::System::Config;

sub new {
    my $Type = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless ($Self, $Type);

    # check needed Objects
    for my $Object (qw(
        ParamObject DBObject     LogObject ConfigObject
        MainObject  LayoutObject TimeObject
    )) {
        if ($Param{$Object}) {
            $Self->{$Object} = $Param{$Object};
        }
        else {
            $Self->{LayoutObject}->FatalError(Message => "Got no $Object!");
        }
    }
#    $Self->{XMLObject} = Kernel::System::XML->new(%{$Self});
    $Self->{ConfigToolObject} = Kernel::System::Config->new(%{$Self});
    $Self->{Subaction} = $Self->{ParamObject}->GetParam(Param => 'Subaction');
    return $Self;
}

sub Run {
    my $Self = shift;
    my %Param = @_;

    # ---------------------------------------------------------- #
    # show the overview
    # ---------------------------------------------------------- #
    if (!$Self->{Subaction}) {
    }
#        my $Output   = '';
#
#        my @TranslationWhiteList = $Self->{XMLObject}->XMLHashGet(
#            Type => 'Fred-Translation',
#            Key  => 1,
#            Cache => 0,
#        );
#
#        my %WhiteList;
#        for my $Content (@{$TranslationWhiteList[1]{Translation}}) {
#            if ($Content->{Content}) {
#                # add add block
#                $Self->{LayoutObject}->Block(
#                    Name => 'Line',
#                    Data => {
#                        Word => $Content->{Content},
#                    },
#                );
#            }
#        }
#
#        # build output
#        $Output .= $Self->{LayoutObject}->Header(Title => "Fred-Overview");
#        $Output .= $Self->{LayoutObject}->NavigationBar();
#        $Output .= $Self->{LayoutObject}->Output(
#            Data => {%Param},
#            TemplateFile => 'DevelFred',
#        );
#        $Output .= $Self->{LayoutObject}->Footer();
#        return $Output;
#    }
#    # ---------------------------------------------------------- #
#    # handle the translation log
#    # ---------------------------------------------------------- #
#    elsif ($Self->{Subaction} eq 'Translation') {
#        my $Value = $Self->{ParamObject}->GetParam(Param => 'Value');
#
#        my @Data = $Self->{XMLObject}->XMLHashGet(
#            Type => 'Fred-Translation',
#            Key  => 1,
#            Cache => 0,
#        );
#
#        if (!@Data) {
#            my @Hash;
#
#            $Hash[1]{Translation}[1]{Content} = $Value;
#            $Self->{XMLObject}->XMLHashAdd(
#                Type    => 'Fred-Translation',
#                Key     => 1,
#                XMLHash => \@Hash,
#            );
#        }
#        else {
#            push @{$Data[1]{Translation}}, {Content => $Value};
#            $Self->{XMLObject}->XMLHashUpdate(
#                Type => 'Fred-Translation',
#                Key => '1',
#                XMLHash => \@Data,
#            );
#
#        }
#
#        my $Referer = $ENV{HTTP_REFERER};
#        if ($Referer =~ /\?(.+)$/) {
#            $Referer = $1;
#        }
#
#        return $Self->{LayoutObject}->Redirect(OP => $Referer);
#    }
#    elsif ($Self->{Subaction} eq 'TranslationDelete') {
#        my @Data = $Self->{XMLObject}->XMLHashDelete(
#            Type => 'Fred-Translation',
#            Key  => 1,
#        );
#
#        my $Referer = $ENV{HTTP_REFERER};
#        if ($Referer =~ /\?(.+)$/) {
#            $Referer = $1;
#        }
#
#        return $Self->{LayoutObject}->Redirect(OP => $Referer);
#    }
    # ---------------------------------------------------------- #
    # fast handle for fred settings
    # ---------------------------------------------------------- #
    elsif ($Self->{Subaction} eq 'Setting') {
        my $ModuleForRef = $Self->{ConfigObject}->Get('Fred::Module');
        for my $Module (keys %{$ModuleForRef}) {
            my $Checked = '';
            if ($ModuleForRef->{$Module}->{Active}) {
                $Checked = 'checked="checked"';
            }
            $Self->{LayoutObject}->Block(
                Name => 'FredModule',
                Data => {
                    FredModule => $Module,
                    Checked    => $Checked,
                }
            );
        }

        # build output
        my $Output = $Self->{LayoutObject}->Header(Title => "Fred-Setting");
        $Output .= $Self->{LayoutObject}->Output(
            Data => {%Param},
            TemplateFile => 'DevelFredSetting',
        );
        return $Output;
    }
    # ---------------------------------------------------------- #
    # fast handle for fred settings
    # ---------------------------------------------------------- #
    elsif ($Self->{Subaction} eq 'SettingAction') {
        my $ModuleForRef = $Self->{ConfigObject}->Get('Fred::Module');
        my @SelectedFredModules = $Self->{ParamObject}->GetArray(Param => 'FredModule');
        my %SelectedModules = map { $_ => 1; } @SelectedFredModules;
        my $UpdateFlag;
        for my $Module (keys %{$ModuleForRef}) {
            if ($ModuleForRef->{$Module}->{Active} && !$SelectedModules{$Module} ||
                !$ModuleForRef->{$Module}->{Active} && $SelectedModules{$Module}
            ) {
                $Self->{ConfigToolObject}->ConfigItemUpdate(
                    Valid => 1,
                    Key => "Fred::Module###$Module",
                    Value => {
                        'Active' => $SelectedModules{$Module} || 0,
                        'Module' => $ModuleForRef->{$Module}->{Module}
                    },
                );
                $UpdateFlag = 1;
            }
        }
        if ($UpdateFlag) {
            $Self->{ConfigToolObject}->ConfigItemUpdateFinish();
        }
        $Self->{LayoutObject}->FatalError(Message => "Now the browser should be closed");
    }
    return 1;
}

1;