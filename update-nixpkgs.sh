#! /usr/bin/env bash

set -eu -o pipefail

exit_trap()
{
  local lc="$BASH_COMMAND" rc=$?
  test $rc -eq 0 || echo "*** error $rc: $lc"
}

trap exit_trap EXIT

cd "$(dirname "$0")"
cabal2nix=$(git describe --dirty)

cd nixpkgs
git reset -q --hard
git clean -dxf -q
git pull -q
export NIX_PATH=nixpkgs=$PWD
nixpkgs=$(git rev-parse --verify HEAD)
cd ..

cd lts-haskell
git pull -q
ltshaskell=$(git rev-parse --verify HEAD)
cd ..

cd hackage
git pull -q
rm -f preferred-versions
for n in */preferred-versions; do
  cat >>preferred-versions "$n"
  echo >>preferred-versions
done
DIR=$HOME/.cabal/packages/hackage.haskell.org
TAR=$DIR/00-index.tar
TARGZ=$TAR.gz
mkdir -p "$DIR"
rm -f "$TAR" "$TARGZ"
git archive --format=tar -o "$TAR" HEAD
gzip -k "$TAR"
hackage=$(git rev-parse --verify HEAD)
cd ..

cabal run -v0 hackage2nix -- --nixpkgs="$PWD/nixpkgs" +RTS -M4G -RTS

cd nixpkgs
git add pkgs/development/haskell-modules
if [ -n "$(git status --porcelain)" ]; then
  cat <<EOF | git commit -q -F -
hackage-packages.nix: update Haskell package set

This update was generated by hackage2nix $cabal2nix using the following inputs:

  - Hackage: https://github.com/commercialhaskell/all-cabal-hashes/commit/$hackage
  - LTS Haskell: https://github.com/fpco/lts-haskell/commit/$ltshaskell
EOF
  git push -q
fi
