{
  buildPackages,
  cacert,
  nix,
  system,
  version,
}:
let
  installerClosureInfo = buildPackages.closureInfo {
    rootPaths = [
      nix
      cacert
    ];
  };

  meta.description = "Distribution-independent Nix bootstrap binaries for ${system}";
in
buildPackages.runCommand "nix-binary-tarball-${version}" { inherit meta; } ''
  cp ${installerClosureInfo}/registration $TMPDIR/reginfo

  dir=nix-${version}-${system}
  fn=$out/$dir.tar.xz
  mkdir -p $out/nix-support
  echo "file binary-dist $fn" >> $out/nix-support/hydra-build-products
  tar cvfJ $fn \
    --owner=0 --group=0 --mode=u+rw,uga+r \
    --mtime='1970-01-01' \
    --absolute-names \
    --hard-dereference \
    --transform "s,$TMPDIR/reginfo,$dir/.reginfo," \
    --transform "s,$NIX_STORE,$dir/store,S" \
    $TMPDIR/reginfo \
    $(cat ${installerClosureInfo}/store-paths)
''
