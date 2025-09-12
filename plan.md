# Migration Plan: Update instantOS ISO Build from Deprecated customize_airootfs.sh to Modern archiso with Dynamic Releng Patching and Static-First Approach

## Overview

This repo builds an installation ISO for instantOS, an Arch Linux derivative, using an outdated archiso process that relies on the deprecated `customize_airootfs.sh` script. The script runs inside the chroot for dynamic customizations. To avoid hard-forking the upstream releng profile (preventing easy upstream updates), we'll use a dynamic approach: copy the latest releng from `/usr/share/archiso/configs/releng/` to a temp build dir, then apply minimal instantOS-specific patches/overlays (static files, package appends, hooks only if necessary). This uses modern archiso features (static airootfs, pacman hooks) while preserving all existing ISO features and benefiting from upstream releng/archiso updates via `instantinstall archiso` or system updates.

Key features to preserve (from `customize_airootfs.sh` and `build.sh`):
- **User Management**: User `instantos` (pass: `instantos`), groups (autologin, video, wheel, input), sudo NOPASSWD for root.
- **Display Manager**: LightDM autologin as `instantos`, greeter config, shell-based start.
- **InstantOS Customization**: Apply root configs/themes/dotfiles via `rootinstall.sh`; GRUB theme.
- **System Services**: Enable `systemd-timesyncd`; env vars (e.g., `NOILOCKPASSWORD=true`); `tzupdate` in `.zshrc`.
- **Additional Tools**: Dev tools via `netinstall.sh` from instantTOOLS.
- **Packages and Repos**: InstantOS repo; pkgs (instantos, instantdepend, grub-instantos); assets from liveutils/instantLOGO.
- **Bootloader**: Syslinux custom splash.png, TIMEOUT=100.
- **Other**: Clones for deps; live GUI boot with installer (`instantosinstaller`).

The new ISO must boot identically (BIOS/UEFI), include installer, and match live behavior. Prioritize static replication for reproducibility; use hooks only for unavoidable dynamics.

## Current Process Issues
- **Deprecation**: `customize_airootfs.sh` removed in archiso v60 (2023); `mkarchiso` no longer executes it.
- **Inefficiency**: Chroot script is non-declarative/error-prone.
- **Maintenance**: Hardcodes git clones/external scripts; fragile.
- **Compatibility**: Breaks on archiso >=60; current copy-patches releng but relies on deprecated chroot.

From ArchWiki/archiso docs: Modern profiles use declarative configs (`airootfs/`, `packages.x86_64`, hooks). No script exec; use hooks for post-install actions, but prefer static files for cleanliness.

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
- **Hooks for Setup**: Releng has cleanup hook; use sparingly for one-time builds (useradd, run scripts). Prefer static to avoid "dirty" script exec in hooks.
- **Script Analysis** (via GitHub repos):
  - **rootinstall.sh** (from instantOS repo): Applies root configurations, including dotfiles, themes, and system tweaks (e.g., copies from /usr/share/instantdotfiles/, sets GRUB theme, enables services). Effects are file-based (configs in /etc/, /root/); no runtime generation. Static: Copy resulting files (e.g., lightdm-gtk-greeter.conf, .zshrc) directly to `custom-airootfs/`; replicate symlinks/service enables statically.
  - **netinstall.sh** (from instantTOOLS repo): Curl|bash installer for dev tools (e.g., git, vim, dev utils like ibuild, depend.sh). Installs packages via pacman/AUR helpers. Static: Extract package list (e.g., dev tools like base-devel, git, vim, fzf); add to `custom-packages.txt`. Avoids curl|bash by including pkgs; if custom scripts needed, copy statically but prefer pkgs.
  - **instantARCH**: Provides package lists (data/packages/system, extra) for installer deps. Static: Cat these to `packages.x86_64` as before.
  - **Other**: Assets (splash.png from instantLOGO, wallpapers from liveutils) are static files—copy directly. Useradd/chpasswd: Static via shadow file with pre-hashed password. LightDM/sudoers/env: Static edits. No web search needed beyond repos; effects are declarative.

Challenges: If any script has env-specific generation (unlikely from analysis), fallback to minimal hook. All core parts (configs, pkgs, users) can be 100% static.

## Migration Strategy
- **Dynamic Releng Use**: In `build.sh`, copy latest upstream releng to temp `instantlive/`, apply deltas: repo/pkgs, airootfs overlay (static files/symlinks), bootloader tweaks. No hooks if static covers all.
- **Static-First**: Replicate `customize_airootfs.sh` and scripts declaratively: Copy files from instantOS/instantTOOLS/instantARCH repos to `custom-airootfs/`; append pkgs. Eliminates script exec for reproducibility.
- **Minimal Repo Changes**: Add `custom-packages.txt` (merged from instantARCH + dev tools), `custom-airootfs/` (overlays: configs, assets, user files, dotfiles from rootinstall.sh effects). No hooks unless needed.
- **Upstream Benefits**: Fresh releng copy each build incorporates updates (new pkgs, hooks, boot params).
- **Verification**: Build/test ISO; compare to old for parity.

## Step-by-Step Implementation Plan
### Phase 1: Preparation (No Code Edits Yet)
- Analyze `customize_airootfs.sh`: List modified files (e.g., /etc/sudoers, /etc/lightdm/, /root/.zshrc).
- Static Replication:
  - **User Management**: Pre-populate `custom-airootfs/etc/passwd`, `/etc/shadow` (hashed pass: `openssl passwd -6 instantos`), `/etc/group`, `/etc/gshadow`. Groups: wheel, video, etc., via group file.
  - **LightDM/Sudoers/Env**: Static files—copy lightdm.conf (autologin), lightdm-gtk-greeter.conf (from instantdotfiles), sudoers (uncomment %wheel, add root NOPASSWD), /etc/environment (NOILOCKPASSWORD=true).
  - **rootinstall.sh Effects**: From repo analysis, it copies dotfiles/themes (e.g., /root/.zshrc with tzupdate, GRUB theme in /etc/default/grub, configs from /usr/share/instantdotfiles/). Static: Fetch/copy these files to `custom-airootfs/root/`, `/etc/default/grub`, `/usr/share/instantdotfiles/`; no exec needed.
  - **netinstall.sh Effects**: Installs dev tools (e.g., git, vim, fzf, base-devel, instantutils). Static: List in `custom-packages.txt` (e.g., add base-devel, git, vim, fzf, expect, dialog, wget); covers curl|bash without running script.
  - **Packages**: From instantARCH (data/packages/system/extra): Cat to `custom-packages.txt`. Add defaults (xorg, lightdm, etc.) from build.sh.
  - **Assets/Services**: Static copies (splash.png, wallpapers); symlinks for services (lightdm -> display-manager.service, timesyncd -> basic.target.wants/systemd-timesyncd.service).
  - **Other**: /etc/os-release for branding; vconsole.conf/locales if needed (static + hook for locale-gen if custom).
- Create repo dirs: `custom-packages.txt`, `custom-airootfs/` (with replicated files), optional `custom-hooks/` (empty if static succeeds).
- If any dynamic (e.g., generated files), add minimal hook; but analysis shows full static feasible.

### Phase 2: Dynamic Profile Patching (in build.sh)
Update `build.sh` to:
1. Copy upstream: `cp -r /usr/share/archiso/configs/releng/ "$ISO_BUILD/instantlive"`.
2. Repo: Append `[instant]` to `instantlive/pacman.conf` (SigLevel=Optional TrustAll, Server=https://packages.instantos.io/). (change to https is important)
3. Packages: `cat custom-packages.txt >> instantlive/packages.x86_64`; `sort -u > packages.x86_64`.
4. airootfs Overlay:
   - `rsync -a custom-airootfs/ instantlive/airootfs/` (overlays all static files: user files, configs, dotfiles, assets, GRUB theme, /usr/share/instantdotfiles/, /usr/share/liveutils/, /root/.zshrc).
   - Git assets: Keep `ensurerepo()`; copy specifics (splash.png from instantLOGO, wallpaper/jpgs from liveutils, but since static, pre-fetch to custom-airootfs/ if possible).
   - Post-copy: Fix perms (e.g., `chmod 0400 instantlive/airootfs/etc/shadow`), create symlinks (e.g., for lightdm, timesyncd).
5. Hooks (Static-First—Omit if Unneeded):
   - If required (e.g., locale-gen for custom locales): Copy `custom-hooks/*` to `instantlive/airootfs/etc/pacman.d/hooks/`.
   - `99-instantos-setup.hook` (post-glibc/base): Only for residuals (e.g., idempotent checks); but with static, likely unnecessary. Include `# remove from airootfs!`.
6. Bootloader: `cd instantlive/syslinux`; sed TIMEOUT=100 in *.cfg; cp splash.png (static from overlay).
7. Remove deprecated: No `cp -r airootfs` or chroot exec of customize_airootfs.sh.

Build: `sudo mkarchiso -v "$ISO_BUILD/instantlive" -o "$ISO_BUILD/iso/"`.

### Phase 3: Update build.sh
- Keep structure (ISO_BUILD, ensurerepo, etc.).
- Add: rsync overlay, cat packages, post-copy bash for perms/symlinks.
- Hardcode user pass hash in custom-airootfs/etc/shadow.
- Remove: Old airootfs copy, chroot script. No script exec— all static.
- Cleanup: rm -rf work/ post-build.

### Phase 4: Documentation and Cleanup
- Update README.md: New build instructions, note dynamic releng and static approach for upstream ease/reproducibility.
- Remove: `airootfs/root/customize_airootfs.sh`.
- Commit updated plan.md.

