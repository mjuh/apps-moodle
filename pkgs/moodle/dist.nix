{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "moodle";
  version = "3.8.4";
  src = fetchurl {
    url = "https://download.moodle.org/stable38/moodle-${version}.tgz";
    sha256 = "10glx6ix1z3z1vqsfbps65iqhm35iklkap7fzgms3mk88q8wlnmg";
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
