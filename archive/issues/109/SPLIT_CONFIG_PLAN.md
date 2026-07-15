# Split Config Plan

## Goal

Split the runtime configuration into smaller YAML files so Debian package
updates can change fundamental service defaults without making it awkward for a
server administrator to preserve local contact details, token settings, or
optional feature choices.

Treat `main.yaml` as the general configuration file.  It should hold the
fundamental service settings which do not belong to a more specific split file.

## Proposed Files

- `contact.yaml`: server administrator details.
- `main.yaml`: everything not covered by the other split files.
- `features.yaml`: optional features and related feature metadata.
- `tokens.yaml`: session token and JWT configuration.

## Loading Model

Update `Chleb::DI::Config` so that selecting a config directory loads
`main.yaml` plus the sibling split files from that same directory.

Suggested load order:

1. `main.yaml`
2. `contact.yaml`
3. `features.yaml`
4. `tokens.yaml`

Use a recursive hash merge so existing call sites such as
`config->get('server', 'admin_email', ...)` continue to work unchanged.
Later files should override earlier files if a key appears in more than one
file.

Temporary test configs containing only `main.yaml` should not need to create
empty split files.

## Development Config Split

Split `etc/main.yaml` into:

- `etc/main.yaml`
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

## Debian Config Split

Split `debian/etc/main.yaml` in the same way, preserving Debian-specific values:

- `/var/run/chleb-bible-search/startup.txt`
- `/usr/share/chleb-bible-search/public`
- `/var/lib/chleb-bible-search/sessions`
- `replace-on-first-install`
- `ttl: 10800`
- `children: 30`

Keep the Debian fundamental service settings in `debian/etc/main.yaml`.

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
- Single-file operation when only `main.yaml` exists.

Keep existing temporary test configs working without requiring every test to
create the full split-file set.

## Documentation

Update README references to `main.yaml` so administrators know the installed
configuration is split across:

- `/etc/chleb-bible-search/main.yaml`
- `/etc/chleb-bible-search/contact.yaml`
- `/etc/chleb-bible-search/features.yaml`
- `/etc/chleb-bible-search/tokens.yaml`

## Recommendation

Keep `main.yaml` as the general configuration file and move administrator
contact details, optional feature choices, and token/JWT settings into their
own files.  This gives Debian administrators smaller conffiles with clearer
ownership boundaries while preserving the existing section/key access pattern in
the Perl code.
