{ stdenv, fetchurl, moodle }:

stdenv.mkDerivation rec {
  inherit (moodle) version src;
  pname = "moodle";
  patches = [
    ./patches/adminlib-is-dataroot-insecure.patch
  ];
  dontFixup = true;
  installPhase = ''
    tar czf moodle-${version}.tar.gz *
    install -Dm644 moodle-${version}.tar.gz $out/tarballs/moodle-${version}.tar.gz
  '';
}
