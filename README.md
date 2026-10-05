# Daily macOS upgrade

`upgrade.sh` runs the daily routine in order:

1. `brew update` — **fatal**: if fetching formulae fails, the rest is pointless
2. `brew upgrade`
3. `brew upgrade --cask --greedy`
4. `brew autoremove`
5. `brew doctor`
6. `brew cleanup --prune=all`
7. `mise upgrade`

Steps 2–7 are non-fatal: a failure is recorded and the run continues, so one
broken cask doesn't stop the cleanup. `brew doctor` in particular exits non-zero
for purely advisory warnings, so it is never treated as fatal.

## Usage

    ./upgrade.sh                 # full run
    ./upgrade.sh --dry-run       # print the steps, change nothing
    ./upgrade.sh --skip-casks    # skip the slow greedy cask upgrade
    ./upgrade.sh --quiet         # log only, no terminal output

Exit code is 1 only if a fatal step failed; advisory failures exit 0.

## Logs

One file per day in `~/.local/state/upgrade/upgrade-YYYY-MM-DD.log`
(override with `UPGRADE_LOG_DIR`). Files older than 30 days are deleted at the
end of each run.

## Notes

- `brew` and `mise` are called by absolute path (`/opt/homebrew/bin/...`) so the
  script works from cron/launchd where the interactive shell isn't loaded —
  `mise` is a shell function in an interactive zsh, not a binary on `PATH`.
- `--greedy` also upgrades casks that update themselves. Some casks ask for the
  admin password, which will block the run waiting on input. If you want it
  fully unattended, use `--skip-casks` and run the cask step by hand.

## Not yet covered (second iteration)

- Apple system updates (`softwareupdate -l` / `-ia`)
- App Store updates (`mas upgrade`)
- JetBrains updates (via JetBrains Toolbox)

## License

[MIT](LICENSE)
