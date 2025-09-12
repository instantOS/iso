# Migration Plan: Update instantOS ISO Build from Deprecated customize_airootfs.sh to Modern archiso with Dynamic Releng Patching and Hook-Based Approach

## Overview
This repo builds an installation ISO for instantOS, an Arch Linux derivative, using an outdated archiso process that relies on the deprecated `customize_airootfs.sh` script. The script runs inside the chroot for dynamic customizations. To avoid hard-forking the upstream releng profile (preventing easy upstream updates), we'll use a dynamic approach: copy the latest releng from `/usr/share/archiso/configs/releng/` to a temp build dir, then apply minimal instantOS-specific patches/overlays (static files, package appends, hooks for dynamic scripts). This uses modern archiso features (static airootfs, pacman hooks) while preserving all existing ISO features and benefiting from upstream releng/archiso updates via `instantinstall archiso` or system updates. Hooks will handle script execution for simplicity, accepting potential reproducibility trade-offs.

Key features to preserve (from `customize_airootfs.sh` and `build.sh`):
- **User Management**: User `instantos` (pass: `instantos`), groups (autologin, video, wheel, input), sudo NOPASSWD for root.
- **Display Manager**: LightDM autologin as `instantos`, greeter config, shell-based start.
- **InstantOS Customization**: Run `instantOS/rootinstall.sh` for root configs/themes/dotfiles; GRUB theme.
- **System Services**: Enable `systemd-timesyncd`; env vars (e.g., `NOILOCKPASSWORD=true`); `tzupdate` in `.zshrc`.
- **Additional Tools**: Dev tools via `netinstall.sh` from instantTOOLS.
- **Packages and Repos**: InstantOS repo; pkgs (instantos, instantdepend, grub-instantos); assets from liveutils/instantLOGO.
- **Bootloader**: Syslinux custom splash.png, TIMEOUT=100.
- **Other**: Clones for deps; live GUI boot with installer (`instantosinstaller`).

The new ISO must boot identically (BIOS/UEFI), include installer, and match live behavior.

## Current Process Issues
- **Deprecation**: `customize_airootfs.sh` removed in archiso v60 (2023); `mkarchiso` no longer executes it.
- **Inefficiency**: Chroot script is non-declarative/error-prone.
- **Maintenance**: Hardcodes git clones/external scripts; fragile.
- **Compatibility**: Breaks on archiso >=60; current copy-patches releng but relies on deprecated chroot.

From ArchWiki/archiso docs: Modern profiles use declarative configs (`airootfs/`, `packages.x86_64`, hooks). Hooks enable post-install script execution for dynamics like running custom setups.

## Research Summary
- **Archiso Evolution**: Profiles (releng/baseline) for modularity. Build: `mkarchiso -v -w /tmp/work -o out/ /path/to/profile/`. Releng is official ISO base.
- **Customization Methods**:
  - Static: Overlay files in `airootfs/` (configs in `/etc/`, dotfiles in `/root/` or `/etc/skel/`).
  - Packages: Append to `packages.x86_64`; add repos to build-time `pacman.conf`.
  - Dynamic: Pacman hooks in `airootfs/etc/pacman.d/hooks/` (e.g., post-glibc for setups). Auto-remove hooks marked `# remove from airootfs!`.
  - Users: Populate `airootfs/etc/{passwd,shadow,group,gshadow}`; perms in `profiledef.sh` or post-copy.
  - Services: Symlinks in `airootfs/etc/systemd/system/*.wants/`.
  - Bootloaders: Modify `syslinux/` etc.
- **Dynamic Patching**: Copy releng, then rsync overlays, cat packages, cp hooks—keeps repo minimal, pulls upstream fresh.
- **Hooks for Setup**: Releng has cleanup hook; use for one-time builds (e.g., useradd, run scripts). Executing scripts in hooks is pragmatic for complex dynamics, though less reproducible than static replication.
- **Script Analysis** (via GitHub repos):
  - **rootinstall.sh** (from instantOS repo): Applies root configurations (copies dotfiles/themes from /usr/share/instantdotfiles/, sets GRUB theme, enables services). Hook: Static copy script to airootfs/usr/local/bin/, exec `bash /usr/local/bin/rootinstall.sh` in post-install hook.
  - **netinstall.sh** (from instantTOOLS repo): Curl|bash for dev tools (git, vim, etc., via pacman/AUR). Hook: Static copy script, exec in hook (avoids curl|bash); or append pkgs to list if simple.
  - **instantARCH**: Package lists (data/packages/system/extra). Static: Cat to `packages.x86_64`.
  - **Other**: Assets (splash.png, wallpapers) static copies. Useradd/chpasswd: Idempotent in hook. LightDM/sudoers/env: Static files + hook for final tweaks.

## Migration Strategy
- **Dynamic Releng Use**: In `build.sh`, copy latest upstream releng to temp `instantlive/`, apply deltas: repo/pkgs, airootfs overlay (static files), hooks for dynamics (script exec, user setup, service enables).
- **Hook-Based**: Use pacman hooks to run `rootinstall.sh` and `netinstall.sh` post-install, replicating `customize_airootfs.sh` logic. Static for simple files (configs, assets); hooks for scripts/services.
- **Minimal Repo Changes**: Add `custom-packages.txt`, `custom-hooks/` (with setup hook), `custom-airootfs/` (overlays: basic configs, scripts, assets). No full static replication—hooks for flexibility.
- **Upstream Benefits**: Fresh releng copy each build incorporates updates (new pkgs, hooks, boot params).
- **Verification**: Build/test ISO; compare to old for parity.

## Step-by-Step Implementation Plan
### Phase 1: Preparation (No Code Edits Yet)
- Analyze `customize_airootfs.sh`: List actions (useradd, lightdm setup, rootinstall.sh, netinstall.sh, enables).
- Prepare Components:
  - `custom-packages.txt`: InstantOS pkgs from instantARCH (data/packages/system/extra), defaults (xorg, lightdm, etc.).
  - `custom-airootfs/`: Basic overlays (e.g., /etc/os-release branding, assets to /usr/share/liveutils/, splash.png).
  - `custom-hooks/99-instantos-setup.hook`: Post-glibc/base trigger:
    - User: `id instantos || (useradd -m -s /bin/bash instantos; echo "instantos:instantos" | chpasswd; gpasswd -a instantos autologin video wheel input)`.
    - Sudo: Static /etc/sudoers (uncomment %wheel, add root NOPASSWD).
    - LightDM: Static /etc/lightdm/lightdm.conf (autologin), greeter.conf; symlink lightdm -> display-manager.service.
    - Scripts: Copy rootinstall.sh/netinstall.sh to /usr/local/bin/ in overlay; exec `bash /usr/local/bin/rootinstall.sh` and `bash /usr/local/bin/netinstall.sh`.
    - Services: Symlink timesyncd; static /etc/environment, /root/.zshrc (tzupdate).
    - GRUB: Static /etc/default/grub (theme).
    - Mark `# remove from airootfs!`.
- Git assets: Use ensurerepo() to fetch/copy specifics (splash.png, wallpapers, packages).

### Phase 2: Dynamic Profile Patching (in build.sh)
Update `build.sh` to:
1. Copy upstream: `cp -r /usr/share/archiso/configs/releng/ "$ISO_BUILD/instantlive"`.
2. Repo: Append `[instant]` to `instantlive/pacman.conf` (SigLevel=Optional TrustAll, Server=http://packages.instantos.io/).
3. Packages: `cat custom-packages.txt >> instantlive/packages.x86_64`; `sort -u > packages.x86_64`.
4. airootfs Overlay:
   - `rsync -a custom-airootfs/ instantlive/airootfs/` (basic configs, assets, scripts to /usr/local/bin/).
   - Git assets: ensurerepo() to copy splash.png (instantLOGO), wallpaper/jpgs (liveutils) to airootfs/usr/share/liveutils/.
   - Post-copy: Fix perms (e.g., `chmod 0400 instantlive/airootfs/etc/shadow` if static user files).
5. Hooks:
   - Copy `custom-hooks/*` to `instantlive/airootfs/etc/pacman.d/hooks/`.
   - 99-instantos-setup.hook: As above—runs useradd, scripts, enables (idempotent where possible).
6. Bootloader: `cd instantlive/syslinux`; sed TIMEOUT=100 in *.cfg; cp splash.png.
7. Remove deprecated: No `cp -r airootfs` or chroot exec of customize_airootfs.sh.

Build: `sudo mkarchiso -v "$ISO_BUILD/instantlive" -o "$ISO_BUILD/iso/"`.

### Phase 3: Update build.sh
- Keep structure (ISO_BUILD, ensurerepo, etc.).
- Add: rsync overlay, cat packages, cp hooks, post-copy for perms/symlinks.
- User pass: Handled in hook (chpasswd).
- Remove: Old airootfs copy, chroot script.
- Cleanup: rm -rf work/ post-build.

