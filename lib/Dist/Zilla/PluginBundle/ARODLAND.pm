package Dist::Zilla::PluginBundle::ARODLAND;
use 5.10.0;
use Moose;
with 'Dist::Zilla::PluginBundle';

use Dist::Zilla::PluginBundle::Basic;
use Dist::Zilla::PluginBundle::Git;
use Dist::Zilla::Plugin::Authority;
use Dist::Zilla::Plugin::MetaNoIndex;
use Dist::Zilla::Plugin::AutoVersion;

sub bundle_config {
  my ($self, $section) = @_;

  my $config = $section->{payload};

  my $dist = $config->{dist} // die "You must supply a dist name\n";
  my $github_user = $config->{github_user} // "arodland";

  my $authority = $config->{authority} // "cpan:ARODLAND";
  my $bugtracker = $config->{bugtracker} // "rt";
  my $homepage = $config->{homepage};
  my $repository_url = $config->{repository_url};
  my $repository_web = $config->{repository_web};

  my $no_a_pre = $config->{no_Autoprereq} // 0;
  my $nextrelease_format = $config->{nextrelease_format} // "Version %v: %{yyyy-MM-dd}d";

  my $nextversion = $config->{nextversion} // "git"; # git, autoversion, manual
  my $tag_message = $config->{git_tag_message};
  my $version_regexp = $config->{git_version_regexp};
  my $autoversion_major = $config->{autoversion_major};

  my ($tracker, $tracker_mailto, $webpage, $repo_url, $repo_web);

  given ($bugtracker) {
    when ('github') {
      $tracker = "http://github.com/$github_user/$dist/issues";
    }
    when ('rt') {
      $tracker = "https://rt.cpan.org/Public/Dist/Display.html?Name=$dist";
      $tracker_mailto = "bug-${dist}\@rt.cpan.org";
    }
    default {
      $tracker = $bugtracker;
    }
  }

  given ($repository_url) {
    when (not defined) {
      $repo_web = "http://github.com/$github_user/$dist";
      $repo_url = "git://github.com/$github_user/$dist.git";
    }
    default {
      $repo_web = $repository_web;
      $repo_url = $repository_url;
    }
  }

  given ($homepage) {
    when (not defined) {
      $webpage = "http://metacpan.org/release/$dist";
    } default {
      $page = $homepage;
    }
  }

  my @plugins = Dist::Zilla::PluginBundle::Basic->bundle_config({
      name => $section->{name} . '/@Basic',
      payload => { },
  });

  my $prefix = 'Dist::Zilla::Plugin::';
  my @extra = map {[ "$section->{name}/$_->[0]" => "$prefix$_->[0]" => $_->[1] ]}
  (
    ($no_a_pre
      ? ()
      : ([ AutoPrereqs => { } ])
    ),
    [ PkgVersion => { } ],
    [ MetaJSON => { } ],
    [
      MetaNoIndex => {
        # Ignore these if they're there
        directory => [ map { -d $_ ? $_ : () } qw( inc t xt utils example examples ) ],
      }
    ],
    [
      MetaResources => {
        homepage => $page,
        'bugtracker.web' => $tracker,
        'bugtracker.mailto' => $tracker_mailto,
        'repository.type' => 'git',
        'repository.url' => $repo_url,
        'repository.web' => $repo_web,
        license => 'http://dev.perl.org/licenses/',
      }
    ],
    [
      Authority => {
        authority => $authority,
        do_metadata => 1,
      }
    ],
    [
      NextRelease => {
        format => $nextrelease_format,
      }
    ],
  );

  push @plugins, @extra;

  given ($nextversion) {
    when ('git') {
      push @plugins, [ "$section->{name}/Git::NextVersion", "Dist::Zilla::Plugin::Git::NextVersion",
        {
          first_version => '0.01',
          ( $version_regexp
            ? (version_regexp => $version_regexp)
            : (version_regexp => '^(\d.*)$')
          ),
        }
      ];
    } when ('autoversion') {
      push @plugins, [ "$section->{name}/AutoVersion", "Dist::Zilla::Plugin::AutoVersion",
        { 
          ( $autoversion_major
            ? (major => $autoversion_major)
            : (major => 0)
          ),
        }
      ];
    } default {
      # Manual versioning
    }
  };

  push @plugins, Dist::Zilla::PluginBundle::Git->bundle_config({
      name    => "$section->{name}/\@Git",
      payload => {
        tag_format => '%v',
        ( $tag_message
          ? (tag_message => $tag_message)
          : ()
        ),
      },
  });

  return @plugins;
}

