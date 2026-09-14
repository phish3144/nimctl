# Contributing

Thanks for helping! Keep it small and testable.

1. Fork, branch from `main`.
2. Make your change in `nimctl` (single file, bash 4.3+, no other runtime dependencies than `curl` and `jq`).
3. Run `shellcheck -S warning nimctl install.sh tests/run.sh` and `bash tests/run.sh` – both must pass.
   The tests use `tests/mock_api.py`; if you add behaviour that depends on the API, extend the mock.
4. Add UI strings to **both** `T_de` and `T_en`.
5. Open a pull request with a short description of the *user-visible* change.

Bug reports: please include `nimctl doctor` output and `~/.nimctl/logs/*.log`.
