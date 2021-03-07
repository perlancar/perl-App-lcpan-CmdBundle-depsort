package App::lcpan::Cmd::depsort_dist;

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
    summary => 'Given a list of dist names, sort using dependency information (dependencies first)',
    args => {
        %App::lcpan::dists_args,
        # TODO: arg: reverse
    },
};
sub handle_cmd {
    require App::lcpan::Cmd::mod2dist;
    require Data::Graph::Util;

    my %args = @_;

    my $state = App::lcpan::_init(\%args, 'ro');
    my $dbh = $state->{dbh};

    my $dists = delete $args{dists};

    my %seen_dists;
    my %seen_mods;
    my %deps; # key = dependency (what must comes first), val = dependent (which depends on the dependency)

    my @dists_to_check = @$dists;
    while (@dists_to_check) {
        my $dist = shift @dists_to_check;
        next if $seen_dists{$dist}++;
        my $res = App::lcpan::deps(dists => [$dist], dont_uniquify=>1);
        return [500, "Cannot get dependency for dist $dist: $res->[0] - $res->[1]"] unless $res->[0] == 200;
      ENTRY:
        for my $entry (@{ $res->[2] }) {
            next if $entry->{module} =~ /^(perl|Config)$/;
            next if $seen_mods{$entry->{module}}++;

            my $res2 = App::lcpan::Cmd::mod2dist::handle_cmd(modules => [$entry->{module}]);
            return [500, "Cannot get the distribution name for module '$entry->{module}': $res2->[0] - $res2->[1]"]
                unless $res2->[0] == 200;
            do {
                log_warn "There is no distribution for module '$entry->{module}', skipped";
                next ENTRY;
            } unless $res2->[2];
            my $dependency_dist = ref $res2->[2] ? $res2->[2]{ $entry->{module} } : $res2->[2];
            $deps{$dependency_dist} //= [];
            push @{ $deps{$dependency_dist} }, $dist;
            push @dists_to_check, $dependency_dist unless $seen_dists{$dependency_dist};
        }
    } # while @dists_to_check
    #return [200, "TMP", \%deps];

    my @sorted_dists;
    eval {
        @sorted_dists = Data::Graph::Util::toposort(
            \%deps,
            $dists,
        );
    };
    return [500, "Cannot sort dists, probably there are circular dependencies"]
        if $@;
    [200, "OK", \@sorted_dists];
}

1;
# ABSTRACT:
