{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "moodle";
  version = "3.8.2";
  src = fetchurl {
    url = "https://download.moodle.org/stable38/moodle-${version}.tgz";
    sha256 = "134vxsbslk7sfalmgcp744aygaxz2k080d14j8nkivk9zhplds53";
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
