#!/bin/bash
set -euo pipefail

source_root="${SRCROOT}/CardMaterials/v1"
bundle_root="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/PBRMaterials"
mkdir -p "$bundle_root"

install_surface() {
  local variant="$1" kind="$2" side="$3" tier="$4"
  local source_dir="${source_root}/${kind}/${variant}/${side}"
  if [[ "$side" != edge ]]; then source_dir="${source_dir}/${tier}"; fi
  local target_dir="${bundle_root}/${variant}/${kind}/${side}/${tier}"
  mkdir -p "$target_dir"
  for channel in basecolor metalness roughness normal-scenekit; do
    local source_file="${source_dir}/${channel}.png"
    local target_file="${target_dir}/${channel}.png"
    if [[ ! -f "$target_file" ]] || ! cmp -s "$source_file" "$target_file"; then
      cp "$source_file" "$target_file"
    fi
  done
}

for variant in brushed-metal; do
  install_surface "$variant" materials front standard
  install_surface "$variant" demo front standard
  install_surface "$variant" materials back standard
  install_surface "$variant" demo back standard
  install_surface "$variant" materials edge standard
  install_surface "$variant" materials front zoom
  install_surface "$variant" demo front zoom
  install_surface "$variant" materials back zoom
  install_surface "$variant" demo back zoom
done

if [[ ! -f "${bundle_root}/studio-environment.png" ]] || \
   ! cmp -s "${source_root}/viewer/studio-environment.png" "${bundle_root}/studio-environment.png"; then
  cp "${source_root}/viewer/studio-environment.png" "${bundle_root}/studio-environment.png"
fi
