# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Chleb Bible Search is a self-hostable Perl microservice for querying and searching the Bible. It exposes a JSON:API-compliant HTTP API (v1 and v2) with endpoints for search, verse lookup, random verse, and verse-of-the-day (VOTD). The library can also be used standalone without the HTTP server.

## Common Commands

```bash
# Generate Makefile (required before other make targets)
./Makefile.PL

# Run all tests
make test

# Run a single unit test
perl -I lib t/<test-name>.t

# Run functional (HTTP integration) tests
make http-test

# Generate code coverage report
make cover

# Build Debian package
make deb

# Clean build artifacts and cache
make clean
```

Functional tests require: HTTPie installed, Nginx running with the project configured, and `/etc/hosts` entry for `chleb-api.example.org`.

## Architecture

### Data Flow

```
HTTP Request → Chleb::Server::Dancer2 (routing)
                → Chleb::Server::Moose (business logic)
                  → Chleb::Bible (core object)
                    → Chleb::Bible::Backend (loads/caches .bin.gz data files)
```

### Key Components

- **`lib/Chleb/Bible.pm`** — Main Bible object; entry point for search, lookup, random, and VOTD operations.
- **`lib/Chleb/Bible/Backend.pm`** — Loads Bible data from compressed `.bin.gz` files (Storable format, versioned at v12). Caches decompressed data in `cache/`.
- **`lib/Chleb/Bible/Search/Query.pm`** — Query builder; supports whole-word matching, testament filtering (Old/New), and book filtering. Call `->run()` to execute. Default limit: 50 verses.
- **`lib/Chleb/Server/Dancer2.pm`** — Dancer2-based HTTP server with route definitions.
- **`lib/Chleb/Server/Moose.pm`** — Business logic for all API endpoints.
- **`lib/Chleb/DI/Container.pm`** — MooseX::Singleton dependency injection container; holds logger, config, and other singletons. Replaced with mocks in tests.
- **`lib/Chleb/Token/`** — Session token management with pluggable backends: Local (file), Redis, or Dummy.
- **`bin/core/app.psgi`** — PSGI entry point for the HTTP server.

### OOP Conventions

- All major classes extend `Chleb::Bible::Base` using **Moose**.
- Attributes use lazy initialization, type constraints, and coercion throughout.
- Custom exceptions via `Chleb::Exception` with HTTP status code mapping.

### Testing Conventions

- Unit tests live in `t/` and use `Test::Module::Runnable` with `setUp`/`tearDown` patterns.
- Use `Chleb::DI::MockLogger` to suppress/capture logging in tests.
- Functional tests in `data/tests/` are shell scripts invoking HTTPie against a live server.

### Configuration

- **`etc/main.yaml`** — Primary config: feature flags (`facebook`, `sessions`), VOTD exclusions (terms/refs), session token backend selection, and Dancer2 settings.
- **`etc/log4perl.conf`** — Log4perl logging configuration.
- **`swagger.yaml`** — OpenAPI specification for the API.
