<!-- parallel-checkouts template v1 (bendyworks/claude-skills) -->

# Parallel Checkouts

This repository can be cloned more than once on the same machine, with each
clone (a *checkout*) running its own dev server and its own full test suite
at the same time as the others. Each checkout is a full, permanent clone, not
a git worktree: git refuses to check out one branch in two worktrees, and two
worktrees of one checkout would share its test database anyway.

Nothing here is required. A checkout that sets none of the variables below
behaves exactly as before, on the same ports and databases.

## How it works

A checkout's identity is a handful of `PRM_*` variables its untracked
`.envrc` ([direnv](https://direnv.net/)) exports. Everything two checkouts
would otherwise share reads them, falling back to the old value when unset:

| What | Where | Variable | Default |
| --- | --- | --- | --- |
| Development database | `config/database.yml` | `PRM_CHECKOUT_SUFFIX` | `prmetrics_development` |
| Test database | `config/database.yml` | `PRM_CHECKOUT_SUFFIX` | `prmetrics_test` |
| Sidekiq's Redis (and the health check of it) | `config/initializers/sidekiq.rb`, `app/controllers/health_controller.rb` | `PRM_JOBS_REDIS_URL`, then `REDIS_URL` | `redis://localhost:6379/0` |
| Dev server port | `config/puma.rb`, `Procfile.dev` | `PORT`, `PRM_APP_PORT` | `3000` |

Postgres and Redis stay one shared server each; a checkout is isolated
inside them by database name and Redis database number. Sidekiq is the only
Redis role development and test use (Action Cable uses Redis only in
production), so checkout N's Sidekiq database is N - 1.

The test suite pins no ports: Capybara picks a free port for its server and
Selenium Manager starts chromedriver on one.

`config/initializers/parallel_checkout_guard.rb` refuses to boot development
or test when `PRM_CHECKOUT_ROOT` names a different directory than the code
being run: a shell still carrying one checkout's identity would otherwise
point another checkout's code at the first checkout's databases. From a
shell outside a checkout, use `direnv exec <checkout> <command>`, which loads
that checkout's environment without changing directory, with absolute paths.

## The `.envrc` identity block

For checkout N (the original checkout is 1 and needs no block):

```bash
# Parallel-checkout identity. See docs/parallel-checkouts.md.
export PRM_CHECKOUT_SUFFIX=<N>
export PRM_CHECKOUT_INDEX=<N - 1>
export PRM_PORT_OFFSET=$((200 * PRM_CHECKOUT_INDEX))
export PRM_CHECKOUT_ROOT="$PWD"
export PRM_APP_PORT=$((3000 + PRM_PORT_OFFSET))
export PORT=$PRM_APP_PORT
export PRM_JOBS_REDIS_URL="redis://localhost:6379/$((0 + PRM_CHECKOUT_INDEX))"
```

## Checkout registry

| Checkout | Suffix | Index | Port offset |
| --- | --- | --- | --- |
| `~/dev/prmetrics` | (none) | 0 | 0 |

## Adding a checkout

1. Clone into a sibling directory named `prmetricsN` from `origin`.
2. Copy `config/master.key` from the original checkout, and the lines of its
   `.git/info/exclude`.
3. Copy the original `.envrc`, add the identity block above, and
   `direnv allow`.
4. Check the block is free: no listener on its dev-server port
   (`lsof -nP -iTCP:<port> -sTCP:LISTEN`), and its Redis database number
   below the server's count (`redis-cli CONFIG GET databases`, 16 by default).
5. `bundle install`, then `bin/rails db:create db:schema:load` for
   development and test.
6. Start the full suite (`bundle exec rake`) here and in another checkout at
   the same moment; both must pass with identical example counts.
7. Add a row to the registry.

## Caveats

- **One branch, one session.** Give each checkout's session its own branch;
  both on `main` for verification is fine.
- **Worktrees inside a checkout share its identity**, so two full suites run
  from two worktrees of one checkout still collide.
- **Machine-level singletons stay single:** a browser-automation session in
  your own browser, a production deploy.
