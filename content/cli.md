+++
title = "CLI reference"
description = "Every refrakt command, what it writes, and what it changes in your project."
[extra]
eyebrow = "Reference"
toc = true
next = { title = "Getting started", url = "/getting-started/" }
+++

## Running the CLI

The CLI is the `refrakt_cli` package, a dev-dependency of every project made by `refrakt new`. Run it from inside the project:

```sh
gleam run -m refrakt_cli -- <command>

# or, with an alias
alias refrakt='gleam run -m refrakt_cli --'
refrakt <command>
```

To create your first project, run it from a throwaway one:

```sh
gleam new refrakt_bootstrap && cd refrakt_bootstrap
gleam add --dev refrakt_cli
gleam run -m refrakt_cli -- new ../my_app --db sqlite
cd ../my_app && rm -rf ../refrakt_bootstrap
```

Commands that work on an existing project read the app name from `gleam.toml` and detect the database from its dependencies (`pog` for PostgreSQL, `sqlight` for SQLite). Everything a generator writes is run through `gleam format`.

| Command | |
|---|---|
| [`new <name>`](#new) | Create a project |
| [`gen resource <name> <fields...>`](#gen-resource) | Full CRUD resource, or a JSON API with `--api` |
| [`gen page <name>`](#gen-page) | A page handler and route |
| [`gen auth`](#gen-auth) | Register, login, logout, sessions |
| [`gen island <name>`](#gen-island) | A Lustre client-side island |
| [`gen live <name>`](#gen-live) | A Lustre server component over WebSocket |
| [`gen migration <name>`](#gen-migration) | An empty SQL migration |
| [`routes`](#routes) | Print the route table |
| [`migrate`](#migrate) | Run pending migrations |
| [`seed`](#seed) | Run database seeds |
| [`build`](#build) | Compile islands to JavaScript |
| [`assets setup`, `assets build`](#assets) | Tailwind CSS setup and build |
| [`dev`](#dev) | Dev server, rebuilds on change |
| [`help`, `version`](#help-and-version) | |

## new

```sh
refrakt new my_app
refrakt new my_app --db postgres
refrakt new my_app --db sqlite
refrakt new path/to/my_app    # the package is named my_app
```

| Flag | |
|---|---|
| `--db postgres` | Add Pog and a `data/repo.gleam` that connects to PostgreSQL |
| `--db sqlite` | Add Sqlight and a `data/repo.gleam` for SQLite |
| none | No database |

Writes the entry point, typed config (`PORT`, `SECRET_KEY_BASE`, `APP_ENV`), the shared `Context`, the router, a home handler, an error handler, the root layout, a flash component, CSS and JS in `priv/static/`, and tests. When `APP_ENV` is `dev` (the default), the router's middleware turns a crash into a page showing the error, the stack trace and the request; in `test` and `prod` it logs the crash and returns a plain 500. Set `APP_ENV=prod` in production.

## gen resource

```sh
refrakt gen resource posts title:string body:text published:bool
refrakt gen resource products name:string price:float stock:int
refrakt gen resource comments body:text --belongs-to posts
refrakt gen resource posts title:string body:text --api
```

The name is plural. Types and files use the singular: `Post`, `post_handler.gleam`, `post_repo.gleam`.

It needs a project created with `--db postgres` or `--db sqlite`; in a project without a database it stops and writes nothing.

**HTML mode** writes:

- `web/<singular>_handler.gleam`: `index`, `show`, `new`, `create`, `edit`, `update`, `delete`
- `web/<singular>_views.gleam`: `index_view`, `show_view`, `form_view`
- `web/forms/<singular>_form.gleam`: the form and params types, `empty`, `from_<singular>`, `from_form_data`, `decode`
- `domain/<singular>.gleam`: the domain type
- `data/<singular>_repo.gleam`: `list`, `get`, `create`, `update`, `delete` in raw SQL
- `data/migrations/NNN_create_<name>.sql`
- `test/<app>/web/<singular>_handler_test.gleam`

and adds seven routes to the router: `GET /posts`, `GET /posts/new`, `POST /posts`, `GET /posts/:id`, `GET /posts/:id/edit`, `PUT /posts/:id`, `DELETE /posts/:id`.

**`--api`** writes a JSON handler, a params type, the domain type, the repo, the migration and tests, with no views or forms. It adds five routes under `/api/`: `GET` and `POST /api/posts`, and `GET`, `PUT`, `DELETE /api/posts/:id`. `index`, `show` and `delete` are complete; `create` and `update` return 501 with a TODO where you decode the JSON body.

**`--belongs-to <parent>`** adds an `int` foreign key field named after the singular parent, such as `post_id`.

### Field types

| Type | Gleam | HTML input | PostgreSQL | SQLite |
|---|---|---|---|---|
| `string` | `String` | text | `TEXT` | `TEXT` |
| `text` | `String` | textarea | `TEXT` | `TEXT` |
| `int` | `Int` | number | `INTEGER` | `INTEGER` |
| `float` | `Float` | number | `DOUBLE PRECISION` | `REAL` |
| `bool` | `Bool` | checkbox | `BOOLEAN` | `INTEGER` |
| `date` | `String` | text | `DATE` | `TEXT` |
| `datetime` | `String` | text | `TIMESTAMPTZ` | `TEXT` |

`string` and `text` fields get a `validate.required` check in the form decoder. Other types are parsed but not validated; add your own checks.

## gen page

```sh
refrakt gen page about
```

Writes `web/about_handler.gleam` with an `index` handler and a test, and adds `GET /about`.

## gen auth

```sh
refrakt gen auth
```

Writes the `User` domain type, password hashing in `domain/auth.gleam`, `data/user_repo.gleam`, a users migration, `web/auth_handler.gleam`, `web/auth_views.gleam`, `web/forms/auth_form.gleam`, `web/middleware/auth.gleam` and tests. Adds five routes: `GET` and `POST /login`, `GET` and `POST /register`, `POST /logout`. Like `gen resource`, it needs a project with a database.

The session is a signed cookie. Protect a handler with the generated middleware:

```gleam
pub fn create(req: Request, ctx: Context) -> Response {
  use _user <- auth.require_auth(req, ctx)
  // ...
}
```

Passwords are hashed with Argon2id (random salt per hash, constant-time verify) through the [argus](https://hex.pm/packages/argus) package, which the command adds to `gleam.toml`. Building argus needs a C compiler.

## gen island

```sh
refrakt gen island counter
```

Writes `web/islands/counter.gleam`, a Lustre client-side app with `init`, `update` and `view`, and `web/islands/counter_embed.gleam`, whose `render()` and `script_tag()` put the island into a server-rendered view. Build the JavaScript with [`refrakt build`](#build).

## gen live

```sh
refrakt gen live dashboard
```

Writes a Lustre server component in `web/live/dashboard.gleam`, its WebSocket module `web/live/dashboard_socket.gleam`, and `web/dashboard_live_handler.gleam`, the page that connects to it. Adds `GET /dashboard`. The component runs on the BEAM and sends DOM patches to the browser over the socket.

## gen migration

```sh
refrakt gen migration add_email_to_posts
```

Writes an empty, numbered SQL file such as `data/migrations/003_add_email_to_posts.sql`. The number is the next one in the directory.

## routes

```sh
refrakt routes
```

Reads `router.gleam` and prints method, path and handler:

```
GET     /posts              post_handler.index
GET     /posts/new          post_handler.new
POST    /posts              post_handler.create
GET     /posts/:id          post_handler.show
```

## migrate

```sh
refrakt migrate
```

The first time, writes `src/<app>/migrate.gleam`, a module that connects to your database and calls `refrakt/migrate`. Then runs it with `gleam run -m <app>/migrate`. Pending `.sql` files in `data/migrations/` are applied in order and recorded in a `_migrations` table. There are no down migrations.

## seed

```sh
refrakt seed
```

The first time, writes `src/<app>/seed.gleam` for you to fill with sample data. Then runs it with `gleam run -m <app>/seed`.

## build

```sh
refrakt build
```

Compiles the island modules in `web/islands/` with `gleam build --target javascript` and copies the output to `priv/static/js/islands/`.

## assets

```sh
refrakt assets setup
refrakt assets build
```

`setup` writes `tailwind.config.js` and `assets/css/app.css` (it needs `npx`, so Node.js). `build` runs the Tailwind CLI and writes a minified `priv/static/css/app.css`. Without them, the plain `priv/static/css/app.css` from `refrakt new` is used as is.

## dev

```sh
refrakt dev
```

Sets `APP_ENV=dev` and runs `gleam run`. If [fswatch](https://github.com/emcrisostomo/fswatch) is installed, it watches `src/` and rebuilds and restarts the server on every change.

## help and version

```sh
refrakt help        # also --help, -h
refrakt version     # also --version, -v
```
