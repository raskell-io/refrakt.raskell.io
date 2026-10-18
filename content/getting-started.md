+++
title = "Getting started"
description = "Install Refrakt and build a blog with posts, authentication and an about page. About ten minutes."
[extra]
eyebrow = "Tutorial"
toc = true
next = { title = "CLI reference", url = "/cli/" }
+++

## What you need

- [Gleam](https://gleam.run/getting-started/installing/) 1.14 or later
- Erlang/OTP 27 or later, and rebar3
- PostgreSQL running locally for this tutorial. With `--db sqlite` you need no database server at all.

If you use [mise](https://mise.jdx.dev/):

```sh
mise use gleam@1.14 erlang@27 rebar@3
```

## Install the CLI

Refrakt comes as two packages on Hex: `refrakt`, the small library your app uses at runtime, and `refrakt_cli`, the code generator. The CLI runs with `gleam run` from inside a Gleam project, so to create your first app, borrow a throwaway project for a moment:

```sh
gleam new refrakt_bootstrap && cd refrakt_bootstrap
gleam add --dev refrakt_cli
gleam run -m refrakt_cli -- new ../blog --db postgres
cd ../blog && rm -rf ../refrakt_bootstrap
```

Projects created by `refrakt new` list `refrakt_cli` as a dev-dependency, so from now on the CLI runs inside your app and never ships with it. The rest of this page uses an alias:

```sh
alias refrakt='gleam run -m refrakt_cli --'
```

## 1. Create the project

```sh
refrakt new blog --db postgres
cd blog
```

`refrakt new` also accepts a path, such as `refrakt new ../blog`; the last segment becomes the package name. Without `--db` you get a project with no database.

```
blog/
  src/
    blog.gleam                    ← entry point
    blog/
      config.gleam                ← reads PORT, SECRET_KEY_BASE, APP_ENV
      context.gleam               ← shared Context type
      router.gleam                ← all routes, pattern matched
      web/
        home_handler.gleam        ← GET /
        error_handler.gleam       ← 404, 500
        layouts/root_layout.gleam ← HTML shell
        components/flash.gleam    ← flash message component
      data/
        repo.gleam                ← database connection
  priv/static/                    ← CSS, JS
  test/
```

Check that it compiles and its tests pass:

```sh
gleam build
gleam test
```

## 2. Create the database

```sh
createdb blog_dev
```

The generated `repo.gleam` connects to `postgres://localhost:5432/blog_dev` by default, so local development needs no configuration.

## 3. Generate a posts resource

```sh
refrakt gen resource posts title:string body:text published:bool
```

This writes seven files and adds seven routes to the router:

| File | What it is |
|---|---|
| `web/post_handler.gleam` | `index`, `show`, `new`, `create`, `edit`, `update`, `delete` |
| `web/post_views.gleam` | Lustre views: list, detail, form |
| `web/forms/post_form.gleam` | `PostForm`, `PostParams` and a validating `decode` |
| `domain/post.gleam` | The `Post` type. No framework imports. |
| `data/post_repo.gleam` | Raw SQL through Pog, with a typed decoder |
| `data/migrations/001_create_posts.sql` | The `posts` table |
| `test/blog/web/post_handler_test.gleam` | Form decoder tests |

Field types are `string`, `text`, `int`, `float`, `bool`, `date` and `datetime`. See the [field types guide](https://github.com/raskell-io/refrakt/blob/main/docs/field-types.md) for how each maps to Gleam, HTML and SQL.

Print the routes:

```sh
refrakt routes
```

```
GET     /                   home_handler.index
GET     /posts              post_handler.index
GET     /posts/new          post_handler.new
POST    /posts              post_handler.create
GET     /posts/:id          post_handler.show
GET     /posts/:id/edit     post_handler.edit
PUT     /posts/:id          post_handler.update
DELETE  /posts/:id          post_handler.delete
```

## 4. Run the migration

Migrations are plain SQL files. Apply this one with `psql`:

```sh
psql blog_dev < src/blog/data/migrations/001_create_posts.sql
```

Or let Refrakt do it: `refrakt migrate` writes a small `src/blog/migrate.gleam` module the first time, then runs every pending file in `data/migrations/` and records it in a `_migrations` table.

## 5. Start the server

```sh
gleam run
```

Open <http://localhost:4000/posts> and click **New Post**. Submit the form empty and you get the validation errors back; fill it in and you are redirected to the new post with a flash message.

## 6. Read the generated code

The router is one `case` expression:

```gleam
case wisp.path_segments(req), req.method {
  [], http.Get -> home_handler.index(req, ctx)

  ["posts"], http.Get -> post_handler.index(req, ctx)
  ["posts", "new"], http.Get -> post_handler.new(req, ctx)
  ["posts"], http.Post -> post_handler.create(req, ctx)
  ["posts", id], http.Get -> post_handler.show(req, ctx, id)
  ["posts", id, "edit"], http.Get -> post_handler.edit(req, ctx, id)
  ["posts", id], http.Put -> post_handler.update(req, ctx, id)
  ["posts", id], http.Delete -> post_handler.delete(req, ctx, id)
  _, _ -> error_handler.not_found(req)
}
```

The domain type is a plain Gleam type:

```gleam
pub type Post {
  Post(id: Int, title: String, body: String, published: Bool)
}
```

The form decoder validates with functions from `refrakt/validate` and returns either clean params or a list of errors:

```gleam
pub fn decode(
  data: wisp.FormData,
) -> Result(PostParams, List(#(String, String))) {
  let title = get_value(data, "title")
  let body = get_value(data, "body")

  let errors =
    []
    |> validate.required(title, "title", "Title is required")
    |> validate.required(body, "body", "Body is required")

  case errors {
    [] ->
      Ok(PostParams(
        title: title,
        body: body,
        published: list.any(data.values, fn(v) { v.0 == "published" }),
      ))
    _ -> Error(errors)
  }
}
```

Besides `required`, `refrakt/validate` has `min_length`, `max_length`, `inclusion` and `format`. All of it is yours to edit.

## 7. Add authentication

```sh
refrakt gen auth
```

| File | What it is |
|---|---|
| `web/auth_handler.gleam` | Login, register and logout handlers |
| `web/auth_views.gleam` | Login and register forms |
| `web/forms/auth_form.gleam` | Credential validation |
| `web/middleware/auth.gleam` | `require_auth` and `get_current_user` |
| `domain/user.gleam` | The `User` type |
| `domain/auth.gleam` | Password hashing |
| `data/user_repo.gleam` | User queries |
| `data/migrations/002_create_users.sql` | The `users` table |
| `test/blog/web/auth_handler_test.gleam` | Tests |

Sessions are a signed, expiring cookie, and cross-site form submissions are rejected with a 403. Passwords are hashed with Argon2id through the [argus](https://hex.pm/packages/argus) package, which `gen auth` adds to your `gleam.toml`; argus compiles a small C library, so building it needs a C compiler.

Run the new migration:

```sh
psql blog_dev < src/blog/data/migrations/002_create_users.sql
```

Five routes are added:

```
GET     /login              auth_handler.login_page
POST    /login              auth_handler.login
GET     /register           auth_handler.register_page
POST    /register           auth_handler.register
POST    /logout             auth_handler.logout
```

## 8. Protect a route

`require_auth` is a Wisp-style middleware: use it at the top of a handler. Edit `create` in `src/blog/web/post_handler.gleam`:

```gleam
import blog/web/middleware/auth

pub fn create(req: Request, ctx: Context) -> Response {
  use _user <- auth.require_auth(req, ctx)
  use form_data <- wisp.require_form(req)
  // ... the rest of create
}
```

Without a session, the request is redirected to `/login`.

## 9. Add a page

```sh
refrakt gen page about
```

This writes `web/about_handler.gleam` and a test, and adds `GET /about` to the router. Put your content in the handler:

```gleam
pub fn index(_req: Request, _ctx: Context) -> Response {
  section([class("about")], [
    h1([], [text("About This Blog")]),
    p([], [text("Built with Refrakt and Gleam.")]),
  ])
  |> root_layout.wrap("About")
  |> wisp.html_response(200)
}
```

## 10. Run the tests

The tests that touch the database use a separate test database. Create it once:

```sh
createdb blog_test
gleam test
```

Each test runs inside a transaction that is rolled back afterwards, so the test database stays empty. The generated tests create, show, update and delete a post through the router, register and log in a user, check that invalid forms and cross-site requests are rejected, and check that password hashing round-trips. Set `DATABASE_URL` to use a different test database.

## What you have

- Seven post routes with forms and validation
- Five auth routes: register, login, logout
- An about page
- Raw SQL you can read, Lustre views the compiler checks, and tests that run against a real database

Every file is plain Gleam that you own. From here:

- Edit the CSS in `priv/static/css/app.css`
- Add a second resource: `refrakt gen resource comments body:text --belongs-to posts`
- Run `refrakt dev`: it rebuilds on every change and your browser reloads by itself
- Deploy with `refrakt gen deploy --fly`, which writes a Dockerfile and `fly.toml`; the [deployment guide](https://github.com/raskell-io/refrakt/blob/main/docs/deployment.md) has the details
- After upgrading Refrakt, run `refrakt diff` to see what changed in the templates

The complete result is in the repository as [`examples/blog`](https://github.com/raskell-io/refrakt/tree/main/examples/blog).
