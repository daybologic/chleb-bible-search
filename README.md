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
| branch | description | FF allowed | rebase allowed |
| ------ | ----------- | ---------- | -------------- |
| bugfix/&lt;ticket&gt;-&lt;description&gt; | A user bug report, with the ticket number | NO | NO |
| bugs/&lt;id&gt; | Reserved for the use of git-bug | NO | NO |
| develop | Mainline merge point for all features | YES | NO |
| docs/&lt;description&gt; | Documentation changes _only_ | NO | NO |
| feature/&lt;description&gt; | New functionality | NO | NO |
| f/YYYYMM-&lt;description&gt; | Legacy features, please don't create new ones | NO | NO |
| hotfix/&lt;description&gt; | Emergency fixes only | NO | YES |
| master | Pointer to latest stable release | YES | NO |
| platform/&lt;uname&gt;/base | Specific changes which can't be merged to master | NO | NO |
| private/&lt;user-defined&gt; | Undocumented hierarchy, maintainer-use only | YES | YES |
| rel/X.Y | released 1.0, 2.0, 2.1 etc, which contain specific tags vX.Y.Z | NO | NO |
| refactor/&lt;description&gt; | Not features, design changes | NO | NO |
| tests/&lt;description&gt; | Unit tests, functional tests, sanity improvements | NO | NO |
| &lt;user&gt;/&lt;hierarchy&gt; | Your GitHub username, followed by recognized hierarchies above | NO | YES |
