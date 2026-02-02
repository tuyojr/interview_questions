# Server Stats Script

This is a minimal, easy-to-read script for basic Linux server stats. A project from [roadmap.sh's DevOps projects](https://roadmap.sh/projects/server-stats)

> [https://roadmap.sh/projects/server-stats](https://roadmap.sh/projects/server-stats)

## Usage

```BASH
chmod +x server-stats.sh
./server-stats.sh
```

## What it prints

- OS version, uptime, load average
- Total CPU usage (average since boot)
- Memory usage (used vs free, percentages)
- Disk usage (used vs free, percentages)
- Top 5 processes by CPU and memory
- Logged-in users
- Failed login attempts (if auth logs are readable)

## Notes

- Memory is shown in KB using `/proc/meminfo`.
- Disk totals exclude `tmpfs` and `devtmpfs`.
- Failed logins are counted from `"Failed password"` in:
  - `/var/log/auth.log`
  - `/var/log/secure`
  Reading these logs may require `sudo`.
