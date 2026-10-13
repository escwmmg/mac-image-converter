#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
destination="$HOME/Applications/Image Converter.app"
service="$HOME/Library/Services/Convert Images.workflow"
if [[ ! -d "Image Converter.app" ]]; then
  ./build.command
fi
if [[ -e "$destination" || -e "$service" ]]; then
  echo "An app or Quick Action already exists at the installation location."
  echo "Move the existing Image Converter app and Convert Images.workflow aside before reinstalling."
  exit 1
fi
mkdir -p "$HOME/Applications" "$HOME/Library/Services"
/usr/bin/ditto "Image Converter.app" "$destination"
/usr/bin/ditto "Convert Images.workflow" "$service"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$destination"
/System/Library/CoreServices/pbs -update || true
/usr/bin/open "$destination"
echo "Installed. Select images in Finder → Quick Actions → Convert Images."
echo "Open the converter anytime with Control–Option–Command–I."
