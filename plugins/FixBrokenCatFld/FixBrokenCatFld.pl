package MT::Plugin::FixBrokenCatFld;
use strict;
use warnings;
use base qw( MT::Plugin );

use MT::Category;
use MT::Request;

our $NAME = ( split /::/, __PACKAGE__ )[-1];
our $VERSION = '0.02';

my $plugin = __PACKAGE__->new(
    {   name        => $NAME,
        id          => lc $NAME,
        key         => lc $NAME,
        version     => $VERSION,
        author_name => 'masiuchi',
        author_link => 'https://github.com/masiuchi',
        plugin_link =>
            'https://github.com/masiuchi/mt-plugin-fix-broken-cat-fld',
        description =>
            '<__trans phrase="Fix Categories or Folders which have no parent.">',
    }
);
MT->add_plugin($plugin);

sub init_registry {
    my ($p) = @_;
    $p->registry(
        {   callbacks => {
                'cms_pre_load_filtered_list.category' =>
                    \&_cms_pre_load_filt_list,
                'cms_pre_load_filtered_list.folder' =>
                    \&_cms_pre_load_filt_list,
            },
        }
    );
}

{
    my $orig = \&MT::Category::remove;

    no warnings 'redefine';
    *MT::Category::remove = sub {
        my ( $cat, @args ) = @_;

        if ( ref($cat) eq 'MT::Folder' ) {
            delete $cat->{__children};
        }
        return $orig->( $cat, @args );
    };
}

sub _cms_pre_load_filt_list {
    my ( $cb, $app, $filter, $opt, $cols ) = @_;

    my $ds      = $app->param('datasource');
    my $blog_id = $app->param('blog_id');
    return unless ( $ds eq 'category' || $ds eq 'folder' ) && $blog_id;

    my $r = MT::Request->instance;
    return if $r->cache(__PACKAGE__);
    $r->cache( __PACKAGE__, 1 );

    my $class = MT->model($ds) or return;
    _fix_broken_data( $app, $class, $blog_id );
}

sub _fix_broken_data {
    my ( $app, $class, $blog_id ) = @_;

    my @all_data = $class->load(
        { blog_id   => $blog_id },
        { fetchonly => [qw( id parent )] },
    ) or return;

    my %all_id;
    foreach my $data (@all_data) {
        $all_id{ $data->id } = 1;
    }

    my @broken_data = grep { $_->parent && !$all_id{ $_->parent } } @all_data;
    foreach my $data (@broken_data) {
        $data->remove;
    }
}

1;
