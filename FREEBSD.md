# FreeBSD support

The `platform/freebsd/base` branch was a focused FreeBSD portability branch.
It removed a Debian-specific build-time dependency from the generated package
information script.

Before this branch, `bin/maint/pkg-info.sh` obtained the project version with:

```sh
dpkg-parsechangelog --show-field Version
```

That command is normally available on Debian systems but not necessarily on
FreeBSD.

The branch replaced it with a local shell function that:

- reads the first line of `debian/changelog`;
- extracts the version enclosed in parentheses;
- reports an error if the changelog is unreadable;
- exits immediately if version parsing fails; and
- uses `set -e` for early failure.

The final change comprised four commits from 27-28 September 2025:

1. `fb92eef5` - replace `dpkg-parsechangelog`;
2. `0509e370` - move `set -e` into the correct position;
3. `d7b6c317` - fail early when parsing fails; and
4. `9107c634` - apply part of CodeRabbit's review feedback.

The aggregate change to `bin/maint/pkg-info.sh` was 30 insertions and one
deletion.

The branch was integrated twice:

- `9c15dd57` merged `platform/freebsd/base` into
  `platform/freebsd/sourcehut`.
- `037b52d4` merged the change into the main development line through pull
  request 139, titled `FreeBSD platform; don't rely on dpkg for version
  parse`.

The change shipped beginning with `v2.1.2`.

At the time this history was recorded, the branch tip was `9107c634`, it had
no commits absent from `master`, and `master` was 689 commits ahead. Bitbucket,
GitHub, origin, and SourceHut retained the same branch tip, while archive did
not have an exact branch ref. The local branch reflog had expired.

Despite its `platform/` name, this was not left as a permanently divergent
FreeBSD branch: its complete work is in `master`. It is safe to remove the
local branch with `git branch -d`; the branch-pruning script will create the
missing archive ref before removing the remaining remote copies.
