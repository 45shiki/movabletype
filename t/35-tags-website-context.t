#!/usr/bin/perl

use strict;
use warnings;

use lib qw(lib t/lib ../lib);

BEGIN {
    $ENV{MT_CONFIG} = 'mysql-test.cfg';
    $ENV{MT_APP}    = 'MT::App::CMS';
}

use IPC::Open2;

use Test::Base;
plan tests => 2 * blocks;

use MT;
use MT::PublishOption;
use MT::Test qw(:app :db);
my $app    = MT->instance;
my $config = $app->config;
$config->AllowComments( 1, 1 );
$config->StaticFilePath( './mt-static', 1 );
$config->CommenterRegistration( { Allow => 1 }, 1 );
$config->save_config;
delete $app->{__static_file_path};

my $blog_id       = 1;                                        # First Website
my $first_website = $app->model('website')->load($blog_id);
$first_website->set_values(
    {   allow_reg_comments       => 1,
        remote_auth_token        => 'token',
        allow_unreg_comments     => 1,
        commenter_authenticators => 'MovableType,TypeKey',
    }
);
$first_website->save or die $first_website->errstr;

filters {
    template => [qw( chomp )],
    expected => [qw( chomp )],
};

my $mt = MT->instance;

# Create userpic
my $userpic = $mt->model('asset')->new;
$userpic->set_values(
    {   blog_id   => 0,
        class     => 'image',
        label     => 'Userpic',
        file_path => './mt-static/images/logo/movable-type-logo.png',
        file_name => 'movable-type-logo.png',
        url       => '%s/images/logo/movable-type-logo.png',
    }
);
$userpic->save or die $mt->errstr;

my $admin = $mt->model('author')->load(1);    # Administrator
$admin->set_values(
    {   nickname         => 'Administrator Melody',
        basename         => 'melody',
        email            => 'melody@localhost',
        url              => 'http://localhost/~melody/',
        userpic_asset_id => $userpic->id,
    }
);
$admin->save or die $admin->errstr;

my $guest = $mt->model('author')->new;
$guest->set_values(
    {   name            => 'Guest',
        nickname        => 'Guest',
        basename        => 'guest',
        email           => 'guest@localhost',
        url             => 'http://localhost/~guest/',
        password        => '',
        type            => MT::Author::AUTHOR(),
        locked_out_time => 0,
    }
);
$guest->save or die $guest->errstr;

{
    # Parent website
    my $w = $mt->model('website')->load($blog_id);
    $w->set_values(
        {   description => 'This is a first website.',
            site_url    => 'http://localhost/first_website/',
            site_path   => '/var/www/html/first_website',
            cc_license =>
                'by http://creativecommons.org/licenses/by/3.0/ http://i.creativecommons.org/l/by/3.0/88x31.png',
        }
    );
    $w->save or die $w->errstr;

    # apply theme
    $app = _run_app(
        'MT::App::CMS',
        {   __test_user      => $admin,
            __request_method => 'POST',
            __mode           => 'apply_theme',
            blog_id          => $w->id,
            theme_id         => 'classic_website',
        },
    );

    # Create categories
    my $cat1 = MT::Category->new;
    $cat1->set_values(
        {   blog_id     => $blog_id,
            label       => 'Website Category 1',
            basename    => 'website_category_1',
            description => 'This is a website category 1.',
            allow_pings => 1,
        }
    );
    $cat1->save or die $cat1->errstr;

    my $cat_tmpl
        = MT::Template->load(
        { blog_id => $blog_id, identifier => 'category_entry_listing' } );

    my $tm_cat = MT::TemplateMap->new;
    $tm_cat->set_values(
        {   archive_type => 'Category',
            blog_id      => $blog_id,
            build_type   => MT::PublishOption::DYNAMIC(),
            is_preferred => 1,
            template_id  => $cat_tmpl->id,
        }
    );
    $tm_cat->save or die $tm_cat->errstr;

    my $fi_cat1 = MT::FileInfo->new;
    $fi_cat1->set_values(
        {   archive_type => 'Category',
            blog_id      => $blog_id,
            category_id  => $cat1->id,
            filepath =>
                '/var/www/html/first_website/website_category_1/index.html',
            template_id    => $cat_tmpl->id,
            templatemap_id => $tm_cat->id,
            url            => '/first_website/website-category-1/index.html',
        }
    );
    $fi_cat1->save or die $fi_cat1->errstr;

    my $cat2 = MT::Category->new;
    $cat2->set_values(
        {   blog_id     => $blog_id,
            label       => 'Website Subcategory 2',
            basename    => 'website_subcategory_2',
            description => 'This is a website subcategory 2.',
            parent      => $cat1->id,
        }
    );
    $cat2->save or die $cat2->errstr;

    my $fi_cat2 = MT::FileInfo->new;
    $fi_cat2->set_values(
        {   archive_type => 'Category',
            blog_id      => $blog_id,
            category_id  => $cat2->id,
            filepath =>
                '/var/www/html/first_website/website_category_1/website_subcategory_2/index.html',
            template_id    => $cat_tmpl->id,
            templatemap_id => $tm_cat->id,
            url =>
                '/first_website/website-category-1/website-subcategory-2/index.html',
        }
    );
    $fi_cat2->save or die $fi_cat2->errstr;

    my $cat3 = MT::Category->new;
    $cat3->set_values(
        {   blog_id     => $blog_id,
            label       => 'Website Category 3',
            basename    => 'website_category_3',
            description => 'This is a website category 3.',
        }
    );
    $cat3->save or die $cat3->errstr;

    my $fi_cat3 = MT::FileInfo->new;
    $fi_cat3->set_values(
        {   archive_type => 'Category',
            blog_id      => $blog_id,
            category_id  => $cat3->id,
            filepath =>
                '/var/www/html/first_website/website_category_3/index.html',
            template_id    => $cat_tmpl->id,
            templatemap_id => $tm_cat->id,
            url            => '/first_website/website-category-3/index.html',
        }
    );
    $fi_cat3->save or die $fi_cat3->errstr;

    my $cat4 = MT::Category->new;
    $cat4->set_values(
        {   blog_id     => $blog_id,
            label       => 'Website Category 4',
            basename    => 'website_category_4',
            description => 'This is a website category 4.',
        }
    );
    $cat4->save or die $cat4->errstr;

    my $fi_cat4 = MT::FileInfo->new;
    $fi_cat4->set_values(
        {   archive_type => 'Category',
            blog_id      => $blog_id,
            category_id  => $cat4->id,
            filepath =>
                '/var/www/html/first_website/website_category_4/index.html',
            template_id    => $cat_tmpl->id,
            templatemap_id => $tm_cat->id,
            url            => '/first_website/website-category-4/index.html',
        }
    );
    $fi_cat4->save or die $fi_cat4->errstr;

    my $cat5 = MT::Category->new;
    $cat5->set_values(
        {   blog_id     => $blog_id,
            label       => 'Website Subsubcategory 5',
            basename    => 'website_subsubcategory_5',
            description => 'This is a website subsubcategory 5.',
            parent      => $cat2->id,
        }
    );
    $cat5->save or die $cat5->errstr;

    my $fi_cat5 = MT::FileInfo->new;
    $fi_cat5->set_values(
        {   archive_type => 'Category',
            blog_id      => $blog_id,
            category_id  => $cat5->id,
            filepath =>
                '/var/www/html/first_website/website_category_1/website_subcategory_2/website_subsubcategory_5/index.html',
            template_id    => $cat_tmpl->id,
            templatemap_id => $tm_cat->id,
            url =>
                '/first_website/website-category-1/website-subcategory-2/website-subsubcategory-5/index.html',
        }
    );
    $fi_cat5->save or die $fi_cat5->errstr;

    my $cat6 = MT::Category->new;
    $cat6->set_values(
        {   blog_id     => $blog_id,
            label       => 'Website Subsubcategory 6',
            basename    => 'website_subsubcategory_6',
            description => 'This is a website subsubcategory 6.',
            parent      => $cat2->id,
        }
    );
    $cat6->save or die $cat6->errstr;

    my $fi_cat6 = MT::FileInfo->new;
    $fi_cat6->set_values(
        {   archive_type => 'Category',
            blog_id      => $blog_id,
            category_id  => $cat6->id,
            filepath =>
                '/var/www/html/first_website/website_category_1/website_subcategory_2/website_subsubcategory_6/index.html',
            template_id    => $cat_tmpl->id,
            templatemap_id => $tm_cat->id,
            url =>
                '/first_website/website-category-1/website-subcategory-2/website-subsubcategory-6/index.html',
        }
    );
    $fi_cat6->save or die $fi_cat6->errstr;

    # Create entries
    my $e1 = $mt->model('entry')->new;
    $e1->set_values(
        {   blog_id     => $blog_id,
            author_id   => $admin->id,
            status      => MT::Entry::RELEASE(),
            title       => 'Website Entry 1',
            basename    => 'website_entry_1',
            text        => 'This is website entry 1.',
            text_more   => 'Both allow_pings and allow_comments are null.',
            excerpt     => 'Website Entry Excerpt 1',
            keywords    => 'Foo',
            authored_on => '20110101000000',
            modified_on => '20110101000000',
            created_on  => '20110101000000',
        }
    );
    $e1->save or die $e1->errstr;

    my $tmpl
        = MT::Template->load( { blog_id => $blog_id, type => 'individual' } );

    my $tm = MT::TemplateMap->new;
    $tm->set_values(
        {   archive_type => 'Individual',
            blog_id      => $blog_id,
            build_type   => MT::PublishOption::DYNAMIC(),
            is_preferred => 1,
            template_id  => $tmpl->id,
        }
    );
    $tm->save or die $tm->errstr;

    my $fi1 = MT::FileInfo->new;
    $fi1->set_values(
        {   archive_type => 'Individual',
            blog_id      => $blog_id,
            entry_id     => $e1->id,
            file_path =>
                '/var/www/html/first_website/2011/01/website-entry-1.html',
            template_id    => $tmpl->id,
            templatemap_id => $tm->id,
            url            => '/first_website/2011/01/website-entry-1.html',
            virtual        => 1,
        }
    );
    $fi1->save or die $fi1->errstr;

    # Set categories
    my $pl1 = MT::Placement->new;
    $pl1->set_values(
        {   blog_id     => $blog_id,
            category_id => $cat1->id,
            entry_id    => $e1->id,
            is_primary  => 1,
        }
    );
    $pl1->save or die $pl1->errstr;

    my $pl4 = MT::Placement->new;
    $pl4->set_values(
        {   blog_id     => $blog_id,
            category_id => $cat4->id,
            entry_id    => $e1->id,
            is_primary  => 0,
        }
    );
    $pl4->save or die $pl4->errstr;

    # Create tag
    my $tag1 = $mt->model('tag')->new;
    $tag1->set_values( { name => 'Website Tag 1', } );
    $tag1->save or die $tag1->errstr;

    my $objtag1 = $mt->model('objecttag')->new;
    $objtag1->set_values(
        {   blog_id           => $blog_id,
            object_datasource => 'entry',
            object_id         => $e1->id,
            tag_id            => $tag1->id,
        }
    );
    $objtag1->save or die $objtag1->errstr;

    # Create score
    my $objscore1 = $mt->model('objectscore')->new;
    $objscore1->set_values(
        {   author_id => $admin->id,
            namespace => 'test_namespace',
            object_ds => 'entry',
            object_id => $e1->id,
            score     => 2,
        }
    );
    $objscore1->save or die $objscore1->errstr;

    my $objscore2 = $mt->model('objectscore')->new;
    $objscore2->set_values(
        {   author_id => $guest->id,
            namespace => 'test_namespace',
            object_ds => 'entry',
            object_id => $e1->id,
            score     => 4,
        }
    );
    $objscore2->save or die $objscore2->errstr;

    # allow_pings is set 1.
    my $e2 = $mt->model('entry')->new;
    $e2->set_values(
        {   blog_id     => $blog_id,
            author_id   => $admin->id,
            status      => MT::Entry::RELEASE(),
            title       => 'Website Entry 2',
            basename    => 'website_entry_2',
            text        => 'This is website entry 2.',
            text_more   => 'Allow_pings is 1, allow_comments is null.',
            excerpt     => 'Website Entry Excerpt 2',
            allow_pings => 1,
            authored_on => '20120202000000',
            modified_on => '20120202000000',
            created_on  => '20120202000000',
        }
    );
    $e2->save or die $e2->errstr;

    my $fi2 = MT::FileInfo->new;
    $fi2->set_values(
        {   archive_type => 'Individual',
            blog_id      => $blog_id,
            entry_id     => $e2->id,
            file_path =>
                '/var/www/html/first_website/2012/02/website-entry-2.html',
            template_id    => $tmpl->id,
            templatemap_id => $tm->id,
            url            => '/first_website/2012/02/website-entry-2.html',
            virtual        => 1,
        }
    );
    $fi2->save or die $fi2->errstr;

    my $pl2 = MT::Placement->new;
    $pl2->set_values(
        {   blog_id     => $blog_id,
            category_id => $cat2->id,
            entry_id    => $e2->id,
            is_primary  => 1,
        }
    );
    $pl2->save or die $pl2->errstr;

    # allow_comments is set 1.
    my $e3 = $mt->model('entry')->new;
    $e3->set_values(
        {   blog_id        => $blog_id,
            author_id      => $admin->id,
            status         => MT::Entry::RELEASE(),
            title          => 'Website Entry 3',
            basename       => 'website_entry_3',
            text           => 'This is website entry 3.',
            text_more      => 'Allow_pings is null, allow_comments is 1.',
            excerpt        => 'Website Entry Excerpt 3',
            allow_comments => 1,
            keywords       => 'Bar',
            authored_on    => '20130303000000',
            modified_on    => '20130303000000',
            created_on     => '20130303000000',
        }
    );
    $e3->save or die $e3->errstr;

    my $fi3 = MT::FileInfo->new;
    $fi3->set_values(
        {   archive_type => 'Individual',
            blog_id      => $blog_id,
            entry_id     => $e3->id,
            file_path =>
                '/var/www/html/first_website/2013/03/website-entry-3.html',
            template_id    => $tmpl->id,
            templatemap_id => $tm->id,
            url            => '/first_website/2013/03/website-entry-3.html',
            virtual        => 1,
        }
    );
    $fi3->save or die $fi3->errstr;

    my $pl3 = MT::Placement->new;
    $pl3->set_values(
        {   blog_id     => $blog_id,
            category_id => $cat3->id,
            entry_id    => $e3->id,
            is_primary  => 1,
        }
    );
    $pl3->save or die $pl3->errstr;

    # status is set 1 (HOLD).
    my $e4 = $mt->model('entry')->new;
    $e4->set_values(
        {   blog_id     => $blog_id,
            author_id   => $admin->id,
            status      => MT::Entry::HOLD(),
            title       => 'Website Entry 4',
            text        => 'This is website entry 4.',
            authored_on => '20140404000000',
        }
    );
    $e4->save or die $e4->errstr;

    my $fi4 = MT::FileInfo->new;
    $fi4->set_values(
        {   archive_type => 'Individual',
            blog_id      => $blog_id,
            entry_id     => $e4->id,
            file_path =>
                '/var/www/html/first_website/2014/04/website-entry-4.html',
            template_id    => $tmpl->id,
            templatemap_id => $tm->id,
            url            => '/first_website/2014/04/website-entry-4.html',
            virtual        => 1,
        }
    );
    $fi4->save or die $fi4->errstr;

    my $e5 = $mt->model('entry')->new;
    $e5->set_values(
        {   blog_id     => $blog_id,
            author_id   => $admin->id,
            status      => MT::Entry::RELEASE(),
            title       => 'Website Entry 5',
            text        => 'This is website entry 5.',
            authored_on => '20150505000000',
            modified_on => '20150505000000',
            created_on  => '20150505000000',
        }
    );
    $e5->save or die $e5->errstr;

    my $fi5 = MT::FileInfo->new;
    $fi5->set_values(
        {   archive_type => 'Individual',
            blog_id      => $blog_id,
            entry_id     => $e5->id,
            file_path =>
                '/var/www/html/first_website/2015/05/website-entry-5.html',
            template_id    => $tmpl->id,
            templatemap_id => $tm->id,
            url            => '/first_website/2015/05/website-entry-5.html',
            virtual        => 1,
        }
    );
    $fi5->save or die $fi5->errstr;

    my $pl5 = MT::Placement->new;
    $pl5->set_values(
        {   blog_id     => $blog_id,
            category_id => $cat5->id,
            entry_id    => $e5->id,
            is_primary  => 1,
        }
    );
    $pl5->save or die $pl5->errstr;

    my $e6 = $mt->model('entry')->new;
    $e6->set_values(
        {   blog_id     => $blog_id,
            author_id   => $admin->id,
            status      => MT::Entry::RELEASE(),
            title       => 'Website Entry 6',
            text        => 'This is website entry 6.',
            authored_on => '20160606000000',
            modified_on => '20160606000000',
            created_on  => '20160606000000',
        }
    );
    $e6->save or die $e6->errstr;

    my $fi6 = MT::FileInfo->new;
    $fi6->set_values(
        {   archive_type => 'Individual',
            blog_id      => $blog_id,
            entry_id     => $e6->id,
            file_path =>
                '/var/www/html/first_website/2016/06/website-entry-6.html',
            template_id    => $tmpl->id,
            templatemap_id => $tm->id,
            url            => '/first_website/2016/06/website-entry-6.html',
            virtual        => 1,
        }
    );
    $fi6->save or die $fi6->errstr;

    my $pl6 = MT::Placement->new;
    $pl6->set_values(
        {   blog_id     => $blog_id,
            category_id => $cat6->id,
            entry_id    => $e6->id,
            is_primary  => 1,
        }
    );
    $pl6->save or die $pl6->errstr;

    my $e7 = $mt->model('entry')->new;
    $e7->set_values(
        {   blog_id     => $blog_id,
            author_id   => $admin->id,
            status      => MT::Entry::RELEASE(),
            title       => 'Website Entry 7',
            text        => 'This is website entry 7.',
            authored_on => '20160606010000',
            modified_on => '20160606010000',
            created_on  => '20160606010000',
        }
    );
    $e7->save or die $e7->errstr;

    my $fi7 = MT::FileInfo->new;
    $fi7->set_values(
        {   archive_type => 'Individual',
            blog_id      => $blog_id,
            entry_id     => $e7->id,
            file_path =>
                '/var/www/html/first_website/2016/06/website-entry-7.html',
            template_id    => $tmpl->id,
            templatemap_id => $tm->id,
            url            => '/first_website/2016/06/website-entry-7.html',
            virtual        => 1,
        }
    );
    $fi7->save or die $fi7->errstr;

    # Create comment
    my $c1 = $mt->model('comment')->new;
    $c1->set_values(
        {   blog_id       => $blog_id,
            entry_id      => $e1->id,
            commenter_id  => $admin->id,
            author        => $admin->nickname,
            email         => $admin->email,
            url           => $admin->url,
            last_moved_on => '20101010000000',
            visible       => 1,
            junk_status   => 1,                  # NOT_JUNK
            ip            => '127.0.0.1',
            text          => 'Comment 1',
            created_on    => '20101010000000',
            modified_on   => '20101010000000',
        }
    );
    $c1->save or die $c1->errstr;

    my $c2 = $mt->model('comment')->new;
    $c2->set_values(
        {   blog_id       => $blog_id,
            entry_id      => $e1->id,
            commenter_id  => $guest->id,
            author        => $guest->nickname,
            email         => $guest->email,
            url           => $guest->url,
            parent_id     => $c1->id,
            last_moved_on => '20111111000000',
            visible       => 1,
            junk_status   => 1,                  # NOT_JUNK
            ip            => '192.168.0.1',
            text          => 'Comment 2',
            created_on    => '20111111000000',
            modified_on   => '20111111000000',
        }
    );
    $c2->save or die $c2->errstr;

    my $c3 = $mt->model('comment')->new;
    $c3->set_values(
        {   blog_id       => $blog_id,
            entry_id      => $e1->id,
            commenter_id  => $admin->id,
            author        => $admin->nickname,
            email         => $admin->email,
            url           => $admin->url,
            parent_id     => $c2->id,
            last_moved_on => '20121212000000',
            visible       => 1,
            junk_status   => 1,                  # NOT_JUNK
            ip            => '127.0.0.1',
            text          => 'Comment 3',
            created_on    => '20121212000000',
            modified_on   => '20121212000000',
        }
    );
    $c3->save or die $c3->errstr;

    # Create comment score
    my $objscore3 = $mt->model('objectscore')->new;
    $objscore3->set_values(
        {   author_id => $admin->id,
            namespace => 'test_namespace',
            object_ds => 'comment',
            object_id => $c1->id,
            score     => 1,
        }
    );
    $objscore3->save or die $objscore3->errstr;

    my $objscore4 = $mt->model('objectscore')->new;
    $objscore4->set_values(
        {   author_id => $admin->id,
            namespace => 'test_namespace',
            object_ds => 'comment',
            object_id => $c1->id,
            score     => 3,
        }
    );
    $objscore4->save or die $objscore4->errstr;

    # Create tbping
    my $tbp1 = $mt->model('tbping')->new;
    $tbp1->set_values(
        {   blog_id       => $blog_id,
            tb_id         => $e2->trackback->id,
            ip            => '127.0.0.1',
            visible       => 1,
            junk_status   => 1,                    # NOT_JUNK
            last_moved_on => '20080808000000',
            blog_name     => 'first website',
        }
    );
    $tbp1->save or die $tbp1->errstr;

    my $tbp2 = $mt->model('tbping')->new;
    $tbp2->set_values(
        {   blog_id       => $blog_id,
            tb_id         => 1,
            ip            => '127.0.0.1',
            visible       => 1,
            junk_status   => 1,                  # NOT_JUNK
            last_moved_on => '20090909000000',
            blog_name     => 'first website',
        }
    );
    $tbp2->save or die $tbp2->errstr;

    # Create asset
    my $as1 = $mt->model('asset')->new;
    $as1->set_values(
        {   blog_id => $blog_id,
            label   => 'Website Asset 1',
        }
    );
    $as1->save or die $as1->errstr;

    my $objas1 = $mt->model('objectasset')->new;
    $objas1->set_values(
        {   asset_id  => $as1->id,
            blog_id   => $blog_id,
            object_ds => 'entry',
            object_id => $e1->id,
        }
    );
    $objas1->save or die $objas1->errstr;

    # Create template maps for archive
    my $tm_mo = $mt->model('templatemap')->load(
        {   blog_id      => $blog_id,
            archive_type => 'Monthly',
        }
    );

    my %suite = (
        Daily => [
            {   file_path =>
                    '/var/www/html/first_website/2011/01/01/index.html',
                startdate => '20110101000000',
                url       => '/first_website/2011/01/01/index.html',
            },
            {   file_path =>
                    '/var/www/html/first_website/2011/02/02/index.html',
                startdate => '20120202000000',
                url       => '/first_website/2012/02/02/index.html',
            },
            {   file_path =>
                    '/var/www/html/first_website/2013/03/03/index.html',
                startdate => '20130303000000',
                url       => '/first_website/2013/03/03/index.html',
            },
            {   file_path =>
                    '/var/www/html/first_website/2015/05/05/index.html',
                startdate => '20150505000000',
                url       => '/first_website/2015/05/05/index.html',
            },
            {   file_path =>
                    '/var/www/html/first_website/2016/06/06/index.html',
                startdate => '20160606000000',
                url       => '/first_website/2016/06/06/index.html',
            },
        ],
        Weekly => [
            {   file_path =>
                    '/var/www/html/first_website/2010/12/26-week/index.html',
                startdate => '20101226000000',
                url       => '/first_website/2010/12/26-week/index.html',
            },
            {   file_path =>
                    '/var/www/html/first_website/2012/01/29-week/index.html',
                startdate => '20120129000000',
                url       => '/first_website/2012/01/29-week/index.html',
            },
            {   file_path =>
                    '/var/www/html/first_website/2013/03/03-week/index.html',
                startdate => '20130303000000',
                url       => '/first_website/2013/03/03-week/index.html',
            },
            {   file_path =>
                    '/var/www/html/first_website/2015/05/03-week/index.html',
                startdate => '20150503000000',
                url       => '/first_website/2015/05/03-week/index.html',
            },
            {   file_path =>
                    '/var/www/html/first_website/2016/06/05-week/index.html',
                startdate => '20160605000000',
                url       => '/first_website/2016/06/05-week/index.html',
            },
        ],
        Monthly => [
            {   file_path => '/var/www/html/first_website/2011/01/index.html',
                startdate => '20110101000000',
                url       => '/first_website/2011/01/index.html',
            },
            {   file_path => '/var/www/html/first_website/2012/02/index.html',
                startdate => '20120201000000',
                url       => '/first_website/2012/02/index.html',
            },
            {   file_path => '/var/www/html/first_website/2013/03/index.html',
                startdate => '20130301000000',
                url       => '/first_website/2013/03/index.html',
            },
            {   file_path => '/var/www/html/first_website/2015/05/index.html',
                startdate => '20150501000000',
                url       => '/first_website/2015/05/index.html',
            },
            {   file_path => '/var/www/html/first_website/2016/06/index.html',
                startdate => '20160601000000',
                url       => '/first_website/2016/06/index.html',
            },
        ],
        Yearly => [
            {   file_path => '/var/www/html/first_website/2011/index.html',
                startdate => '20110101000000',
                url       => '/first_website/2011/index.html',
            },
            {   file_path => '/var/www/html/first_website/2012/index.html',
                startdate => '20120101000000',
                url       => '/first_website/2012/index.html',
            },
            {   file_path => '/var/www/html/first_website/2013/index.html',
                startdate => '20130101000000',
                url       => '/first_website/2013/index.html',
            },
            {   file_path => '/var/www/html/first_website/2015/index.html',
                startdate => '20150101000000',
                url       => '/first_website/2015/index.html',
            },
            {   file_path => '/var/www/html/first_websiete/2016/index.html',
                startdate => '20160101000000',
                url       => '/first_website/2016/index.html'
            },
        ],
        Author => [
            {   file_path =>
                    '/var/www/html/first_website/author/melody/index.html',
                url       => '/first_website/author/melody/index.html',
                author_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/author/guest/index.html',
                url       => '/first_website/author/guest/index.html',
                author_id => 2,
            },
        ],
        'Author-Daily' => [
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2011/01/01/index.html',
                startdate => '20110101000000',
                url => '/first_website/author/melody/2011/01/01/index.html',
                author_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2012/02/02/index.html',
                startdate => '20120202000000',
                url => '/first_website/author/melody/2012/02/02/index.html',
                author_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2013/03/03/index.html',
                startdate => '20130303000000',
                url => '/first_website/author/melody/2013/03/03/index.html',
                author_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2015/05/05/index.html',
                startdate => '20150505000000',
                url => '/first_website/author/melody/2015/05/05/index.html',
                author_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2016/06/06/index.html',
                startdate => '20160606000000',
                url => '/first_website/author/melody/2016/06/06/index.html',
                author_id => 1,
            },
        ],
        'Author-Weekly' => [
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2010/12/26-week/index.html',
                startdate => '20101226000000',
                url =>
                    '/first_website/author/melody/2010/12/26-week/index.html',
                author_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2012/01/29-week/index.html',
                startdate => '20120129000000',
                url =>
                    '/first_website/author/melody/2012/01/29-week/index.html',
                author_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2013/03/03-week/index.html',
                startdate => '20130303000000',
                url =>
                    '/first_website/author/melody/2013/03/03-week/index.html',
                author_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2015/05/03-week/index.html',
                startdate => '20150503000000',
                url =>
                    '/first_website/author/melody/2015/05/03-week/index.html',
                author_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2016/06/05-week/index.html',
                startdate => '20160605000000',
                url =>
                    '/first_website/author/melody/2016/06/05-week/index.html',
                author_id => 1,
            },
        ],
        'Author-Monthly' => [
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2011/01/index.html',
                startdate => '20110101000000',
                url => '/first_website/author/melody/2011/01/index.html',
                author_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2012/02/index.html',
                startdate => '20120201000000',
                url => '/first_website/author/melody/2012/02/index.html',
                author_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2013/03/index.html',
                startdate => '20130301000000',
                url => '/first_website/author/melody/2013/03/index.html',
                author_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2015/05/index.html',
                startdate => '20150501000000',
                url => '/first_website/author/melody/2015/05/index.html',
                author_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2016/06/index.html',
                startdate => '20160601000000',
                url => '/first_website/author/melody/2016/06/index.html',
                author_id => 1,
            },
        ],
        'Author-Yearly' => [
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2011/index.html',
                startdate => '20110101000000',
                url       => '/first_website/author/melody/2011/index.html',
                author_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2012/index.html',
                startdate => '20120101000000',
                url       => '/first_website/author/melody/2012/index.html',
                author_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2013/index.html',
                startdate => '20130101000000',
                url       => '/first_website/author/melody/2013/index.html',
                author_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2015/index.html',
                startdate => '20150101000000',
                url       => '/first_website/author/melody/2015/index.html',
                author_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/author/melody/2016/index.html',
                startdate => '20160101000000',
                url       => '/first_website/author/melody/2016/index.html',
                author_id => 1,
            },
        ],
        'Category-Daily' => [
            {   file_path =>
                    '/var/www/html/first_website/website-category-1/2011/01/01/index.html',
                startdate => '20110101000000',
                url =>
                    '/first_website/website-category-1/2011/01/01/index.html',
                category_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/website-category-1/website-subcategory-2/2012/02/02/index.html',
                startdate => '20120202000000',
                url =>
                    '/first_website/website-category-1/website-subcategory-2/2012/02/02/index.html',
                category_id => 2,
            },
            {   file_path =>
                    '/var/www/html/first_website/website-category-3/2013/03/03/index.html',
                startdate => '20130303000000',
                url =>
                    '/first_website/website-category-3/2013/03/03/index.html',
                category_id => 3,
            },
            {   file_path =>
                    '/var/www/html/first_website/website-category-1/website-subcategory-2/website-subsubcategory-5/2015/05/05/index.html',
                startdate => '20150505000000',
                url =>
                    '/first_website/website-category-1/website-subcategory-2/website-subsubcategory-5/2015/05/05/index.html',
                category_id => 5,
            },
            {   file_path =>
                    '/var/www/html/first_website/website-category-1/website-subcategory-2/website-subsubcategory-6/2016/06/06/index.html',
                startdate => '20160606000000',
                url =>
                    '/first_website/website-category-1/website-subcategory-2/website-subsubcategory-6/2016/06/06/index.html',
                category_id => 6,
            },
        ],
        'Category-Weekly' => [
            {   file_path =>
                    '/var/www/html/first_website/website-category-1/2010/12/26-week/index.html',
                startdate => '20101226000000',
                url =>
                    '/first_website/website-category-1/2010/12/26-week/index.html',
                category_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/website-category-1/website-subcategory-2/2012/01/29-week/index.html',
                startdate => '20120129000000',
                url =>
                    '/first_website/website-category-1/website-subcategory-2/2012/01/29-week/index.html',
                category_id => 2,
            },
            {   file_path =>
                    '/var/www/html/first_website/website-category-3/2013/03/03-week/index.html',
                startdate => '20130303000000',
                url =>
                    '/first_website/website-category-3/2013/03/03-week/index.html',
                category_id => 3,
            },
            {   file_path =>
                    '/var/www/html/first_website/website-category-1/website-subcategory-2/website-subsubcategory-5/2015/05/03-week/index.html',
                startdate => '20150503000000',
                url =>
                    '/first_website/website-category-1/website-subcategory-2/website-subsubcategory-5/2015/05/03-week/index.html',
                category_id => 5,
            },
            {   file_path =>
                    '/var/www/html/first_website/website-category-1/website-subcategory-2/website-subsubcategory-6/2016/06/05-week/index.html',
                startdate => '20160605000000',
                url =>
                    '/first_website/website-category-1/website-subcategory-2/website-subsubcategory-6/2016/06/05-week/index.html',
                category_id => 6,
            },
        ],
        'Category-Monthly' => [
            {   file_path =>
                    '/var/www/html/first_website/website-category-1/2011/01/index.html',
                startdate => '20110101000000',
                url => '/first_website/website-category-1/2011/01/index.html',
                category_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/website-category-1/website-subcategory-2/2012/02/index.html',
                startdate => '20120201000000',
                url =>
                    '/first_website/website-category-1/website-subcategory-2/2012/02/index.html',
                category_id => 2,
            },
            {   file_path =>
                    '/var/www/html/first_website/website-category-3/2013/03/index.html',
                startdate => '20130301000000',
                url => '/first_website/website-category-3/2013/03/index.html',
                category_id => 3,
            },
            {   file_path =>
                    '/var/www/html/first_website/website-category-1/website-subcategory-2/website-subsubcategory-5/2015/05/index.html',
                startdate => '20150501000000',
                url =>
                    '/first_website/website-category-1/website-subcategory-2/website-subsubcategory-5/2015/05/index.html',
                category_id => 5,
            },
            {   file_path =>
                    '/var/www/html/first_website/website-category-1/website-subcategory-2/website-subsubcategory-6/2016/06/index.html',
                startdate => '20160601000000',
                url =>
                    '/first_website/website-category-1/website-subcategory-2/website-subsubcategory-6/2016/06/index.html',
                category_id => 6,
            },
        ],
        'Category-Yearly' => [
            {   file_path =>
                    '/var/www/html/first_website/website-category-1/2011/index.html',
                startdate => '20110101000000',
                url => '/first_website/website-category-1/2011/index.html',
                category_id => 1,
            },
            {   file_path =>
                    '/var/www/html/first_website/website-category-1/website-subcategory-2/2012/index.html',
                startdate => '20120101000000',
                url =>
                    '/first_website/website-category-1/website-subcategory-2/2012/index.html',
                category_id => 2,
            },
            {   file_path =>
                    '/var/www/html/first_website/website-category-3/2013/index.html',
                startdate => '20130101000000',
                url => '/first_website/website-category-3/2013/index.html',
                category_id => 3,
            },
            {   file_path =>
                    '/var/www/html/first_website/website-category-1/website-subcategory-2/website-subsubcategory-5/2015/index.html',
                startdate => '20150101000000',
                url =>
                    '/first_website/website-category-1/website-subcategory-2/website-subsubcategory-5/2015/index.html',
                category_id => 5,
            },
            {   file_path =>
                    '/var/www/html/first_website/website-category-1/website-subcategory-2/website-subsubcategory-6/2016/index.html',
                startdate => '20160101000000',
                url =>
                    '/first_website/website-category-1/website-subcategory-2/website-subsubcategory-6/2016/index.html',
                category_id => 6,
            },
        ],
    );

    foreach my $key ( keys %suite ) {
        my $templatemap;
        if ( $key eq 'Monthly' ) {
            $templatemap = $tm_mo;
        }
        else {
            $templatemap = $mt->model('templatemap')->new;
            $templatemap->set_values(
                {   archive_type => $key,
                    blog_id      => $blog_id,
                    build_type   => MT::PublishOption::DYNAMIC(),
                    is_preferred => 1,
                    template_id  => $tm_mo->template_id,
                }
            );
            $templatemap->save or die $templatemap->errstr;
        }

        foreach my $data ( @{ $suite{$key} } ) {
            my $fi = $mt->model('fileinfo')->new;
            $fi->set_values(
                {   archive_type   => $key,
                    blog_id        => $blog_id,
                    template_id    => $templatemap->template_id,
                    templatemap_id => $templatemap->id,
                    virtual        => 1,
                }
            );
            foreach my $col ( keys %$data ) {
                $fi->$col( $data->{$col} );
            }
            $fi->save or die $fi->errstr;
        }
    }
}

{
    # Child blog
    my $b = $mt->model('blog')->new;
    $b->set_values(
        {   author_id => $admin->id,
            parent_id => $blog_id,
            name      => 'First Blog',
        }
    );
    $b->save or die $b->errstr;

    my $e1 = $mt->model('entry')->new;
    $e1->set_values(
        {   blog_id   => $b->id,
            author_id => $admin->id,
            status    => MT::Entry::RELEASE(),
            title     => 'Blog Entry 1',
        }
    );
    $e1->save or die $e1->errstr;
}

MT->request->reset;

run {
    my $block = shift;

SKIP:
    {
        skip $block->skip, 1 if $block->skip;

        my $tmpl = $app->model('template')->new;
        $tmpl->text( '<mt:Websites site_ids="'
                . $blog_id . '">'
                . $block->template
                . '</mt:Websites>' );
        my $ctx = $tmpl->context;

        $ctx->stash( 'builder', MT::Builder->new );
        $ctx->stash( 'user',    $admin );

        my $result = $tmpl->build;
        $result =~ s/^(\r\n|\r|\n|\s)+|(\r\n|\r|\n|\s)+\z//g;

        is( $result, $block->expected, $block->name );
    }
};

sub php_test_script {
    my ( $template, $text ) = @_;
    $text ||= '';

    my $test_script = <<PHP;
<?php
\$MT_HOME   = '@{[ $ENV{MT_HOME} ? $ENV{MT_HOME} : '.' ]}';
\$MT_CONFIG = '@{[ $app->find_config ]}';
\$tmpl = <<<__TMPL__
$template
__TMPL__
;
\$text = <<<__TMPL__
$text
__TMPL__
;
PHP
    $test_script .= <<'PHP';
include_once($MT_HOME . '/php/mt.php');
include_once($MT_HOME . '/php/lib/MTUtil.php');

$mt = MT::get_instance(1, $MT_CONFIG);
$mt->config('SupportDirectoryPath', './mt-static');
$mt->init_plugins();

$ctx =& $mt->context();

if ($ctx->_compile_source('evaluated template', $tmpl, $_var_compiled)) {
    $ctx->_eval('?>' . $_var_compiled);
} else {
    print('Error compiling template module.');
}

?>
PHP
}

SKIP:
{
    unless ( join( '', `php --version 2>&1` ) =~ m/^php/i ) {
        skip "Can't find executable file: php",
            1 * blocks('expected_dynamic');
    }

    run {
        my $block = shift;

    SKIP:
        {
            skip $block->skip, 1 if $block->skip;

            open2( my $php_in, my $php_out, 'php -q' );
            print $php_out &php_test_script(
                '<mt:Websites site_ids="'
                    . $blog_id . '">'
                    . $block->template
                    . '</mt:Websites>',
                $block->text
            );
            close $php_out;
            my $php_result = do { local $/; <$php_in> };
            $php_result =~ s/^(\r\n|\r|\n|\s)+|(\r\n|\r|\n|\s)+\z//g;

            my $name = $block->name . ' - dynamic';
            is( $php_result, $block->expected, $name );
        }
    };
}

__END__

=== mt:BlogIfCCLicense
--- template
<mt:BlogIfCCLicense>if<mt:Else>else</mt:BlogIfCCLicense>
--- expected
if

=== mt:BlogIfCommentsOpen
--- template
<mt:BlogIfCommentsOpen>if<mt:else>else</mt:BlogIfCommentsOpen>
--- expected
if

=== mt:BlogID
--- template
<mt:BlogID>
--- expected
1

=== mt:BlogName
--- template
<mt:BlogName>
--- expected
First Website

=== mt:BlogDescription
--- template
<mt:BlogDescription>
--- expected
This is a first website.

=== mt:BlogLanguage
--- template
<mt:BlogLanguage>
--- expected
en_US

=== mt:BlogURL
--- template
<mt:BlogURL>
--- expected
http://localhost/first_website/

=== mt:BlogArchiveURL
--- template
<mt:BlogArchiveURL>
--- expected
http://localhost/first_website/

=== mt:BlogRelativeURL
--- template
<mt:BlogRelativeURL>
--- expected
/first_website/

=== mt:BlogSitePath
--- template
<mt:BlogSitePath>
--- expected
/var/www/html/first_website/

=== mt:BlogHost
--- template
<mt:BlogHost>
--- expected
localhost

=== mt:BlogTimezone
--- template
<mt:BlogTimezone>
--- expected
+00:00

=== mt:BlogCCLicenseURL
--- template
<mt:BlogCCLicenseURL>
--- expected
http://creativecommons.org/licenses/by/3.0/

=== mt:BlogCCLicenseImage
--- template
<mt:BlogCCLicenseImage>
--- expected
http://i.creativecommons.org/l/by/3.0/88x31.png

=== mt:CCLicenseRDF
--- template
<mt:CCLicenseRDF>
--- expected
<!--
<rdf:RDF xmlns="http://web.resource.org/cc/"
         xmlns:dc="http://purl.org/dc/elements/1.1/"
         xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<Work rdf:about="http://localhost/first_website/">
<dc:title>First Website</dc:title>
<dc:description>This is a first website.</dc:description>
<license rdf:resource="http://creativecommons.org/licenses/by/3.0/" />
</Work>
<License rdf:about="http://creativecommons.org/licenses/by/3.0/">
</License>
</rdf:RDF>
-->

=== mt:BlogFileExtension
--- template
<mt:BlogFileExtension>
--- expected
.html

=== mt:BlogTemplateSetID
--- template
<mt:BlogTemplateSetID>
--- expected
classic-website

=== mt:BlogThemeID
--- template
<mt:BlogThemeID>
--- expected
classic-website

=== mt:EntriesHeader, mt:EntriesFooter
--- template
<mt:Entries><mt:EntriesHeader>EntriesHeader
</mt:EntriesHeader><mt:EntryTitle><mt:EntriesFooter>
EntriesFooter</mt:EntriesFooter>
</mt:Entries>
--- expected
EntriesHeader
Website Entry 7
Website Entry 6
Website Entry 5
Website Entry 3
Website Entry 2
Website Entry 1
EntriesFooter

=== mt:EntryPrevious
--- template
<mt:Entries><mt:EntryPrevious><mt:EntryBody>
</mt:EntryPrevious></mt:Entries>
--- expected
This is website entry 6.
This is website entry 5.
This is website entry 3.
This is website entry 2.
This is website entry 1.

=== mt:EntryNext
--- template
<mt:Entries><mt:EntryNext><mt:EntryBody>
</mt:EntryNext></mt:Entries>
--- expected
This is website entry 7.
This is website entry 6.
This is website entry 5.
This is website entry 3.
This is website entry 2.

=== mt:DateHeader
--- template
<mt:Entries><mt:DateHeader><mt:EntryDate format="%Y-%m-%d">
</mt:DateHeader><mt:EntryTitle><mt:DateFooter>
***</mt:DateFooter>
</mt:Entries>
--- expected
2016-06-06
Website Entry 7
Website Entry 6
***
2015-05-05
Website Entry 5
***
2013-03-03
Website Entry 3
***
2012-02-02
Website Entry 2
***
2011-01-01
Website Entry 1
***

=== mt:EntryIfExtended
--- template
<mt:Entries><mt:EntryIfExtended><mt:EntryMore>
</mt:EntryIfExtended></mt:Entries>
--- expected
Allow_pings is null, allow_comments is 1.
Allow_pings is 1, allow_comments is null.
Both allow_pings and allow_comments are null.

=== mt:AuthorHasEntry
--- template
<mt:Authors><mt:AuthorHasEntry><mt:AuthorName>
</mt:AuthorHasEntry></mt:Authors>
--- expected
Melody

=== mt:EntriesCount
--- template
<mt:EntriesCount>
--- expected
6

=== mt:Entries, mt:EntryID
--- template
<mt:Entries glue=" "><mt:EntryID></mt:Entries>
--- expected
7 6 5 3 2 1

=== mt:EntryTitle
--- template
<mt:Entries><mt:EntryTitle>
</mt:Entries>
--- expected
Website Entry 7
Website Entry 6
Website Entry 5
Website Entry 3
Website Entry 2
Website Entry 1

=== mt:EntryStatus
--- template
<mt:Entries glue=" "><mt:EntryStatus></mt:Entries>
--- expected
Publish Publish Publish Publish Publish Publish

=== mt:EntryFlag
--- template
<mt:Entries><mt:EntryFlag flag="allow_pings"> <mt:EntryFlag flag="allow_comments">
</mt:Entries>
--- expected
0 0
0 0
0 0
0 1
1 0
0 0

=== mt:EntryBody
--- template
<mt:Entries><mt:EntryBody>
</mt:Entries>
--- expected
This is website entry 7.
This is website entry 6.
This is website entry 5.
This is website entry 3.
This is website entry 2.
This is website entry 1.

=== mt:EntryMore
--- template
<mt:Entries><mt:EntryMore>
</mt:Entries>
--- expected
Allow_pings is null, allow_comments is 1.
Allow_pings is 1, allow_comments is null.
Both allow_pings and allow_comments are null.

=== mt:EntryExcerpt
--- template
<mt:Entries><mt:EntryExcerpt>
</mt:Entries>
--- expected
This is website entry 7....
This is website entry 6....
This is website entry 5....
Website Entry Excerpt 3
Website Entry Excerpt 2
Website Entry Excerpt 1

=== mt:EntryKeywords
--- template
<mt:Entries><mt:EntryKeywords> </mt:Entries>
--- expected
Bar  Foo

=== mt:EntryLink
--- template
<mt:Entries><mt:EntryLink>
</mt:Entries>
--- expected
http://localhost/first_website/2016/06/website-entry-7.html
http://localhost/first_website/2016/06/website-entry-6.html
http://localhost/first_website/2015/05/website-entry-5.html
http://localhost/first_website/2013/03/website-entry-3.html
http://localhost/first_website/2012/02/website-entry-2.html
http://localhost/first_website/2011/01/website-entry-1.html

=== mt:EntryBasename
--- template
<mt:Entries><mt:EntryBasename>
</mt:Entries>
--- expected
website_entry_7
website_entry_6
website_entry_5
website_entry_3
website_entry_2
website_entry_1

=== mt:EntryAtomID
--- template
<mt:Entries><mt:EntryAtomID>
</mt:Entries>
--- expected
tag:localhost,2016:/first_website//1.7
tag:localhost,2016:/first_website//1.6
tag:localhost,2015:/first_website//1.5
tag:localhost,2013:/first_website//1.3
tag:localhost,2012:/first_website//1.2
tag:localhost,2011:/first_website//1.1

=== mt:EntryPermalink
--- template
<mt:Entries><mt:EntryPermalink>
</mt:Entries>
--- expected
http://localhost/first_website/2016/06/website-entry-7.html
http://localhost/first_website/2016/06/website-entry-6.html
http://localhost/first_website/2015/05/website-entry-5.html
http://localhost/first_website/2013/03/website-entry-3.html
http://localhost/first_website/2012/02/website-entry-2.html
http://localhost/first_website/2011/01/website-entry-1.html

=== mt:EntryPermalink - Daily
--- template
<mt:Entries><mt:EntryPermalink archive_type="Daily">
</mt:Entries>
--- expected
http://localhost/first_website/2016/06/06/#000007
http://localhost/first_website/2016/06/06/#000006
http://localhost/first_website/2015/05/05/#000005
http://localhost/first_website/2013/03/03/#000003
http://localhost/first_website/2012/02/02/#000002
http://localhost/first_website/2011/01/01/#000001

=== mt:EntryPermalink - Weekly
--- template
<mt:Entries><mt:EntryPermalink archive_type="Weekly">
</mt:Entries>
--- expected
http://localhost/first_website/2016/06/05-week/#000007
http://localhost/first_website/2016/06/05-week/#000006
http://localhost/first_website/2015/05/03-week/#000005
http://localhost/first_website/2013/03/03-week/#000003
http://localhost/first_website/2012/01/29-week/#000002
http://localhost/first_website/2010/12/26-week/#000001

=== mt:EntryPermalink - Monthly
--- template
<mt:Entries><mt:EntryPermalink archive_type="Monthly">
</mt:Entries>
--- expected
http://localhost/first_website/2016/06/#000007
http://localhost/first_website/2016/06/#000006
http://localhost/first_website/2015/05/#000005
http://localhost/first_website/2013/03/#000003
http://localhost/first_website/2012/02/#000002
http://localhost/first_website/2011/01/#000001

=== mt:EntryPermalink - Yearly
--- template
<mt:Entries><mt:EntryPermalink archive_type="Yearly">
</mt:Entries>
--- expected
http://localhost/first_website/2016/#000007
http://localhost/first_website/2016/#000006
http://localhost/first_website/2015/#000005
http://localhost/first_website/2013/#000003
http://localhost/first_website/2012/#000002
http://localhost/first_website/2011/#000001

=== mt:EntryPermalink - Author
--- template
<mt:Entries><mt:EntryPermalink archive_type="Author">
</mt:Entries>
--- expected
http://localhost/first_website/author/melody/#000007
http://localhost/first_website/author/melody/#000006
http://localhost/first_website/author/melody/#000005
http://localhost/first_website/author/melody/#000003
http://localhost/first_website/author/melody/#000002
http://localhost/first_website/author/melody/#000001

=== mt:EntryPermalink - Author-Daily
--- template
<mt:Entries><mt:EntryPermalink archive_type="Author-Daily">
</mt:Entries>
--- expected
http://localhost/first_website/author/melody/2016/06/06/#000007
http://localhost/first_website/author/melody/2016/06/06/#000006
http://localhost/first_website/author/melody/2015/05/05/#000005
http://localhost/first_website/author/melody/2013/03/03/#000003
http://localhost/first_website/author/melody/2012/02/02/#000002
http://localhost/first_website/author/melody/2011/01/01/#000001

=== mt:EntryPermalink - Author-Weekly
--- template
<mt:Entries><mt:EntryPermalink archive_type="Author-Weekly">
</mt:Entries>
--- expected
http://localhost/first_website/author/melody/2016/06/05-week/#000007
http://localhost/first_website/author/melody/2016/06/05-week/#000006
http://localhost/first_website/author/melody/2015/05/03-week/#000005
http://localhost/first_website/author/melody/2013/03/03-week/#000003
http://localhost/first_website/author/melody/2012/01/29-week/#000002
http://localhost/first_website/author/melody/2010/12/26-week/#000001

=== mt:EntryPermalink - Author-Monthly
--- template
<mt:Entries><mt:EntryPermalink archive_type="Author-Monthly">
</mt:Entries>
--- expected
http://localhost/first_website/author/melody/2016/06/#000007
http://localhost/first_website/author/melody/2016/06/#000006
http://localhost/first_website/author/melody/2015/05/#000005
http://localhost/first_website/author/melody/2013/03/#000003
http://localhost/first_website/author/melody/2012/02/#000002
http://localhost/first_website/author/melody/2011/01/#000001

=== mt:EntryPermalink - Author-Yearly
--- template
<mt:Entries><mt:EntryPermalink archive_type="Author-Yearly">
</mt:Entries>
--- expected
http://localhost/first_website/author/melody/2016/#000007
http://localhost/first_website/author/melody/2016/#000006
http://localhost/first_website/author/melody/2015/#000005
http://localhost/first_website/author/melody/2013/#000003
http://localhost/first_website/author/melody/2012/#000002
http://localhost/first_website/author/melody/2011/#000001

=== mt:EntryPermalink - Category
--- template
<mt:Entries><mt:EntryIfCategory><mt:EntryPermalink archive_type="Category"></mt:EntryIfCategory>
</mt:Entries>
--- expected
http://localhost/first_website/website-category-1/website-subcategory-2/website-subsubcategory-6/#000006
http://localhost/first_website/website-category-1/website-subcategory-2/website-subsubcategory-5/#000005
http://localhost/first_website/website-category-3/#000003
http://localhost/first_website/website-category-1/website-subcategory-2/#000002
http://localhost/first_website/website-category-1/#000001

=== mt:EntryPermalink - Category-Daily
--- template
<mt:Entries><mt:EntryIfCategory><mt:EntryPermalink archive_type="Category-Daily"></mt:EntryIfCategory>
</mt:Entries>
--- expected
http://localhost/first_website/website-category-1/website-subcategory-2/website-subsubcategory-6/2016/06/06/#000006
http://localhost/first_website/website-category-1/website-subcategory-2/website-subsubcategory-5/2015/05/05/#000005
http://localhost/first_website/website-category-3/2013/03/03/#000003
http://localhost/first_website/website-category-1/website-subcategory-2/2012/02/02/#000002
http://localhost/first_website/website-category-1/2011/01/01/#000001

=== mt:EntryPermalink - Category-Weekly
--- template
<mt:Entries><mt:EntryIfCategory><mt:EntryPermalink archive_type="Category-Weekly"></mt:EntryIfCategory>
</mt:Entries>
--- expected
http://localhost/first_website/website-category-1/website-subcategory-2/website-subsubcategory-6/2016/06/05-week/#000006
http://localhost/first_website/website-category-1/website-subcategory-2/website-subsubcategory-5/2015/05/03-week/#000005
http://localhost/first_website/website-category-3/2013/03/03-week/#000003
http://localhost/first_website/website-category-1/website-subcategory-2/2012/01/29-week/#000002
http://localhost/first_website/website-category-1/2010/12/26-week/#000001

=== mt:EntryPermalink - Category-Monthly
--- template
<mt:Entries><mt:EntryIfCategory><mt:EntryPermalink archive_type="Category-Monthly"></mt:EntryIfCategory>
</mt:Entries>
--- expected
http://localhost/first_website/website-category-1/website-subcategory-2/website-subsubcategory-6/2016/06/#000006
http://localhost/first_website/website-category-1/website-subcategory-2/website-subsubcategory-5/2015/05/#000005
http://localhost/first_website/website-category-3/2013/03/#000003
http://localhost/first_website/website-category-1/website-subcategory-2/2012/02/#000002
http://localhost/first_website/website-category-1/2011/01/#000001

=== mt:EntryPermalink - Category-Yearly
--- template
<mt:Entries><mt:EntryIfCategory><mt:EntryPermalink archive_type="Category-Yearly"></mt:EntryIfCategory>
</mt:Entries>
--- expected
http://localhost/first_website/website-category-1/website-subcategory-2/website-subsubcategory-6/2016/#000006
http://localhost/first_website/website-category-1/website-subcategory-2/website-subsubcategory-5/2015/#000005
http://localhost/first_website/website-category-3/2013/#000003
http://localhost/first_website/website-category-1/website-subcategory-2/2012/#000002
http://localhost/first_website/website-category-1/2011/#000001

=== mt:EntryClass
--- template
<mt:Entries glue=" "><mt:EntryClass></mt:Entries>
--- expected
entry entry entry entry entry entry

=== mt:EntryClassLabel
--- template
<mt:Entries glue=" "><mt:EntryClassLabel></mt:Entries>
--- expected
Entry Entry Entry Entry Entry Entry

=== mt:EntryAuthor
--- template
<mt:Entries glue=" "><mt:EntryAuthor></mt:Entries>
--- expected
Melody Melody Melody Melody Melody Melody

=== mt:EntryAuthorDisplayName
--- template
<mt:Entries><mt:EntryAuthorDisplayName>
</mt:Entries>
--- expected
Administrator Melody
Administrator Melody
Administrator Melody
Administrator Melody
Administrator Melody
Administrator Melody

=== mt:EntryAuthorNickname
--- template
<mt:Entries><mt:EntryAuthorNickname>
</mt:Entries>
--- expected
Administrator Melody
Administrator Melody
Administrator Melody
Administrator Melody
Administrator Melody
Administrator Melody

=== mt:EntryAuthorUsername
--- template
<mt:Entries glue=" "><mt:EntryAuthorUsername></mt:Entries>
--- expected
Melody Melody Melody Melody Melody Melody

=== mt:EntryAuthorEmail
--- template
<mt:Entries><mt:EntryAuthorEmail>
</mt:Entries>
--- expected
melody@localhost
melody@localhost
melody@localhost
melody@localhost
melody@localhost
melody@localhost

=== mt:EntryAuthorURL
--- template
<mt:Entries><mt:EntryAuthorURL>
</mt:Entries>
--- expected
http://localhost/~melody/
http://localhost/~melody/
http://localhost/~melody/
http://localhost/~melody/
http://localhost/~melody/
http://localhost/~melody/

=== mt:EntryAuthorLink
--- template
<mt:Entries><mt:EntryAuthorLink>
</mt:Entries>
--- expected
<a href="http://localhost/~melody/">Administrator Melody</a>
<a href="http://localhost/~melody/">Administrator Melody</a>
<a href="http://localhost/~melody/">Administrator Melody</a>
<a href="http://localhost/~melody/">Administrator Melody</a>
<a href="http://localhost/~melody/">Administrator Melody</a>
<a href="http://localhost/~melody/">Administrator Melody</a>

=== mt:EntryAuthorID
--- template
<mt:Entries glue=" "><mt:EntryAuthorID></mt:Entries>
--- expected
1 1 1 1 1 1

=== mt:AuthorEntryCount
--- template
<mt:Entries glue=" "><mt:AuthorEntryCount></mt:Entries>
--- expected
6 6 6 6 6 6

=== mt:EntryDate
--- template
<mt:Entries><mt:EntryDate>
</mt:Entries>
--- expected
June  6, 2016  1:00 AM
June  6, 2016 12:00 AM
May  5, 2015 12:00 AM
March  3, 2013 12:00 AM
February  2, 2012 12:00 AM
January  1, 2011 12:00 AM

=== mt:EntryCreatedDate
--- template
<mt:Entries><mt:EntryCreatedDate>
</mt:Entries>
--- expected
June  6, 2016  1:00 AM
June  6, 2016 12:00 AM
May  5, 2015 12:00 AM
March  3, 2013 12:00 AM
February  2, 2012 12:00 AM
January  1, 2011 12:00 AM

=== mt:EntryModifiedDate
--- template
<mt:Entries><mt:EntryCreatedDate>
</mt:Entries>
--- expected
June  6, 2016  1:00 AM
June  6, 2016 12:00 AM
May  5, 2015 12:00 AM
March  3, 2013 12:00 AM
February  2, 2012 12:00 AM
January  1, 2011 12:00 AM

=== mt:EntryBlogID
--- template
<mt:Entries glue=" "><mt:EntryBlogID></mt:Entries>
--- expected
1 1 1 1 1 1

=== mt:EntryBlogName
--- template
<mt:Entries><mt:EntryBlogName>
</mt:Entries>
--- expected
First Website
First Website
First Website
First Website
First Website
First Website

=== mt:EntryBlogDescription
--- template
<mt:Entries><mt:EntryBlogDescription>
</mt:Entries>
--- expected
This is a first website.
This is a first website.
This is a first website.
This is a first website.
This is a first website.
This is a first website.

=== mt:EntryBlogURL
--- template
<mt:Entries><mt:EntryBlogURL>
</mt:Entries>
--- expected
http://localhost/first_website/
http://localhost/first_website/
http://localhost/first_website/
http://localhost/first_website/
http://localhost/first_website/
http://localhost/first_website/

=== mt:EntryEditLink
--- SKIP
--- template
<mt:Entries><mt:EntryEditLink>
</mt:Entries>
--- expected
[<a href="/cgi-bin/mt.cgi?__mode=view&_type=entry&blog_id=1&id=7">Edit</a>]
[<a href="/cgi-bin/mt.cgi?__mode=view&_type=entry&blog_id=1&id=6">Edit</a>]
[<a href="/cgi-bin/mt.cgi?__mode=view&_type=entry&blog_id=1&id=5">Edit</a>]
[<a href="/cgi-bin/mt.cgi?__mode=view&_type=entry&blog_id=1&id=3">Edit</a>]
[<a href="/cgi-bin/mt.cgi?__mode=view&_type=entry&blog_id=1&id=2">Edit</a>]
[<a href="/cgi-bin/mt.cgi?__mode=view&_type=entry&blog_id=1&id=1">Edit</a>]

=== mt:BlogEntryCount
--- template
<mt:BlogEntryCount>
--- expected
6

=== mt:Comments, mt:CommentBlogID
--- template
<mt:Comments><mt:CommentBlogID>
</mt:Comments>
--- expected
1
1
1

=== mt:BlogCommentCount
--- template
<mt:BlogCommentCount>
--- expected
3

=== mt:CommentEntry
--- template
<mt:Comments><mt:CommentEntry><mt:EntryTitle>
</mt:CommentEntry></mt:Comments>
--- expected
Website Entry 1
Website Entry 1
Website Entry 1

=== mt:EntryIfAllowComments
--- template
<mt:Entries><mt:EntryIfAllowComments>if
</mt:EntryIfAllowComments></mt:Entries>
--- expected
if

=== mt:EntryIfCommentsOpen
--- template
<mt:Entries><mt:EntryIfCommentsOpen>if
</mt:EntryIfCommentsOpen></mt:Entries>
--- expected
if

=== mt:IfCommenterIsEntryAuthor
--- template
<mt:Comments><mt:IfCommenterIsEntryAuthor>if
<mt:Else>else
</mt:IfCommenterIsEntryAuthor></mt:Comments>
--- expected
if
else
if

=== mt:CommentEntryID
--- template
<mt:Comments><mt:CommentEntryID>
</mt:Comments>
--- expected
1
1
1

=== mt:EntryCommentCount
--- template
<mt:Entries><mt:EntryCommentCount>
</mt:Entries>
--- expected
0
0
0
0
0
3

=== mt:EntryTrackbackCount
--- template
<mt:Entries><mt:EntryTrackbackCount>
</mt:Entries>
--- expected
0
0
0
0
1
0

=== mt:EntryTrackbackLink
--- template
<mt:Entries><mt:EntryTrackbackLink>
</mt:Entries>
--- expected
http://localhost/cgi-bin/mt-tb.cgi/2

=== mt:EntryTrackbackData
--- template
<mt:Entries><mt:EntryTrackbackData>
</mt:Entries>
--- expected
<!--
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:trackback="http://madskills.com/public/xml/rss/module/trackback/"
         xmlns:dc="http://purl.org/dc/elements/1.1/">
<rdf:Description
    rdf:about="http://localhost/first_website/2012/02/website-entry-2.html"
    trackback:ping="http://localhost/cgi-bin/mt-tb.cgi/2"
    dc:title="Website Entry 2"
    dc:identifier="http://localhost/first_website/2012/02/website-entry-2.html"
    dc:subject="Website Subcategory 2"
    dc:description="Website Entry Excerpt 2"
    dc:creator="Administrator Melody"
    dc:date="2012-02-02T00:00:00+00:00" />
</rdf:RDF>
-->

=== mt:EntryTrackbackID
--- template
<mt:Entries><mt:EntryTrackbackID>
</mt:Entries>
--- expected
2

=== mt:PingBlogName
--- template
<mt:Pings><mt:PingBlogName>
</mt:Pings>
--- expected
first website
first website

=== mt:BlogPingCount
--- template
<mt:BlogPingCount>
--- expected
2

=== mt:PingEntry
--- template
<mt:Pings><mt:PingEntry><mt:EntryBody>
</mt:PingEntry></mt:Pings>
--- expected
This is website entry 2.

=== mt:EntryIfAllowPings
--- template
<mt:Entries><mt:EntryIfAllowPings>if
</mt:EntryIfAllowPings></mt:Entries>
--- expected
if

=== mt:CategoryIfAllowPings
--- template
<mt:Categories glue=" "><mt:CategoryIfAllowPings>if
</mt:CategoryIfAllowPings></mt:Categories>
--- expected
if

=== mt:Categories, mt:CategoryID
--- template
<mt:Categories glue=" "><mt:CategoryID></mt:Categories>
--- expected
1 3 4 2 5 6

=== mt:CategoryPrevious
--- template
<mt:Categories><mt:CategoryPrevious><mt:CategoryLabel>
</mt:CategoryPrevious></mt:Categories>
--- expected
Website Category 1
Website Category 3
Website Subsubcategory 5

=== mt:CategoryNext
--- template
<mt:Categories><mt:CategoryNext><mt:CategoryLabel>
</mt:CategoryNext></mt:Categories>
--- expected
Website Category 3
Website Category 4
Website Subsubcategory 6

=== mt:SubCategories
--- template
<mt:Categories><mt:SubCategories><mt:CategoryBasename>
</mt:SubCategories></mt:Categories>
--- expected
website_subcategory_2
website_subsubcategory_5
website_subsubcategory_6

=== mt:TopLevelCategories
--- template
<mt:TopLevelCategories><mt:CategoryDescription>
</mt:TopLevelCategories>
--- expected
This is a website category 1.
This is a website category 3.
This is a website category 4.

=== mt:ParentCategory
--- template
<mt:Categories><mt:SubCategories><mt:ParentCategory><mt:CategoryLabel>
</mt:ParentCategory></mt:SubCategories></mt:Categories>
--- expected
Website Category 1
Website Subcategory 2
Website Subcategory 2

=== mt:ParentCategories
--- template
<mt:Categories><mt:SubCategories><mt:ParentCategories glue=" "><mt:CategoryBasename></mt:ParentCategories>
</mt:SubCategories></mt:Categories>
--- expected
website_category_1 website_subcategory_2
website_category_1 website_subcategory_2 website_subsubcategory_5
website_category_1 website_subcategory_2 website_subsubcategory_6

=== mt:TopLevelParent
--- template
<mt:TopLevelCategories><mt:SubCategories><mt:TopLevelParent><mt:CategoryLabel>
</mt:TopLevelParent></mt:SubCategories></mt:TopLevelCategories>
--- expected
Website Category 1

=== mt:EntriesWithSubCategories
--- template
<mt:Entries category="Website Category 1"><mt:EntryCategories glue=" | "><mt:CategoryLabel></mt:EntryCategories>
</mt:Entries>
<mt:EntriesWithSubCategories category="Website Category 1"><mt:EntryCategories glue=" | "><mt:CategoryLabel></mt:EntryCategories>
</mt:EntriesWithSubCategories>
--- expected
Website Category 1 | Website Category 4

Website Subsubcategory 6
Website Subsubcategory 5
Website Subcategory 2
Website Category 1 | Website Category 4

=== mt:IfCategory
--- template
<mt:Categories><mt:IfCategory label="Website Subcategory 2"><mt:CategoryLabel></mt:IfCategory></mt:Categories>
--- expected
Website Subcategory 2

=== mt:EntryIfCategory
--- template
<mt:Entries><mt:EntryIfCategory name="Website Subcategory 2"><mt:EntryTitle></mt:EntryIfCategory></mt:Entries>
--- expected
Website Entry 2

=== mt:SubCatIsFirst
--- template
<mt:Categories><mt:SubCategories><mt:SubCatIsFirst><mt:CategoryLabel>
</mt:SubCatIsFirst></mt:SubCategories></mt:Categories>
--- expected
Website Subcategory 2
Website Subsubcategory 5

=== mt:SubCatIsLast
--- template
<mt:Categories><mt:SubCategories><mt:SubCatIsLast><mt:CategoryBasename>
</mt:SubCatIsLast></mt:SubCategories></mt:Categories>
--- expected
website_subcategory_2
website_subsubcategory_6

=== mt:HasSubCategories
--- template
<mt:Categories><mt:HasSubCategories><mt:CategoryLabel>
</mt:HasSubCategories></mt:Categories>
--- expected
Website Category 1
Website Subcategory 2

=== mt:HasNoSubCategories
--- template
<mt:Categories><mt:HasNoSubCategories><mt:CategoryBasename>
</mt:HasNoSubCategories></mt:Categories>
--- expected
website_category_3
website_category_4
website_subsubcategory_5
website_subsubcategory_6

=== mt:HasParentCategory
--- template
<mt:Categories><mt:HasParentCategory><mt:CategoryLabel>
</mt:HasParentCategory></mt:Categories>
--- expected
Website Subcategory 2
Website Subsubcategory 5
Website Subsubcategory 6

=== mt:HasNoParentCategory
--- template
<mt:Categories><mt:HasNoParentCategory><mt:CategoryBasename>
</mt:HasNoParentCategory></mt:Categories>
--- expected
website_category_1
website_category_3
website_category_4

=== mt:IfIsAncestor
--- template
<mt:Categories><mt:IfIsAncestor child="Website Subcategory 2"><mt:CategoryLabel>
</mt:IfIsAncestor></mt:Categories>
--- expected
Website Category 1
Website Subcategory 2

=== mt:IfIsDescendant
--- template
<mt:Categories><mt:IfIsDescendant parent="Website Category 1"><mt:CategoryBasename>
</mt:IfIsDescendant></mt:Categories>
--- expected
website_category_1
website_subcategory_2
website_subsubcategory_5
website_subsubcategory_6

=== mt:EntryCategories
--- template
<mt:Entries><mt:EntryCategories glue=" | "><mt:CategoryLabel></mt:EntryCategories>
</mt:Entries>
--- expected
Website Subsubcategory 6
Website Subsubcategory 5
Website Category 3
Website Subcategory 2
Website Category 1 | Website Category 4

=== mt:EntryPrimaryCategory
--- template
<mt:Entries><mt:EntryPrimaryCategory><mt:CategoryBasename>
</mt:EntryPrimaryCategory></mt:Entries>
--- expected
website_subsubcategory_6
website_subsubcategory_5
website_category_3
website_subcategory_2
website_category_1

=== mt:EntryAdditionalCategories
--- template
<mt:Entries><mt:EntryAdditionalCategories><mt:CategoryLabel>
</mt:EntryAdditionalCategories></mt:Entries>
--- expected
Website Category 4

=== mt:CategoryLabel
--- template
<mt:Categories><mt:CategoryLabel>
</mt:Categories>
--- expected
Website Category 1
Website Category 3
Website Category 4
Website Subcategory 2
Website Subsubcategory 5
Website Subsubcategory 6

=== mt:CategoryBasename
--- template
<mt:Categories><mt:CategoryBasename>
</mt:Categories>
--- expected
website_category_1
website_category_3
website_category_4
website_subcategory_2
website_subsubcategory_5
website_subsubcategory_6

=== mt:CategoryDescription
--- template
<mt:Categories><mt:CategoryDescription>
</mt:Categories>
--- expected
This is a website category 1.
This is a website category 3.
This is a website category 4.
This is a website subcategory 2.
This is a website subsubcategory 5.
This is a website subsubcategory 6.

=== mt:CategoryArchiveLink
--- template
<mt:Categories><mt:CategoryArchiveLink>
</mt:Categories>
--- expected
http://localhost/first_website/website-category-1/
http://localhost/first_website/website-category-3/
http://localhost/first_website/website-category-4/
http://localhost/first_website/website-category-1/website-subcategory-2/
http://localhost/first_website/website-category-1/website-subcategory-2/website-subsubcategory-5/
http://localhost/first_website/website-category-1/website-subcategory-2/website-subsubcategory-6/

=== mt:CategoryCount
--- template
<mt:Categories glue=" "><mt:CategoryCount></mt:Categories>
--- expected
1 1 1 1 1 1

=== mt:SubCatsRecurse
--- template
<mt:TopLevelCategories><mt:CategoryLabel>
<mt:SubCatsRecurse></mt:TopLevelCategories>
--- expected
Website Category 1
Website Subcategory 2
Website Subsubcategory 5
Website Subsubcategory 6
Website Category 3
Website Category 4

=== mt:SubCategoryPath
--- template
<mt:Categories><mt:SubCategoryPath>
</mt:Categories>
--- expected
website_category_1
website_category_3
website_category_4
website_category_1/website_subcategory_2
website_category_1/website_subcategory_2/website_subsubcategory_5
website_category_1/website_subcategory_2/website_subsubcategory_6

=== mt:BlogCategoryCount
--- template
<mt:BlogCategoryCount>
--- expected
6

=== mt:ArchiveCategory
--- template
<mt:Categories><mt:ArchiveCategory>
</mt:Categories>
--- expected
Website Category 1
Website Category 3
Website Category 4
Website Subcategory 2
Website Subsubcategory 5
Website Subsubcategory 6

=== mt:EntryCategory
--- template
<mt:Entries><mt:EntryCategory>
</mt:Entries>
--- expected
Website Subsubcategory 6
Website Subsubcategory 5
Website Category 3
Website Subcategory 2
Website Category 1

=== mt:CategoryCommentCount
--- template
<mt:Categories><mt:CategoryCommentCount>
</mt:Categories>
--- expected
3
0
3
0
0
0

=== mt:CategoryTrackbackLink
--- template
<mt:Categories><mt:CategoryTrackbackLink>
</mt:Categories>
--- expected
http://localhost/cgi-bin/mt-tb.cgi/1

=== mt:CategoryTrackbackCount
--- template
<mt:Categories><mt:CategoryTrackbackCount>
</mt:Categories>
--- expected
1
0
0
0
0
0

=== mt:EntryAssets
--- template
<mt:Entries><mt:EntryAssets>ID:<mt:EntryID> / <mt:AssetLabel>
</mt:EntryAssets></mt:Entries>
--- expected
ID:1 / Website Asset 1

=== mt:EntryAuthorUserpicAsset
--- template
<mt:Entries><mt:EntryAuthorUserpicAsset><mt:AssetLabel>
</mt:EntryAuthorUserpicAsset></mt:Entries>
--- expected
Userpic
Userpic
Userpic
Userpic
Userpic
Userpic

=== mt:EntryAuthorUserpic
--- SKIP
--- template
<mt:Entries><mt:EntryAuthorUserpic>
</mt:Entries>
--- expected
<img src="/mt-static/support/assets_c/userpics/userpic-1-100x100.png?1" width="25" height="25" alt="" />
<img src="/mt-static/support/assets_c/userpics/userpic-1-100x100.png?1" width="25" height="25" alt="" />
<img src="/mt-static/support/assets_c/userpics/userpic-1-100x100.png?1" width="25" height="25" alt="" />
<img src="/mt-static/support/assets_c/userpics/userpic-1-100x100.png?1" width="25" height="25" alt="" />
<img src="/mt-static/support/assets_c/userpics/userpic-1-100x100.png?1" width="25" height="25" alt="" />
<img src="/mt-static/support/assets_c/userpics/userpic-1-100x100.png?1" width="25" height="25" alt="" />

=== mt:EntryAuthorUserpicURL
--- template
<mt:Entries><mt:EntryAuthorUserpicURL>
</mt:Entries>
--- expected
/mt-static/support/assets_c/userpics/userpic-1-100x100.png
/mt-static/support/assets_c/userpics/userpic-1-100x100.png
/mt-static/support/assets_c/userpics/userpic-1-100x100.png
/mt-static/support/assets_c/userpics/userpic-1-100x100.png
/mt-static/support/assets_c/userpics/userpic-1-100x100.png
/mt-static/support/assets_c/userpics/userpic-1-100x100.png

=== mt:EntryTags
--- template
<mt:Entries><mt:EntryTags><mt:TagName>
</mt:EntryTags></mt:Entries>
--- expected
Website Tag 1

=== mt:EntryIfTagged
--- template
<mt:Entries><mt:EntryIfTagged><mt:EntryTitle>
</mt:EntryIfTagged></mt:Entries>
--- expected
Website Entry 1

=== mt:EntryScore
--- template
<mt:Entries><mt:EntryScore namespace="test_namespace">
</mt:Entries>
--- expected
0
0
0
0
0
6

=== mt:EntryScoreHigh
--- template
<mt:Entries><mt:EntryScoreHigh namespace="test_namespace">
</mt:Entries>
--- expected
0
0
0
0
0
4

=== mt:EntryScoreLow
--- template
<mt:Entries><mt:EntryScoreLow namespace="test_namespace">
</mt:Entries>
--- expected
0
0
0
0
0
2

=== mt:EntryScoreAvg
--- template
<mt:Entries><mt:EntryScoreAvg namespace="test_namespace">
</mt:Entries>
--- expected
0
0
0
0
0
3.00

=== mt:EntryScoreCount
--- template
<mt:Entries><mt:EntryScoreCount namespace="test_namespace">
</mt:Entries>
--- expected
0
0
0
0
0
2

=== mt:EntryRank
--- template
<mt:Entries><mt:EntryRank namespace="test_namespace">
</mt:Entries>
--- expected
5

=== mt:IfExternalUserManagement
--- template
<mt:IfExternalUserManagement>if<mt:Else>else</mt:IfExternalUserManagement>
--- expected
else

=== mt:IfCommenterRegistrationAllowed
--- template
<mt:IfCommenterRegistrationAllowed>if</mt:IfCommenterRegistrationAllowed>
--- expected
if

=== mt:IfCommenterTrusted
--- template
<mt:Comments><mt:IfCommenterTrusted><mt:CommenterName>
<mt:Else>else
</mt:IfCommenterTrusted></mt:Comments>
--- expected
Administrator Melody
Guest
Administrator Melody

=== mt:CommenterIfTrusted
--- template
<mt:Comments><mt:CommenterIfTrusted><mt:CommenterName>
<mt:Else>else
</mt:CommenterIfTrusted></mt:Comments>
--- expected
Administrator Melody
Guest
Administrator Melody

=== mt:CommenterIsAuthor
--- template
<mt:Comments><mt:IfCommenterIsAuthor><mt:CommenterName>
<mt:Else>else
</mt:IfCommenterIsAuthor></mt:Comments>
--- expected
Administrator Melody
Guest
Administrator Melody

=== mt:IfCommentsModerated
--- template
<mt:IfCommentsModerated>if<mt:Else>else</mt:IfCommentsModerated>
--- expected
if

=== mt:BlogIfCommentsOpen
--- template
<mt:BlogIfCommentsOpen>if<mt:Else>else</mt:BlogIfCommentsOpen>
--- expected
if

=== mt:WebsiteIfCommentsOpen
--- template
<mt:WebsiteIfCommentsOpen>if<mt:Else>else</mt:WebsiteIfCommentsOpen>
--- expected
if

=== mt:CommentsHeader, mt:CommentsFooter
--- template
<mt:Comments><mt:CommentsHeader>-- header --
</mt:CommentsHeader><mt:CommentName>
<mt:CommentsFooter>-- footer --
</mt:CommentsFooter></mt:Comments>
--- expected
-- header --
Administrator Melody
Guest
Administrator Melody
-- footer --

=== mt:CommentIfModerated
--- template
<mt:Comments><mt:CommentIfModerated>if<mt:Else>else</mt:CommentIfModerated>
</mt:Comments>
--- expected
else
else
else

=== mt:CommentParent
--- template
<mt:Comments><mt:CommentParent><mt:CommentName></mt:CommentParent>
</mt:Comments>
--- expected
Administrator Melody
Guest

=== mt:CommentReplies
--- template
<mt:Comments><mt:CommentReplies><mt:CommentName></mt:CommentReplies>
</mt:Comments>
--- expected
Guest
Administrator Melody

=== mt:IfCommentParent
--- template
<mt:Comments><mt:IfCommentParent>if<mt:Else>else</mt:IfCommentParent>
</mt:Comments>
--- expected
else
if
if

=== mt:IfCommentReplies
--- template
<mt:Comments><mt:IfCommentReplies>if<mt:Else>else</mt:IfCommentReplies>
</mt:Comments>
--- expected
if
if
else

=== mt:IfRegistrationRequired
--- template
<mt:IfRegistrationRequired>required<mt:Else>not required</mt:IfRegistrationRequired>
--- expected
not required

=== mt:IfRegistrationNotRequired
--- template
<mt:IfRegistrationNotRequired>not required<mt:Else>required</mt:IfRegistrationNotRequired>
--- expected
not required

=== mt:IfRegistrationAllowed
--- template
<mt:IfRegistrationAllowed>allowed<mt:Else>not allowed</mt:IfRegistrationAllowed>
--- expected
allowed

=== mt:IfTypeKeyToken
--- template
<mt:IfTypeKeyToken>if<mt:Else>else</mt:IfTypeKeyToken>
--- expected
if

=== mt:IfAllowCommentHTML
--- template
<mt:IfAllowCommentHTML>if<mt:Else>else</mt:IfAllowCommentHTML>
--- expected
if

=== mt:IfCommentsAllowed
--- template
<mt:IfCommentsAllowed>if<mt:Else>else</mt:IfCommentsAllowed>
--- expected
if

=== mt:IfCommentsAccepted
--- template
<mt:IfCommentsAccepted>if<mt:Else>else</mt:IfCommentsAccepted>
--- expected
if

=== mt:IfCommentsActive
--- template
<mt:IfCommentsActive>if<mt:Else>else</mt:IfCommentsActive>
--- expected
if

=== mt:IfNeedEmail
--- template
<mt:IfNeedEmail>if<mt:Else>else</mt:IfNeedEmail>
--- expected
else

=== mt:IfRequireCommentEmails
--- template
<mt:IfRequireCommentEmails>if<mt:Else>else</mt:IfRequireCommentEmails>
--- expected
else

=== mt:CommentID, mt:CommenterUserpicAsset
--- template
<mt:Comments><mt:CommentID>: <mt:CommenterUserpicAsset><mt:AssetLabel></mt:CommenterUserpicAsset>
</mt:Comments>
--- expected
1: Userpic
2: 
3: Userpic

=== mt:AuthorCommentCount
--- SKIP
--- template
<mt:Authors><mt:AuthorCommentCount>
</mt:Authors>
--- expected
1

=== mt:CommenterNameChunk
--- SKIP
--- template
<mt:Comments><mt:CommenterNameChunk>
</mt:Comments>
--- expected
(no php code)

=== mt:CommenterUsername
--- template
<mt:Comments><mt:CommenterUsername>
</mt:Comments>
--- expected
Melody
Guest
Melody

=== mt:CommenterName
--- template
<mt:Comments><mt:CommenterName>
</mt:Comments>
--- expected
Administrator Melody
Guest
Administrator Melody

=== mt:CommenterEmail
--- template
<mt:Comments><mt:CommenterEmail>
</mt:Comments>
--- expected
melody@localhost
guest@localhost
melody@localhost

=== mt:CommenterAuthType
--- template
<mt:Comments><mt:CommenterAuthType>
</mt:Comments>
--- expected
MT

MT

=== mt:CommenterAuthIconURL
--- template
<mt:Comments><mt:CommenterAuthIconURL>
</mt:Comments>
--- expected
http://localhost/mt-static/images/comment/mt_logo.png

http://localhost/mt-static/images/comment/mt_logo.png

=== mt:CommenterID
--- template
<mt:Comments><mt:CommenterID>
</mt:Comments>
--- expected
1
2
1

=== mt:CommenterURL
--- template
<mt:Comments><mt:CommenterURL>
</mt:Comments>
--- expected
http://localhost/~melody/
http://localhost/~guest/
http://localhost/~melody/

=== mt:UserSessionState
--- SKIP
--- template
<mt:UserSessionState>
--- expected
(no php code)

=== mt:UserSessionCookieTimeout
--- template
<mt:UserSessionCookieTimeout>
--- expected
14400

=== mt:UserSessionCookieName
--- template
<mt:UserSessionCookieName>
--- expected
mt_blog_user

=== mt:UserSessionCookiePath
--- template
<mt:UserSessionCookiePath>
--- expected
/

=== mt:UserSessionCookieDomain
--- template
<mt:UserSessionCookieDomain>
--- expected
.localhost

=== mt:CommentName
--- template
<mt:Comments><mt:CommentName>
</mt:Comments>
--- expected
Administrator Melody
Guest
Administrator Melody

=== mt:CommentIP
--- template
<mt:Comments><mt:CommentIP>
</mt:Comments>
--- expected
127.0.0.1
192.168.0.1
127.0.0.1

=== mt:CommentAuthor
--- template
<mt:Comments><mt:CommentAuthor>
</mt:Comments>
--- expected
Administrator Melody
Guest
Administrator Melody

=== mt:CommentAuthorLink
--- template
<mt:Comments><mt:CommentAuthorLink>
</mt:Comments>
--- expected
<a title="http://localhost/~melody/" href="http://localhost/~melody/">Administrator Melody</a>
<a title="http://localhost/~guest/" href="http://localhost/~guest/">Guest</a>
<a title="http://localhost/~melody/" href="http://localhost/~melody/">Administrator Melody</a>

=== mt:CommentAuthorIdentity
--- template
<mt:Comments><mt:CommentAuthorIdentity>
</mt:Comments>
--- expected
<a class="commenter-profile" href="http://localhost/~melody/"><img alt="" src="http://localhost/mt-static/images/comment/mt_logo.png" width="16" height="16" /></a>
<a class="commenter-profile" href="http://localhost/~guest/"><img alt="" src="http://localhost/mt-static/images/nav-commenters.gif" width="16" height="16" /></a>
<a class="commenter-profile" href="http://localhost/~melody/"><img alt="" src="http://localhost/mt-static/images/comment/mt_logo.png" width="16" height="16" /></a>

=== mt:CommentEmail
--- template
<mt:Comments><mt:CommentEmail>
</mt:Comments>
--- expected
melody@localhost
guest@localhost
melody@localhost

=== mt:CommentLink
--- template
<mt:Comments><mt:CommentLink>
</mt:Comments>
--- expected
http://localhost/first_website/2011/01/website-entry-1.html#comment-1
http://localhost/first_website/2011/01/website-entry-1.html#comment-2
http://localhost/first_website/2011/01/website-entry-1.html#comment-3

=== mt:CommentURL
--- template
<mt:Comments><mt:CommentURL>
</mt:Comments>
--- expected
http://localhost/~melody/
http://localhost/~guest/
http://localhost/~melody/

=== mt:CommentBody
--- template
<mt:Comments><mt:CommentBody>
</mt:Comments>
--- expected
<p>Comment 1</p>
<p>Comment 2</p>
<p>Comment 3</p>

=== mt:CommentOrderNumber
--- template
<mt:Comments><mt:CommentOrderNumber>
</mt:Comments>
--- expected
1
2
3

=== mt:CommentDate
--- template
<mt:Comments><mt:CommentDate>
</mt:Comments>
--- expected
October 10, 2010 12:00 AM
November 11, 2011 12:00 AM
December 12, 2012 12:00 AM

=== mt:CommentParentID
--- template
<mt:Comments><mt:CommentParentID>
</mt:Comments>
--- expected
1
2

=== mt:CommentReplyToLink
--- template
<mt:Comments><mt:CommentReplyToLink>
</mt:Comments>
--- expected
<a title="Reply" href="javascript:void(0);" onclick="mtReplyCommentOnClick(1, 'Administrator Melody')">Reply</a>
<a title="Reply" href="javascript:void(0);" onclick="mtReplyCommentOnClick(2, 'Guest')">Reply</a>
<a title="Reply" href="javascript:void(0);" onclick="mtReplyCommentOnClick(3, 'Administrator Melody')">Reply</a>

=== mt:CommentPreviewAuthor
--- SKIP
--- template
<mt:Comments><mt:CommentPreviewAuthor>
</mt:Comments>
--- expected
(no php code)

=== mt:CommentPreviewIP
--- SKIP
--- template
<mt:Comments><mt:CommentPreviewIP>
</mt:Comments>
--- expected
(no php code)

=== mt:CommentPreviewAuthorLink
--- SKIP
--- template
--- expected

=== mt:CommentPreviewEmail
--- SKIP
--- template
--- expected

=== mt:CommentPreviewURL
--- SKIP
--- template
--- expected

=== mt:CommentPreviewBody
--- SKIP
--- template
--- expected

=== mt:CommentPreviewDate
--- SKIP
--- template
--- expected

=== mt:CommentPreviewState
--- SKIP
--- template
--- expected

=== mt:CommentPreviewIsStatic
--- SKIP
--- template
--- expected

=== mt:CommentRepliesRecurse
--- template
<mt:Comments><mt:CommentReplies><mt:CommentName>
<mt:CommentRepliesRecurse></mt:CommentReplies></mt:Comments>
--- expected
Guest
Administrator Melody
Administrator Melody

=== mt:WebsiteCommentCount
--- template
<mt:WebsiteCommentCount>
--- expected
3

=== mt:TypeKeyToken
--- template
<mt:TypeKeyToken>
--- expected
token

=== mt:CommentFields
--- SKIP
--- template
<mt:CommentFields>
--- expected
(deprecated)

=== mt:RemoteSignOutLink
--- SKIP
--- template
<mt:RemoteSignOutLink>
--- expected
(deprecated)

=== mt:RemoteSignInLink
--- SKIP
--- template
<mt:RemoteSignInLink>
--- expected
(deprecated)

=== mt:SignOutLink
--- SKIP
--- template
<mt:SignOutLink>
--- expected
http://localhost/cgi-bin/mt-cp.cgi?__mode=logout&static=0&blog_id=1

=== mt:SignInLink
--- SKIP
--- template
<mt:SignInLink>
--- expected
http://localhost/cgi-bin/mt-cp.cgi?__mode=login&blog_id=1

=== mt:SignOnURL
--- SKIP
--- template
<mt:SignOnURL>
--- expected
https://www.typekey.com/t/typekey/login?

=== mt:CommenterUserpic
--- SKIP
--- template
<mt:Comments><mt:CommenterUserpic>
</mt:Comments>
--- expected
<img src="/mt-static/support/assets_c/userpics/userpic-1-100x100.png?1" width="100" height="100" alt="" />

<img src="/mt-static/support/assets_c/userpics/userpic-1-100x100.png?1" width="100" height="100" alt="" />

=== mt:CommenterUserpicURL
--- template
<mt:Comments><mt:CommenterUserpicURL>
</mt:Comments>
--- expected
/mt-static/support/assets_c/userpics/userpic-1-100x100.png

/mt-static/support/assets_c/userpics/userpic-1-100x100.png

=== mt:CommentScore
--- template
<mt:Comments><mt:CommentScore namespace="test_namespace">
</mt:Comments>
--- expected
4
0
0

=== mt:CommentScoreHigh
--- template
<mt:Comments><mt:CommentScoreHigh namespace="test_namespace">
</mt:Comments>
--- expected
3
0
0

=== mt:CommentScoreLow
--- template
<mt:Comments><mt:CommentScoreLow namespace="test_namespace">
</mt:Comments>
--- expected
1
0
0

=== mt:CommentScoreAvg
--- template
<mt:Comments><mt:CommentScoreAvg namespace="test_namespace">
</mt:Comments>
--- expected
2.00
0
0

=== mt:CommentScoreCount
--- template
<mt:Comments><mt:CommentScoreCount namespace="test_namespace">
</mt:Comments>
--- expected
2
0
0

=== mt:CommentRank
--- template
<mt:Comments><mt:CommentRank namespace="test_namespace">
</mt:Comments>
--- expected
5


