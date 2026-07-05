# docker-img-shrink

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Required-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Platform](https://img.shields.io/badge/Runs_on-Windows-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows)

Shrink Linux disk images on Windows using Docker. Takes a raw `.img` (or compressed `.img.gz` / `.img.bz2` / `.img.xz`), strips unused space, injects an auto-expand-root service, and spits out a tightly compressed result with `pigz`.

Wraps the [Drewsif/PiShrink](https://github.com/Drewsif/PiShrink) script — works for **any Linux image** (Raspberry Pi OS, Ubuntu, Debian, Armbian, etc.), not just Pi images.

---

## What It Does

1. Pick up any Linux `.img` from `Input/`
2. Run `pishrink.sh` to reclaim free space
3. Mount the image and install an `expand-root.service` — on first boot the system resizes its root partition to fill the disk
4. Compress everything with `pigz` (all cores, max compression)
5. Drop the result into `Output/`

---

## How It Works

When you run `docker compose up --build`, the container runs `scripts/run.sh` which does this:

**1. Decompress**
The input file (`.img`, `.img.gz`, `.img.bz2`, or `.img.xz`) is copied from `/input` into a temp workspace. Compressed formats are decompressed with `gunzip`, `bunzip2`, or `xz`.

**2. Shrink**
The upstream [pishrink.sh](https://github.com/Drewsif/PiShrink) script runs on the raw image. It mounts the image's partitions, zeros out free space, removes logs and temporary files, then truncates the image to the smallest possible size.

**3. Inject expand-root**
The shrunk image is attached as a loop device with `losetup`. `kpartx` maps the partitions, the ext4 root partition is mounted, and two files are copied in:

- `expand-root.sh` → `/usr/local/sbin/` inside the image
- `expand-root.service` → `/etc/systemd/system/` and enabled via `chroot`

The image is then unmounted, the loop device detached.

**4. Compress**
`pigz` compresses the final `.img` with all CPU cores at maximum compression level (`-9`).

**5. Output**
The `.img.gz` file is moved to the `/output` volume — appears as `Output/shrunk_image.img.gz` on your host.

---

## Quick Start

### Requirements

- Docker Desktop for Windows
- A Linux `.img` file (raw, gzip, bzip2, or xz)

### Steps

```powershell
git clone https://github.com/H-Held/docker-img-shrink.git
cd docker-img-shrink
```

Drop your image into the `Input/` folder, then:

```powershell
docker compose up --build
```

The result lands in `Output/shrunk_image.img.gz`.

### Windows Helper Scripts

Two batch / PowerShell scripts in `windows/`:

| Script | Does |
|---|---|
| `build_and_shutdown.bat` | Builds the container, runs it, shuts down the PC |
| `build_upload_shutdown.ps1` | Builds → runs → calls `wait_upload.py` → shuts down |

For the PowerShell upload variant, you need a Python venv and your own `wait_upload.py`. Dependencies are in `requirements.txt`.

---

## How the Expand-Root Service Works

The injected systemd unit runs once at boot:

- Stops SSH and all TTY logins (prevents interruptions)
- Paints a red "MAINTENANCE IN PROGRESS" screen on all consoles
- Resizes the root partition to 100% of the disk with `parted`
- Runs `resize2fs`
- Deletes itself and reboots

No interaction needed — the Pi (or any Linux box) expands on its own and comes back up with the full disk.

---

## Docker Bits

The container needs `privileged: true` — it uses loop devices, `kpartx`, `mount`, and `chroot`.

| Host | Container | Notes |
|---|---|---|
| `./Input` | `/input` | Read-only, holds your source image |
| `./Output` | `/output` | Final compressed artifact |

---

## Files

```
├── .gitignore
├── LICENSE
├── README.md
├── docker-compose.yml
├── Dockerfile
├── requirements.txt
│
├── scripts/
│   ├── run.sh
│   ├── expand-root.sh
│   └── expand-root.service
│
└── windows/
    ├── build_and_shutdown.bat
    └── build_upload_shutdown.ps1
```

---

## License

MIT — see [LICENSE](LICENSE). Upstream PiShrink by Drewsif is also MIT.

## Credits

- [Drewsif/PiShrink](https://github.com/Drewsif/PiShrink) — the shrink logic
- `pigz` by Mark Adler — parallel gzip