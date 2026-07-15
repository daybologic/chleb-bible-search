# Split Config Plan

## Goal

Split the runtime configuration into smaller YAML files so Debian package
updates can change fundamental service defaults without making it awkward for a
server administrator to preserve local contact details, token settings, or
optional feature choices.

Keep `main.yaml` support for backward compatibility.

## Proposed Files

- `contact.yaml`: server administrator details.
- `general.yaml`: everything not covered by the other split files.
- `features.yaml`: optional features and related feature metadata.
- `tokens.yaml`: session token and JWT configuration.

## Loading Model

Update `Chleb::DI::Config` so that selecting a `main.yaml` also loads sibling
split files from the same directory.

Suggested load order:

1. `main.yaml`
2. `general.yaml`
3. `contact.yaml`
4. `features.yaml`
5. `tokens.yaml`

Use a recursive hash merge so existing call sites such as
`config->get('server', 'admin_email', ...)` continue to work unchanged.
Later files should override earlier files if a key appears in more than one
file.

Temporary test configs containing only `main.yaml` should keep working.

## Development Config Split

Split `etc/main.yaml` into:

- `etc/general.yaml`
  - `server.uptime_file`
  - `server.children`, if present
  - `Dancer2`
  - `votd_exclude`
  - `rate_limit`
- `etc/contact.yaml`
  - `server.admin_email`
  - `server.admin_name`
  - `server.domain`
- `etc/features.yaml`
  - `features`
  - `facebook`
  - `twitter`
  - `mailing_list_votd`, if explicit defaults are added
- `etc/tokens.yaml`
  - `session_tokens`

Leave `etc/main.yaml` as a small compatibility anchor, probably containing
comments only.

## Debian Config Split

Split `debian/etc/main.yaml` in the same way, preserving Debian-specific values:

- `/var/run/chleb-bible-search/startup.txt`
- `/usr/share/chleb-bible-search/public`
- `/var/lib/chleb-bible-search/sessions`
- `replace-on-first-install`
- `ttl: 10800`
- `children: 30`

Leave `debian/etc/main.yaml` as a small compatibility anchor.

## Script Updates

Some shell scripts parse `/etc/chleb-bible-search/main.yaml` directly:

- `bin/core/run.sh` reads `server.children`.
- `bin/core/session-clean.sh` reads `session_tokens.backend_local.dir`.

Avoid duplicating merge logic in shell.  Prefer updating `bin/core/yaml2json.pl`
so it can accept multiple YAML files and merge them using the same semantics as
`Chleb::DI::Config`.

The scripts can then call it with:

```text
/etc/chleb-bible-search/main.yaml
/etc/chleb-bible-search/general.yaml
/etc/chleb-bible-search/contact.yaml
/etc/chleb-bible-search/features.yaml
/etc/chleb-bible-search/tokens.yaml
```

## Debian Maintainer Script Updates

`debian/chleb-bible-search-core.postinst` currently replaces the JWT secret in:

```text
/etc/chleb-bible-search/main.yaml
```

After the split, it should edit:

```text
/etc/chleb-bible-search/tokens.yaml
```

## Packaging Updates

`debian/chleb-bible-search-core.install` already installs
`debian/etc/*.yaml`, so the new split YAML files should be included
automatically.

Update `MANIFEST` to include the new config files.

## Tests

Add or update tests around `Chleb::DI::Config` for:

- Loading split sibling config files.
- Recursive hash merging.
- Override order.
- Backward compatibility with a single `main.yaml`.

Keep existing temporary test configs working without requiring every test to
create the full split-file set.

## Documentation

Update README references to `main.yaml` so administrators know the installed
configuration is split across:

- `/etc/chleb-bible-search/main.yaml`
- `/etc/chleb-bible-search/general.yaml`
- `/etc/chleb-bible-search/contact.yaml`
- `/etc/chleb-bible-search/features.yaml`
- `/etc/chleb-bible-search/tokens.yaml`

## Recommendation

Keep `main.yaml` present and supported, but make the package's normal config
use the four split files.  This avoids breaking existing local deployments and
test fixtures, while giving Debian administrators smaller conffiles with clearer
ownership boundaries.
