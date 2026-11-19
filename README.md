# TheHostBoy checker for POSIX shell

Measures a bounded SHA-256 workload and temporary-file read/write timing, then submits one schema v1 report to TheHostBoy. Runtime-visible memory and CPU limits are unavailable in this shell checker and are reported as `null`.

## Requirements

- POSIX-compatible `/bin/sh`
- `curl`, `sha256sum`, `awk`, `dd`, `date`, `mktemp`, `od`, `tr`, and `sleep`
- HTTPS access to your TheHostBoy instance

The `date` implementation's nanosecond format is used when available; otherwise timing falls back to seconds and is less precise.

## Community checker setup

Create an account and checker installation on TheHostBoy, verify a domain you control, and copy the one-time key. Use the community report endpoint:

```sh
export HOSTBOY_REPORT_URL='https://HOSTBOY_DOMAIN/api/v1/community/reports'
export HOSTBOY_CHECKER_KEY='YOUR_INSTALLATION_KEY'
./hostboy-checker.sh
```

The report URL and key are provided by TheHostBoy. Keep the key private; it allows submissions for this installation. To run periodically, configure both environment variables in the hosting account's cron environment and schedule `/absolute/path/hostboy-checker.sh`. Do not commit a key or a `.env` file.

The script sends a report at most once per run, retries bounded transient failures, limits each request to 10 seconds, and does not follow redirects. It performs local CPU and temporary-storage work; it does not scan site files or collect visitor data.

The default endpoint for a user-contributed installation is `/api/v1/community/reports`. Provider-authorized installations use the exact report URL supplied by an administrator. Community results are labeled self-reported and kept out of provider plan rankings.
