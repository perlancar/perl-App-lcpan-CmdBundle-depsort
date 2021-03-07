package App::lcpan::Cmd::depsort_rel;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

require App::lcpan;

our %SPEC;

$SPEC{handle_cmd} = {
    v => 1.1,
    summary => 'Given a list of release tarball names, sort using dependency information (dependencies first)',
    description => <<'_',

Currently this routine only accepts release names in the form of:

    DISTNAME-VERSION.(tar.gz|tar.bz2|zip)

examples:

    App-IndonesianHolidayUtils-0.001.tar.gz
    Calendar-Indonesia-Holiday-1.446.tar.gz

_
    args => {
        releases => {
            'x.name.is_plural' => 1,
            'x.name.singular' => 'release',
            schema => ['array*', of=>'str*'],
            req => 1,
            pos => 0,
            slurpy => 1,
        },
        # TODO: arg: reverse
    },
};
sub handle_cmd {
    require App::lcpan::Cmd::depsort_dist;
    require Data::Graph::Util;

    my %args = @_;

    my $state = App::lcpan::_init(\%args, 'ro');
    my $dbh = $state->{dbh};

    my $rels = delete $args{releases};

    my @dists;
    my %reldists; # key = release name, val = dist name
    for my $rel (@$rels) {
        $rel =~ /\A(\w+(?:-\w+)*)-(\d(?:\.\d+)*)\.(tar\.gz|tar\.bz2|zip)\z/
            or return [400, "Unrecognized release name $rel, please use DISTNAME-VERSION.tar.gz"];
        $reldists{$rel} = $1;
        push @dists, $1;
    }
    my $res = App::lcpan::Cmd::depsort_dist::handle_cmd(dists => \@dists);
    return $res unless $res->[0] == 200;
    my %distpos; # key = dist, val = index
    for my $i (0 .. $#{ $res->[2] }) {
        $distpos{ $res->[2][$i] } = $i;
    }

    my @sorted_rels = sort {
        $distpos{ $reldists{$a} } <=> $distpos{ $reldists{$b} }
    } @$rels;
    [200, "OK", \@sorted_rels];
}

1;
# ABSTRACT:
