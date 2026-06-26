# AGENTS.md

Guidance for coding agents working in this repository.

## Project Overview

Chleb Bible Search is a self-hostable Perl microservice for querying and
searching the Bible. It exposes a JSON:API-compliant HTTP API, currently with
v1 and v2 endpoints for search, verse lookup, random verse, and verse of the
day. The core library can also be used without an HTTP server.

## Common Commands

Run these from the repository root.

```bash
# Generate Makefile before using make targets
./Makefile.PL

# Run the project test target
make test

# Run a single unit test
perl -I lib t/<test-name>.t

# Run functional HTTP integration tests (this requires a web server to be installed)
make http-test

# Generate coverage report
make cover

# Build Debian package
make deb

# Clean build artifacts and cache
make clean
```

`make test` is extended by `Makefile.PL` to include `http-test`. Functional
tests require HTTPie, a running Nginx instance configured for the project, and
an `/etc/hosts` entry for `chleb-api.example.org`. If that environment is not
available, use targeted unit tests such as `perl -I lib t/Server_search.t`.

## Architecture

Request flow:

```text
HTTP Request
  -> Chleb::Server::Dancer2
  -> Chleb::Server::Moose
  -> Chleb::Bible
  -> Chleb::Bible::Backend
```

Key files and directories:

- `lib/Chleb/Bible.pm`: main Bible object and entry point for search, lookup,
  random, and verse-of-the-day operations.
- `lib/Chleb/Bible/Backend.pm`: loads compressed `.bin.gz` Bible data files
  using Storable format and caches decompressed data in `cache/`.
- `lib/Chleb/Bible/Search/Query.pm`: query builder for whole-word matching,
  testament filtering, and book filtering. Call `->run()` to execute. Default
  limit is 50 verses.
- `lib/Chleb/Server/Dancer2.pm`: Dancer2 HTTP routing layer.
- `lib/Chleb/Server/Moose.pm`: business logic for API endpoints.
- `lib/Chleb/DI/Container.pm`: MooseX::Singleton dependency injection
  container for logger, config, and other shared services.
- `lib/Chleb/Token/`: session token support with Local, Redis, and Dummy
  repositories.
- `bin/core/app.psgi`: PSGI entry point for the HTTP server.
- `etc/main.yaml`: configuration used for development work, including feature
  flags, VOTD exclusions, session token backend selection, and Dancer2
  settings.
- `debian/etc/main.yaml`: default configuration installed for Debian GNU/Linux
  packages. Keep it aligned with intended Debian deployment defaults rather
  than treating it as the development configuration.
- `etc/log4perl.conf`: Log4perl configuration used for development work.
- `debian/etc/log4perl.conf`: default Log4perl configuration installed for
  Debian GNU/Linux packages. Keep it aligned with intended Debian deployment
  defaults rather than treating it as the development logging configuration.
- `swagger.yaml`: OpenAPI specification.

## Coding Conventions

- This is a Perl 5 codebase using Moose for the main object model.
- Major classes extend `Chleb::Bible::Base`.
- Prefer existing Moose attributes, lazy builders, type constraints, and
  coercions over ad hoc object state.
- Use `Chleb::Exception` for custom exceptions and HTTP status mapping.
- In Perl conditionals, write explicit string length comparisons such as
  `length($value) > 0` rather than relying on `length($value)` as a boolean.
- Keep changes scoped to the library, server layer, config, or packaging area
  implied by the task.

## Testing Conventions

- Unit tests live in `t/`.
- Tests use `Test::Module::Runnable` with `setUp` and `tearDown` patterns.
- Use `Chleb::DI::MockLogger` in tests when logging needs to be suppressed or
  captured.
- Functional tests live under `data/tests/` and are shell scripts that invoke
  HTTPie against a live server.
- When changing shared behavior, add or update focused tests in `t/`; when
  changing route behavior, consider both unit-level server tests and functional
  coverage.

## Contribution Conventions

- Follow the branch naming scheme documented in `README.md`.
- Use Gitmoji for commit summary lines. Put the relevant emoji at the start of
  the summary, for example `📝 add AGENTS guidance` for documentation. Do not
  add a category prefix such as `docs:` or `config:` after the emoji. Only use
  emojis that exist under `data/gitmoji/`.
- Add `Co-Authored-By: Codex <noreply@openai.com>` to commits made by Codex.
- Keep commit messages focused on the change being made.

## Agent Notes

- Check the worktree before editing and do not overwrite unrelated local
  changes.
- Run the narrowest relevant tests first. Only run `make test` when the HTTP
  integration test prerequisites are available or intentionally being checked.
- Generated data and build artifacts may appear under `cache/`, `data/`,
  `info/`, and coverage directories; avoid committing incidental output unless
  the task explicitly requires it.
