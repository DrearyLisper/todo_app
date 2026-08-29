# todo_app

A simple full-stack TODO web app built with [Lustre](https://hexdocs.pm/lustre)
following the [full-stack applications guide](https://lustre.hexdocs.pm/guide/06-full-stack-applications.html).

Monorepo with three Gleam projects:

- `client/` — Lustre SPA (JavaScript target) with create / check / delete todos
- `server/` — Wisp + Mist server, server-side renders the page and exposes a
  `POST /api/todos` endpoint
- `shared/` — `TodoItem` type plus JSON encoding/decoding shared by both sides

Todos are persisted to JSON files on disk via [storail](https://hexdocs.pm/storail)
under `server/data/`.

## Running

Build the client bundle into the server's static directory:

```sh
cd client
gleam run -m lustre/dev build --outdir=../server/priv/static --no-html=true
```

Then start the server:

```sh
cd server
gleam run
```

Open <http://localhost:3000>.

## Development

Run the server as above, and in another terminal start the Lustre dev server,
which hot-reloads the client and proxies `/api` to `localhost:3000`:

```sh
cd client
gleam run -m lustre/dev start
```

Tests:

```sh
(cd shared && gleam test)
(cd client && gleam test)
(cd server && gleam test)
```
