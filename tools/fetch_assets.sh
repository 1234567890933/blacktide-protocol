#!/usr/bin/env bash
# Pull the free, openly licensed art packs the game can use, straight from
# their GitHub repositories. Nothing here is required to run the game — the
# project ships with procedural primitives and swaps in real art when present.
#
# Everything downloaded lands in assets/external/ which is git-ignored, so the
# repository stays small and the licences stay with their authors.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${ROOT}/assets/external"
mkdir -p "${DEST}"/{models,audio,textures}

clone_pack() {
  local name="$1" url="$2" ref="${3:-main}"
  local target="${DEST}/_src/${name}"
  if [ -d "${target}" ]; then
    echo "== ${name} already present"
    return
  fi
  echo "== Cloning ${name}"
  mkdir -p "${DEST}/_src"
  git clone --depth 1 --branch "${ref}" "${url}" "${target}" || \
    echo "!! Could not clone ${name} (offline?) — skipping, procedural assets stay in use"
}

# --- Models (CC0) -----------------------------------------------------------
# Kenney's weapon + industrial kits are the closest thing to a free tactical set.
clone_pack "kenney-weapons"  "https://github.com/KenneyNL/Weapon-Pack.git"
clone_pack "kenney-industrial" "https://github.com/KenneyNL/Industrial-Kit.git"

# --- Audio (CC0) ------------------------------------------------------------
clone_pack "kenney-audio" "https://github.com/KenneyNL/Audio-Kit.git"

# --- Textures (CC0) ---------------------------------------------------------
clone_pack "polyhaven-hdri" "https://github.com/Poly-Haven/Assets.git"

cat <<'NOTE'

Next steps:
  1. Copy the .glb / .ogg / .jpg files you want into
     assets/external/models|audio|textures using the filenames listed in
     assets/MANIFEST.md (the loader looks for those exact names).
  2. AudioDirector automatically prefers assets/external/audio/<sfx_name>.ogg
     over the built-in synthesiser, so dropping in gun_ar.ogg is enough.
  3. Re-run tools/build_local.sh. Sizes grow fast: keep the whole APK under the
     budget in docs/05-build-and-release.md.
NOTE
