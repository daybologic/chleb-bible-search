# Chleb Bible Search

[GitHub release](https://github.com/daybologic/chleb-bible-search)

Welcome to the Chleb Bible Search by Rev. Duncan Ross Palmer

## What is Chleb Bible Search

A self-hostable microservice for querying the bible and searching for content, using a small, compressed, binary file.
The backend Perl library is also designed to be easily integrated with applications.

The service also provides a determinsitic verse of the day lookup.

## Documentation

For up to date documentation, please ensure you are viewing the latest copy at [GitHub](https://github.com/daybologic/chleb-bible-search/blob/master/README.md)

For API documentation, please use the documentation published at [SwaggerHub](https://app.swaggerhub.com/apis/M6KVM/chleb-bible-search/1.0.0)

## Availability

Hosting for Chleb Bible Search source code is provided at the following sites:

  * [BitBucket](https://bitbucket.org/2E0EOL/chleb-bible-search/commits/branch/master)
  * [GitHub](https://github.com/daybologic/chleb-bible-search)
  * [SourceHut](https://git.sr.ht/~m6kvm/chleb-bible-search)

The latest release is version 1.0.0, which is available for download at the following sites:

  * [GitHub](https://github.com/daybologic/chleb-bible-search/archive/refs/tags/v1.0.0.tar.gz)
  * [SourceHut](https://git.sr.ht/~m6kvm/chleb-bible-search/archive/v1.0.0.tar.gz)

The latest release is available as a Debian package from the following locations:

  * [BitBucket](https://bitbucket.org/2E0EOL/chleb-bible-search/downloads/chleb-bible-search_1.0.0_all.deb)
  * [GitHub](https://github.com/daybologic/chleb-bible-search/releases/download/v1.0.0/chleb-bible-search_1.0.0_all.deb)
  * [SourceHut](https://git.sr.ht/~m6kvm/chleb-bible-search/refs/v1.0.0)

## Contributing

### Branch naming scheme

When contributing to the project, please fork from the GitHub repository and make all contributions based on the develop branch,
unless you are specifically patching a bug within an historical release, in which case, branch from the relevant rel/ branch.

Please name your branch using this scheme:
  * bugfix/<ticket>-<description>
  * docs/<description>
  * feature/<description>
  * f/YYYYMM-<description>
  * hotfix/<description>
  * platform/<uname>/base
  * platform/<uname>/<dist>
  * rel/X.Y
  * refactor/<description>
  * tests/<description>
  * <user>/<hierarchy>
