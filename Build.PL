use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Posy::Plugin::Toc',
    license             => 'perl',
    dist_author         => 'Kathryn Andersen',
    dist_version_from   => 'lib/Posy/Plugin/Toc.pm',
	requires            => {
	'Posy' => 0.71,
	},
    build_requires => {
        'Test::More' => 0,
    },
);

$builder->create_build_script();
