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
production), so the stride is 1 and checkout N's Sidekiq database is N - 1.

The test suite pins no ports: Capybara picks a free port for its server and
Selenium Manager starts chromedriver on one.

`config/initializers/00_parallel_checkout_guard.rb` refuses to boot
development or test when the shell's identity does not belong to the code
being run: when `PRM_CHECKOUT_ROOT` names a different checkout (a shell still
carrying one checkout's identity), or when the checkout's marker names a
suffix the shell does not carry (a second checkout run with no identity
loaded). Either would point one checkout's code at another checkout's
databases. The marker is a file named `parallel-checkout` in the clone's git
directory, where `git clean` cannot reach it and every worktree of the clone
finds it. The original checkout has no marker and sets nothing, so it always
boots.

To run a command in a checkout from a shell that is not already in it, use
`direnv exec <checkout> <command>`, which loads that checkout's environment
without changing directory: `cd <checkout> && direnv exec . <command>`.

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

## Adding a checkout

1. Clone into a sibling directory named `prmetricsN` from `origin`.
2. Copy `config/master.key` from the original checkout, and the lines of its
   `.git/info/exclude`.
3. Copy the original `.envrc`, add the identity block above, record the
   suffix in the git directory
   (`printf 'N\n' > "$(git rev-parse --path-format=absolute --git-common-dir)/parallel-checkout"`),
   and `direnv allow`.
4. Check the block is free: no listener on its dev-server port
   (`lsof -nP -iTCP:<port> -sTCP:LISTEN`), and its Redis database number
   below the server's count and empty (`redis-cli -n <db> CONFIG GET databases`,
   16 by default, and `redis-cli -n <db> DBSIZE`, 0).
5. `direnv exec . bundle install`, then check that
   `direnv exec . bin/rails runner 'puts ActiveRecord::Base.connection_db_config.database'`
   prints `prmetrics_developmentN`, then
   `direnv exec . bin/rails db:create db:schema:load` (development and test).
6. Start the full suite (`bundle exec rake`) here and in another checkout at
   the same moment; both must pass with identical example counts.

## Caveats

- **One branch, one session.** Give each checkout's session its own branch;
  both on `main` for verification is fine.
- **Worktrees share their checkout's identity**, so two full suites run from
  two worktrees of one checkout still collide.
- **Machine-level singletons stay single:** a browser-automation session in
  your own browser, a production deploy.
