# CLAUDE.md

Usage, steps and logging are documented in `README.md`. These are the rules for
changing the script:

- **Never run `./upgrade.sh` without `--dry-run`.** A real run upgrades the whole
  machine, and the greedy cask step can block waiting for an admin password.
- **Keep `brew` and `mise` as absolute paths** (`/opt/homebrew/bin/...`). The
  script must work from cron/launchd, where the interactive shell isn't loaded
  and `mise` is not on `PATH`.
- **Only `brew update` is fatal.** New steps use `warn` unless nothing after
  them can work when they fail.

To check a change:

    bash -n upgrade.sh
    shellcheck upgrade.sh     # if installed
    ./upgrade.sh --dry-run
