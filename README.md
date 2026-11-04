# docker-img-shrink

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Required-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Platform](https://img.shields.io/badge/Runs_on-Windows-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows)

Shrinks Linux SD card images (Raspberry Pi OS, Kali, Ubuntu, …) on Windows with Docker. The result is small and grows back to the full card size on first boot.

Based on [Drewsif/PiShrink](https://github.com/Drewsif/PiShrink) (MIT).

## Quick Start

1. Install and start Docker Desktop.
2. Put one image into `Input/` (`.img`, `.img.gz`, `.img.bz2` or `.img.xz`).
3. Run in the project folder (or double-click `windows/build.bat`):

```powershell
docker compose run --build --rm pishrink
```

4. Result: `Output/<input name>_shrunk.img.gz`

Use `run`, not `up`. Only `run` shows the progress bars.

## Settings

In `docker-compose.yml` under `environment:`, or per run:

```powershell
docker compose run --build --rm -e OUT_NAME=my_pi -e COMPRESS=none pishrink
```

| Variable | Default | Meaning |
|---|---|---|
| `OUT_NAME` | `<input name>_shrunk` | Output file name without extension |
| `COMPRESS` | `gz` | `gz` → `.img.gz`, `none` → raw `.img` |

## Win32 Disk Imager

- **Read:** choose a target `.img`, tick *Read Only Allocated Partitions*, click *Read*.
- **Write:** only raw `.img` works. Set `COMPRESS=none` or unpack the `.img.gz` with 7-Zip. Raspberry Pi Imager and balenaEtcher write `.img.gz` directly.
- The target card must be at least as large as the shrunk image.

## Free Space

- About **N** free on the project drive, N = uncompressed image size (32 GB card → 32 GB).
- The input file stays untouched. Temporary files in `Output/.work/` are deleted after the run, also on errors.

## Steps

| Step | Does | Progress bar |
|---|---|---|
| 1/4 | Copy or unpack the input into a working copy | yes |
| 2/4 | Shrink filesystem, partition and file (PiShrink) | no, log lines only |
| 3/4 | Install a one-time service that expands the root partition on first boot, then reboots | – (seconds) |
| 4/4 | Compress with `pigz` on all cores (skipped with `COMPRESS=none`) | yes |

## License

MIT, see [LICENSE](LICENSE).
