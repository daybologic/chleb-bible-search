# Chleb Bible Search

[GitHub release](https://github.com/daybologic/chleb-bible-search)

Welcome to the Chleb Bible Search by Rev. Duncan Ross Palmer

## What is Chleb Bible Search

A self-hostable microservice for querying the bible and searching for content.
The backend Perl library is also designed to be easily integrated with applications.

The service also provides a determinsitic verse of the day lookup.

## Documentation

For up to date documentation, please ensure you are viewing the latest copy at [GitHub](https://github.com/daybologic/chleb-bible-search/blob/master/README.md)

For API documentation, please use the documentation published at [SwaggerHub](https://app.swaggerhub.com/apis/M6KVM/chleb-bible-search/2.0.0)

## Configuration

The configuration YAML file can be found in etc/main.yaml or when installed,
/etc/chleb-bible-search/main.yaml

## Availability

A running version of the latest version of the microservice itself is hosted on behalf of the project at this location:

  * [chleb-api.daybologic.co.uk](https://chleb-api.daybologic.co.uk/)

Hosting for Chleb Bible Search source code is provided at the following sites:

  * [BitBucket](https://bitbucket.org/2E0EOL/chleb-bible-search/commits/branch/master)
  * [GitHub](https://github.com/daybologic/chleb-bible-search)
  * [SourceHut](https://git.sr.ht/~m6kvm/chleb-bible-search)

The latest release is version 2.0.0, which is available for download at the following sites:

  * [GitHub](https://github.com/daybologic/chleb-bible-search/archive/refs/tags/v2.0.0.tar.gz)
  * [SourceHut](https://git.sr.ht/~m6kvm/chleb-bible-search/archive/v2.0.0.tar.gz)

The latest release is available as a Debian package from the following locations:

  * [GitHub](https://github.com/daybologic/chleb-bible-search/releases/download/v2.0.0/chleb-bible-search_2.0.0_all.deb)
  * [SourceHut](https://git.sr.ht/~m6kvm/chleb-bible-search/refs/v2.0.0)

## Self-hosted installation

You are welcome to use our hosted version of the service, at [chleb-api.daybologic.co.uk](https://chleb-api.daybologic.co.uk/).
This is the easiest way to fire up and get searching the bible via your application or website.  However, if you want to install
the service on your own equipment.  Please install the deb file, where possible, an then run:

```
sudo dpkg -i chleb-bible-search_2.0.0_all.deb
sudo systemctl enable chleb-bible-search.service
sudo invoke-rc.d chleb-bible-search start
```

### Web front-end (proxy).

#### Apache

If you have made the microservice work using Apache as a proxy, please contribute and tell us how
you did it.  Otherwise, we recommend Nginx; it's simple, lightweight, and provides everything you
will need to install the project.

#### Nginx

How to install with Nginx (recommended).

With the Debian package, we automatically install the site file to /etc/nginx/sites-available/chleb-bible-search.example,
which you should copy and rename by running:

```
sudo cp /etc/nginx/sites-available/chleb-bible-search.example /etc/nginx/sites-available/chleb-bible-search
```

but in any case, you can copy and modify etc/nginx/chleb-bible-search.example in the source code distribution to the
available sites location in the Nginx configuration directory, and rename it chleb-bible-search

Remember to modify the hostname to match your site in the new file!  Also, you may need a symbolic link to make
the site live.  We will not do this for you!  Under Debian, this name will be
/etc/nginx/sites-enabled/chleb-bible-search, eg.

```
sudo cp -l /etc/nginx/sites-available/chleb-bible-search /etc/nginx/sites-enabled/chleb-bible-search
```

## Contributing

### Branch naming scheme

When contributing to the project, please fork from the GitHub repository and make all contributions based on the develop branch,
unless you are specifically patching a bug within an historical release, in which case, branch from the relevant rel/ branch.

Please name your branch using this scheme:
| branch | description | FF allowed | rebase allowed |
| ------ | ----------- | ---------- | -------------- |
| bugfix/&lt;ticket&gt;-&lt;description&gt; | A user bug report, with the ticket number | NO | NO |
| bugs/&lt;id&gt; | Reserved for the use of git-bug | NO | NO |
| develop | Mainline merge point for all features | NO except from master | NO |
| docs/&lt;description&gt; | Documentation changes _only_ | NO | NO |
| feature/&lt;description&gt; | New functionality | NO | NO |
| f/YYYYMM-&lt;description&gt; | Legacy features, please don't create new ones | NO | NO |
| hotfix/&lt;description&gt; | Emergency fixes only | NO | YES |
| maint | Maintainer branches (features for developers) | NO | NO |
| master | Pointer to latest stable release | YES | NO |
| platform/&lt;uname&gt;/base | Specific changes which can't be merged to master | NO | NO |
| private/&lt;user-defined&gt; | Undocumented hierarchy, maintainer-use only | YES | YES |
| rel/X.Y | released 1.0, 2.0, 2.1 etc, which contain specific tags vX.Y.Z | NO | NO |
| refactor/&lt;description&gt; | Not features, design changes | NO | NO |
| tests/&lt;description&gt; | Unit tests, functional tests, sanity improvements | NO | NO |
| &lt;user&gt;/&lt;hierarchy&gt; | Your GitHub username, followed by recognized hierarchies above | NO | YES |

### Raising issues

Please check if the bug you are reported is already recognized, but if you need to raise an issue
or report a bug, please do so on [GitHub](https://github.com/daybologic/chleb-bible-search/issues).
If there is a security problem, please consider reporting to me directly:
<a href="mailto:2e0eol\@gmail.com">2e0eol\@gmail.com</a>

### Standards and Principles

All of the standards we use are documented elsewhere on the world-wide web:

  * [Git](https://git-scm.com/)
  * [GitFlow](https://nvie.com/posts/a-successful-git-branching-model/)
  * [Gitmoji](https://gitmoji.dev/)
  * [JSON:API](https://jsonapi.org/format/)
  * [Perl 5](https://dev.perl.org/perl5/)
  * [RESTful](https://restfulapi.net/)
  * [Semantic Versioning](https://semver.org/)
  * [Twelve-Factor App](https://12factor.net/)

Very importantly, the master branch is always the latest release, and should be production ready at any time!
Please do not submit and target pull requests to the master branch, but to the develop branch!

### Testing

Please ensure when writing new code that there is a test suite for it.  We ask for this to prevent code
from becoming fragile, so that if any changes are made to your submission, subsequently, we can be
reasonably confident that there has not been a regression.

We have two levels of testing and you can pick at least one, whichever is more appropriate:

For anything involving code which is not directly-related to an endpoint, write a test-suite under
the t/ directory.  This is a standard directory for Perl-authored projects, and uses [Test::Module::Runnable](https://github.com/daybologic/libtest-module-runnable-perl)
Please see the [documentation](https://git.sr.ht/~m6kvm/libtest-module-runnable-perl/tree/master/item/README.md) for writing tests.  Please look at [existing tests](https://git.sr.ht/~m6kvm/libtest-module-runnable-perl/tree/master/item/t) for a guide.

You can run the test suite any time by typing:
```
./Makefile.PL
make && make test
```

You will need to install all build-dependencies first.

For anything involving endpoints code, especially code within [Moose.pm](https://git.sr.ht/~m6kvm/chleb-bible-search/tree/master/item/lib/Chleb/Server/Moose.pm) or [Dancer2.pm](https://git.sr.ht/~m6kvm/chleb-bible-search/tree/master/item/lib/Chleb/Server/Dancer2.pm), please write one or more tests under [data/tests](https://git.sr.ht/~m6kvm/chleb-bible-search/tree/tests/httpie-1/item/data/tests).

These files are a all bash shell files.  Start with [1/template.sh]((https://git.sr.ht/~m6kvm/chleb-bible-search/tree/tests/httpie-1/item/data/tests/1/template.sh) and copy this. The digit at the start represents the endpoint version.

You can test this by running [tt/httpie-tests.sh](https://git.sr.ht/~m6kvm/chleb-bible-search/tree/tests/httpie-1/item/tt/httpie-tests.sh) and specify the 1/name or run all the tests by specifying no parameters.

You will need to edit your /etc/hosts file to ensure that the name [chleb-api.example.org](http://chleb-api.example.org) points to your running code, and set up Nginx.  Remember this does *not* use https (TLS)!

You will need to install [HTTPie](https://www.baeldung.com/httpie-http-client-command-line#bd-1-on-linux) (at least the command-line utilities, if not the full GUI app)

You can also run these tests by typing:

```
./Makefile.PL
make && make http-test
```

nb. if the 'http' utility is not in the path, or chleb-api.example.org does not resolve, then this script exists with a false success case, emitting a warning.
This is merely to ensure the package still builds, and should be obvious.  Don't be fooled!

When building the Debian package, the unit testing framework will automagically execute and any failing
tests will cause the package building process to fail.
