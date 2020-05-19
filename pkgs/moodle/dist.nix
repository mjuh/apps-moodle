{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "moodle";
  version = "3.8.3";
  src = fetchurl {
    url = "https://download.moodle.org/stable38/moodle-${version}.tgz";
    sha256 = "1anjv4gvbb6833j04a1b4aaysnl4h0x96sr1hhm4nm5kq2fimjd1";
  };
  patches = [
    ./patches/adminlib-is-dataroot-insecure.patch
    ./patches/mysql_collation.patch
  ];
  dontFixup = true;
  installPhase = ''
    tar czf moodle-${version}.tar.gz *
    install -Dm644 moodle-${version}.tar.gz $out/tarballs/moodle-${version}.tar.gz
  '';
}
