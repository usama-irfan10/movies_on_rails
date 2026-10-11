# Movies on Rails

[![CI](https://github.com/usama-irfan10/movies_on_rails/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/usama-irfan10/movies_on_rails/actions/workflows/ci.yml)

Backend for a small movie review platform: CSV import, a searchable and sortable movie
overview, and a token-protected JSON API. Rails 8 · PostgreSQL · RSpec · ActiveModelSerializers.

- [Live demo](#live-demo)
- [Quick start with Docker](#quick-start-with-docker)
- [Quick start without Docker](#quick-start-without-docker)
- [Configuration](#configuration)
- [Command cheat sheet](#command-cheat-sheet)
- [Using the app](#using-the-app)
- [Importing data](#importing-data)
- [API reference](#api-reference)
- [API documentation (OpenAPI)](#api-documentation-openapi)
- [Authentication](#authentication)
- [Design decisions](#design-decisions)
- [Security](#security)
- [Testing and quality](#testing-and-quality)
- [Production notes](#production-notes)
- [Troubleshooting](#troubleshooting)
- [Known limitations](#known-limitations)

## Live demo

**https://movies-on-rails.onrender.com** - sign in with `demo@example.com` /
`demo-password-123`. The API works the same way (`POST /api/v1/tokens` with those
credentials returns a bearer token); try it in Swagger UI at
https://movies-on-rails.onrender.com/api-docs.

It runs on Render's free plan (see [Deploying to Render](#deploying-to-render)): after 15
idle minutes the app sleeps, so the first request can take about a minute.

## Quick start with Docker

Only Docker (with Compose v2) is needed - no local Ruby or PostgreSQL.

```bash
cp .env.example .env                                   # optional: every setting has a default
docker compose up --build                              # app + PostgreSQL on http://localhost:3000
```

On the first start the database is created and seeded with the bundled CSV data and a
development account. Open http://localhost:3000 and sign in with `demo@example.com` /
`demo-password-123`. The app is published on `127.0.0.1` only. Stop with `Ctrl+C`;
`docker compose down -v` also deletes the database volume.

Run other commands in a second terminal, for example
`docker compose run --rm web bin/rails import:all` to re-import the CSV files.

Password-reset emails cannot open a browser from inside a container, so they are listed at
http://localhost:3000/letter_opener.

The containers are capped at 2 CPU cores for the app and 1 for PostgreSQL, and image builds
install at most 2 gems in parallel, so a laptop stays responsive. Adjust `DOCKER_CPUS`,
`DOCKER_DB_CPUS` and `BUNDLE_JOBS` in `.env` (lower on a small machine, higher for speed).

## Quick start without Docker

Requires Ruby (see `.ruby-version`), PostgreSQL running locally, and Bundler.

```bash
bundle install
cp .env.example .env                                   # optional
bin/rails db:setup                                     # create, load schema, import the CSVs, demo user
bin/rails server                                       # http://localhost:3000
```

PostgreSQL is reached through `config/database.yml` (your OS user by default). Set
`DATABASE_URL` to use other credentials. Password-reset emails open in your browser
through the `letter_opener` gem.

## Configuration

Settings come from environment variables. In development and test, a `.env` file is loaded
by `dotenv-rails` (copy `.env.example`); real environment variables always win over `.env`.
`docker compose` reads the same file. **Every variable is optional in development.** In
production the app refuses to boot, with a clear message, if `APP_HOST` is missing.

| Variable | Default | Purpose |
| --- | --- | --- |
| `APP_HOST` | `localhost:3000` | Host used in email links. **Required in production**; also becomes the only allowed host name |
| `MAILER_FROM` | `no-reply@example.com` | Sender address of emails |
| `DATABASE_URL` | from `config/database.yml` | Database connection string |
| `RAILS_MASTER_KEY` or `SECRET_KEY_BASE` | - | Production secrets (never commit them) |
| `RAILS_MAX_THREADS` | `3` | Puma threads and DB pool size |
| `PORT` | `3000` | Puma port without Docker |
| `RAILS_LOG_LEVEL` | `info` | Production log verbosity |
| `APP_PORT` | `3000` | Docker only: host port the container is published on |
| `POSTGRES_PASSWORD` | `postgres` | Docker only: password of the local database container |

## Command cheat sheet

Prefix with `docker compose run --rm web` to run inside Docker.

| Task | Command |
| --- | --- |
| Install gems | `bundle install` |
| Create DB, load schema, seed (CSV data + demo user) | `bin/rails db:setup` |
| Apply new migrations | `bin/rails db:migrate` |
| Import the CSV files (safe to repeat) | `bin/rails import:all` |
| Import other CSV files | `bin/rails "import:all[path/to/movies.csv,path/to/reviews.csv]"` |
| Create a user | `bin/rails users:create EMAIL=you@example.com` (prompts for the password) |
| Delete expired sessions and tokens | `bin/rails auth:prune` |
| Start the server | `bin/rails server` |
| Run all specs | `bundle exec rspec` |
| Run one spec file | `bundle exec rspec spec/models/movie_spec.rb` |
| Lint | `bin/rubocop` (auto-fix: `bin/rubocop -A`) |
| Security scan | `bin/brakeman` |
| Dependency audit | `bundle exec bundler-audit check --update` |
| Regenerate the API docs | `RAILS_ENV=test bin/rails rswag:specs:swaggerize` |
| Run only the API contract specs | `bundle exec rspec spec/api` |
| Specs in Docker | `docker compose run --rm -e RAILS_ENV=test web bash -c "bin/rails db:create db:schema:load && bundle exec rspec"` |

## Using the app

| Page | Path |
| --- | --- |
| Movie overview (sorted by average stars, best first) | `/` or `/movies` |
| Search by actor name (partial, case-insensitive; titles are not searched) | `/movies?actor=cage` |
| Sort: `rating_desc` (default), `rating_asc`, `title` | `/movies?sort=rating_asc` |
| Sign in / out | `/session/new` |
| Reset a forgotten password | `/passwords/new` |
| Emails sent in development (Docker only) | `/letter_opener` |
| Interactive API docs (Swagger UI) | `/api-docs` |
| Health check (public) | `/up` |

All pages except sign-in, password reset and the health check require a login. There is no
public signup: an operator creates users with `bin/rails users:create`. Movies without reviews
show "No reviews yet" and are listed after rated movies in both rating orders.

## Importing data

```bash
bin/rails import:all                                               # db/data/movies.csv and reviews.csv
bin/rails "import:all[path/to/movies.csv,path/to/reviews.csv]"     # other files
```

The import runs in one transaction: it either completes or changes nothing. It is safe to
re-run, and concurrent runs wait for each other. What it does with the data:

- **movies.csv** has one row per movie x actor x filming location; rows are collapsed into
  unique movies, actors and locations. **reviews.csv** is streamed in batches, so its size
  does not matter.
- Records are matched ignoring case and extra whitespace (`" inception "` is `Inception`),
  both within the files and against data already in the database, so re-imports update rows
  instead of duplicating them. Column headers are matched the same way; a UTF-8 byte-order
  mark is fine.
- A reviewer's last row for a movie wins. Reviews may refer to movies imported earlier.
- Rows that cannot be used are skipped and reported with their line number: a missing title,
  director or user; a year outside 1888-2100; stars that are not a whole number from 1 to 5;
  a filming location without a country; a review for an unknown movie. When rows for the same
  movie disagree (for example on the year), the first row wins and the others are reported.
- A file that is missing, malformed, or lacks a required column stops the import with a
  clear message, and nothing is changed.
- The import adds and updates; it never deletes rows that are absent from the files.

## API reference

The API is read-only apart from issuing and revoking tokens. Every endpoint except
`POST /api/v1/tokens` needs `Authorization: Bearer <token>`.

```bash
# 1. Get a token (shown once, valid for 30 days)
curl -X POST http://localhost:3000/api/v1/tokens \
  -H 'Content-Type: application/json' \
  -d '{"email_address":"demo@example.com","password":"demo-password-123"}'
# => {"token":"...","token_type":"Bearer","expires_at":"..."}

TOKEN=...   # paste the token

# 2. List movies (search, sort and paginate)
curl 'http://localhost:3000/api/v1/movies?actor=cage&sort=rating_desc&page=1&per_page=20' \
  -H "Authorization: Bearer $TOKEN"

# 3. One movie, with its filming locations
curl http://localhost:3000/api/v1/movies/1 -H "Authorization: Bearer $TOKEN"

# 4. A movie's reviews, newest first (paginated)
curl 'http://localhost:3000/api/v1/movies/1/reviews?page=1' -H "Authorization: Bearer $TOKEN"

# 5. Revoke the token
curl -X DELETE http://localhost:3000/api/v1/tokens -H "Authorization: Bearer $TOKEN"
```

| Endpoint | Parameters | Success | Errors |
| --- | --- | --- | --- |
| `POST /api/v1/tokens` | `email_address`, `password` (JSON body) | `201` with `token`, `token_type`, `expires_at` | `401` invalid credentials, `429` too many attempts |
| `DELETE /api/v1/tokens` | - | `204` | `401` |
| `GET /api/v1/movies` | `actor`, `sort`, `page`, `per_page` (default 20, max 100) | `200` with `movies` and `meta` | `401`, `429` |
| `GET /api/v1/movies/:id` | - | `200` with `movie` | `401`, `404` |
| `GET /api/v1/movies/:movie_id/reviews` | `page`, `per_page` | `200` with `reviews` and `meta` | `401`, `404` |

Unknown `sort` values fall back to `rating_desc`. Errors look like `{"error": "Not found"}`.
A list response:

```json
{
  "movies": [
    { "id": 1, "title": "Inception", "year": 2010, "director": "Christopher Nolan",
      "average_stars": 2.75, "reviews_count": 4, "actors": ["Ellen Page", "Giovani Ribisi"] }
  ],
  "meta": { "current_page": 1, "per_page": 20, "total_pages": 1, "total_count": 2 }
}
```

`average_stars` is `null` (and `reviews_count` is `0`) for a movie without reviews. The detail
response adds `description` and `locations` (`name`, `country`). Reviews have `id`,
`user_name`, `stars`, `comment` and `created_at`; they are paginated separately so a popular
movie cannot produce an unbounded response.

## API documentation (OpenAPI)

The API is described in [`swagger/v1/openapi.yaml`](swagger/v1/openapi.yaml) (OpenAPI 3.0).
Swagger UI is served at `/api-docs` (locally http://localhost:3000/api-docs, live
https://movies-on-rails.onrender.com/api-docs): call `POST /api/v1/tokens` with the demo
account, click **Authorize**, paste the token, and try each endpoint.

The document is generated, not hand-written. The specs in `spec/api` describe every endpoint
with [rswag](https://github.com/rswag/rswag), and running them checks each real response
against the documented schema (unexpected or missing fields fail the test). After changing
the API, update those specs and regenerate:

```bash
bundle exec rspec spec/api                          # contract tests
RAILS_ENV=test bin/rails rswag:specs:swaggerize     # rewrite swagger/v1/openapi.yaml
```

CI fails if the committed document is out of date. The response schemas live in
`spec/swagger_helper.rb`. The YAML file can also be opened in any OpenAPI viewer (for
example https://editor.swagger.io). Swagger UI's page needs inline scripts, so it sends its
own, looser Content-Security-Policy; every other page keeps the strict one.

## Authentication

**Web UI - cookie sessions** (modelled on the Rails 8 authentication generator).
`has_secure_password` (bcrypt) stores passwords, 12 characters minimum. A successful login
creates a `sessions` row and sets a signed, HttpOnly, SameSite=Lax cookie (Secure in
production) that holds only that row's id, so a login can be revoked on the server. Logins
last 30 days, sign-in attempts are rate limited, and the session id is reset at login to
prevent session fixation.

**Password reset.** The emailed link carries a signed token that expires after 15 minutes
and stops working once the password changes. The form answers identically for unknown
addresses, so it cannot be used to discover accounts. Changing a password signs the user out
everywhere and revokes their API tokens.

**API - Bearer tokens.** One token per login, 256 bits of randomness; only its SHA-256 digest
is stored, so a database leak does not expose usable tokens. Tokens expire after 30 days and
can be revoked with `DELETE /api/v1/tokens`. A browser session cookie is *not* accepted by the
API. Run `bin/rails auth:prune` regularly (for example daily from cron) to delete expired rows.

## Design decisions

- **Normalized schema.** `movies.csv` has one row per movie x actor x filming location, so it
  is split into `movies`, `actors`, `locations` and the `movie_actors` / `movie_locations`
  join tables. `country` belongs to the location. Reviewers are stored as `reviews.user_name`.
  Natural keys (title, actor name, location name and country, reviewer per movie) are unique
  regardless of case through `lower(...)` unique indexes, and check constraints guard stars,
  years and the cached stats - the database enforces the rules even when validations are
  bypassed (as the bulk import does).
- **Efficient sorting.** `average_stars` and `reviews_count` are cached on `movies` and
  recomputed with one `UPDATE` (`Movie.refresh_rating_stats!`) after imports and after a review
  is committed. The average is `NULL` for unrated movies ("not rated" is not "0 stars"), and
  both rating orders put them last. Each order (`rating_desc`, `rating_asc`, case-insensitive
  `title`) has a matching index, so a page is an index scan with no join or aggregate; `id`
  breaks ties so pages are stable.
- **Efficient search.** Actor search uses `ILIKE` backed by a `pg_trgm` GIN index and a
  subquery (`WHERE id IN (...)`), so each movie appears once without `DISTINCT`.
- **Efficient import.** Parsing (`MoviesFile`, `ReviewsFile`, plain Ruby) is separate from
  writing. Rows are written with batched `upsert_all` / `insert_all`; ids come back through
  `RETURNING`, so no lookup queries are needed. Only movies whose reviews changed get their
  stats refreshed. See [Importing data](#importing-data).
- **Measured.** On PostgreSQL 16 with 200,000 movies and 600,000 reviews, each query plan
  uses its index: a sorted page takes about 0.2 ms and an actor search about 1 ms.
- **No N+1.** The index and API actions eager-load associations (covered by specs).
- **Serializers.** `MovieSerializer` (lists), `MovieDetailSerializer` (single movie) and
  `ReviewSerializer` from ActiveModelSerializers, with a root key and pagination `meta`.
- **Configuration.** Plain environment variables plus `dotenv-rails` for local `.env` files,
  with defaults for development and a fail-fast check in production. (Figaro is no longer
  actively maintained, and Rails credentials are kept for secrets only.)

```
app/
  controllers/        web pages, sessions, passwords, api/v1 (base, movies, reviews, tokens)
  controllers/concerns/  Authentication (cookie sessions), Paginatable
  models/             Movie, Actor, Location, Review, join models, User, Session, ApiToken
  serializers/        API representations
  services/           MovieCatalogImporter (+ CsvFile, MoviesFile, ReviewsFile, Issues)
lib/tasks/            import.rake, users.rake, auth.rake
config/initializers/  action_mailer, rack_attack, content_security_policy, app_environment
db/data/              the two CSV files
spec/                 models, services, requests, mailers, factories; spec/api = OpenAPI contract specs
swagger/v1/           openapi.yaml, generated from spec/api
```

## Security

- Every query is parameterized; `LIKE` wildcards in search input are escaped.
- `sort` is whitelisted (`Movie::SORT_OPTIONS`), so user input never reaches `ORDER BY`.
- Pagination params are coerced and clamped, including array and hash params; search terms
  are capped at 100 characters.
- ERB escapes all output (covered by a spec); a strict Content-Security-Policy is sent.
- Passwords are bcrypt-hashed; API tokens are stored as SHA-256 digests; credentials, tokens
  and emails are filtered from logs by Rails' parameter filter.
- Login and token errors never reveal whether an account exists.
- Rate limits (Rack::Attack): API 120 requests/min per IP, token endpoint 10/min, password
  reset requests 5 per 15 min, plus Rails' `rate_limit` on web sign-in. Throttled requests get
  `429` with a `Retry-After` header.
- Production forces HTTPS, marks cookies Secure, and only accepts requests for `APP_HOST`.
- No secrets are committed: `.env` is git-ignored, only `.env.example` is tracked.
- CI runs Brakeman, bundler-audit and RuboCop on every push.

## Testing and quality

```bash
bundle exec rspec          # models, importer, HTML pages, API, API contract, authentication, throttling
bin/rubocop                # style (rails-omakase)
bin/brakeman               # security static analysis
bundle exec bundler-audit check --update
```

GitHub Actions (`.github/workflows/ci.yml`) runs the scan, audit, lint and test jobs against
a PostgreSQL service, and checks that `swagger/v1/openapi.yaml` matches the specs.

## Production notes

- Set `RAILS_MASTER_KEY` (or `SECRET_KEY_BASE`), `DATABASE_URL` and `APP_HOST`. Run
  `bin/rails db:prepare` on deploy; on a new database it also seeds the bundled CSV data
  (`bin/rails import:all` re-imports at any time).
- Rails generated a production `Dockerfile`; build it with `docker build -t movies_on_rails .`
  and pass the variables above with `-e`. `Dockerfile.dev` and `docker-compose.yml` are for
  development and tests only.
- **Email.** Real email delivery is intentionally not configured. For a demo deployment,
  set `MAIL_INBOX_USERNAME` and `MAIL_INBOX_PASSWORD`: emails are then kept in a web inbox at
  `/letter_opener`, protected by HTTP basic auth (and rate limited). Without them no email is
  sent. For real email, set `config.action_mailer.delivery_method` (SMTP or an email API) in
  `config/environments/production.rb`.
- **Shared cache.** Rack::Attack and `rate_limit` count requests in `Rails.cache`. With several
  servers, configure a shared cache store (Redis, Solid Cache or Memcached) so limits apply
  across processes.
- **Background jobs.** Reset emails are sent with `deliver_later`; the default in-process
  adapter is fine for one server. Use a real queue adapter if you scale out.
- Schedule `bin/rails auth:prune` daily.

### Deploying to Render

`render.yaml` is a [Render Blueprint](https://render.com/docs/blueprint-spec): a free web
service built from `./Dockerfile` and a free PostgreSQL database.

1. In Render, choose **New > Blueprint** and select this repository.
2. Render creates the database, generates `SECRET_KEY_BASE`, sets `DATABASE_URL` and
   `SEED_DEMO_USER=true`, and asks for `MAIL_INBOX_PASSWORD` (leave it empty to keep the email
   inbox off). `APP_HOST` defaults to the service's `onrender.com` host name.
3. On start, `bin/docker-entrypoint` runs `bin/prepare-database`: on the empty database
   `db:prepare` creates the schema, imports the bundled CSV files and adds the demo account;
   later starts skip it unless a migration is pending.

Free services sleep after 15 idle minutes (the next request takes about a minute), and
Render deletes free databases 30 days after creation. To keep the data longer, point
`DATABASE_URL` at another PostgreSQL database, for example a free Neon one.

### Deploying to Vercel

`Dockerfile.vercel` runs the app on [Vercel's container runtime](https://vercel.com/docs/functions/runtimes/container),
with a free [Neon](https://neon.com) Postgres database from the Vercel Marketplace.

1. Import the GitHub repository as a new Vercel project (no build settings needed: Vercel
   detects `Dockerfile.vercel`).
2. In the project's **Storage** tab, add a Neon database. It sets `DATABASE_URL` and
   `DATABASE_URL_UNPOOLED`; the app uses the unpooled one.
3. Add environment variables: `PORT=3000`, `APP_HOST` (the production domain, unless system
   environment variables are exposed), `SECRET_KEY_BASE` (`bin/rails secret`; when missing,
   `bin/vercel-start` derives one from the database URL), and optionally
   `MAIL_INBOX_USERNAME` / `MAIL_INBOX_PASSWORD` for the email inbox. If the Marketplace
   prefixed the database variables, set `DATABASE_URL_FROM` to the name of the unpooled one
   (for example `movies_DATABASE_URL_UNPOOLED`).
4. Deploy. On start, `bin/vercel-start` runs `bin/prepare-database` (see Render above).

Status: on a Hobby account the image builds and is pushed, but every deployment so far has
stopped at the final step with "internal Vercel error" (Container Runtime is in beta), so
the live demo runs on Render.

Things to know: idle instances stop after a few minutes, so the first request afterwards
takes a few seconds; rate limits are counted per instance (in-memory cache); and the email
inbox lives in the instance's `/tmp`, so messages disappear when it stops.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `PG::ConnectionBad` without Docker | Start PostgreSQL, or set `DATABASE_URL` |
| Port 3000 already in use with Docker | Set `APP_PORT=3001` in `.env` and restart |
| `Missing required environment variables: APP_HOST` | Production only - set `APP_HOST` |
| Empty movie list | Run `bin/rails import:all` |
| `Import failed, nothing was changed` | Fix the file named in the message (missing column or malformed CSV) |
| Cannot sign in | Create a user: `bin/rails users:create EMAIL=...` |
| `A server is already running` | Delete `tmp/pids/server.pid` (Docker does this automatically) |
| Reset email did not appear | Docker: open `/letter_opener`. Local: check the browser opened a tab |
| Gems missing inside Docker after editing the Gemfile | `docker compose build web` |
| Want a clean database in Docker | `docker compose down -v` |

## Known limitations

- Movie titles are unique, because reviews.csv identifies movies by title alone; two films
  with the same title (a remake, say) would need the year added to the files.
- movies.csv is collapsed in memory (one entry per unique movie, actor and location), which
  is fine for catalogs of millions of rows; reviews.csv is streamed.
- Deep pages use `OFFSET`, which slows down far into a large list; keyset pagination would be
  the next step.
- No public signup, email verification, two-factor authentication or roles: every signed-in
  user can read everything (the app has no per-user data).
- There are no endpoints for creating reviews; data enters through the CSV import.
