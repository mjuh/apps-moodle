{ nixpkgs ? (import <nixpkgs> { }).fetchgit {
  url = "https://github.com/NixOS/nixpkgs.git";
  rev = "ce9f1aaa39ee2a5b76a9c9580c859a74de65ead5";
  sha256 = "1s2b9rvpyamiagvpl5cggdb2nmx4f7lpylipd397wz8f0wngygpi";
}, overlayUrl ? "git@gitlab.intr:_ci/nixpkgs.git", overlayRef ? "master" }:

with import nixpkgs {
  overlays = [
    (import (builtins.fetchGit {
      url = overlayUrl;
      ref = overlayRef;
    }))
  ];
};

with lib;

let
  moodle-dist = fetchurl {
    url = "https://download.moodle.org/stable38/moodle-3.8.2.tgz";
    sha256 = "134vxsbslk7sfalmgcp744aygaxz2k080d14j8nkivk9zhplds53";
  };

  moodle-langpack-ru = fetchurl {
    url = "https://download.moodle.org/download.php/direct/langpack/3.8/ru.zip";
    sha256 = "1bqnmbbhdk6j89nqacch6mk7gz52qfvaiq3pzj2k8iv3y0pr3srx";
  };

  installCommand = builtins.concatStringsSep " " [
    "${php72}/bin/php"
    "admin/cli/install.php"
    "--non-interactive"
    "--agree-license"
    "--lang=ru"
    "--dataroot=/workdir/moodledata"
    "--wwwroot=http://$DOMAIN_NAME/"
    "--dbtype=mariadb"
    "--dbhost=$DB_HOST"
    "--dbname=$DB_NAME"
    "--dbpass=$DB_PASSWORD"
    "--dbuser=$DB_USER"
    "--adminuser=$ADMIN_USERNAME"
    "--adminemail=$ADMIN_EMAIL"
    "--adminpass=$ADMIN_PASSWORD"
    "--fullname=$APP_TITLE"
    "--shortname=$APP_TITLE"
  ];

  entrypoint = (stdenv.mkDerivation {
    name = "moodle-install";
    builder = writeScript "builder.sh" (''
      source $stdenv/setup
      mkdir -p $out/bin
      cat > $out/bin/moodle-install.sh <<'EOF'
      #!${bash}/bin/bash
      set -ex
      export PATH=${gnutar}/bin:${coreutils}/bin:${gnused}/bin:${patch}/bin:$PATH

      echo "Extract installer archive."
      tar xf ${moodle-dist} --strip-components=1

      echo "Generate 'moodledata/.htaccess' file."
      mkdir moodledata
      cat > moodledata/.htaccess <<'EOH'
      order deny,allow
      deny from all
      EOH

      echo "Patch."
      patch -p1 <${./adminlib-is-dataroot-insecure.patch}

      echo "Install."
      ${installCommand}

      echo "Post install fixup."
      sed -i "s@'/workdir/moodledata'@__DIR__.'/moodledata'@" config.php

      echo "Install Russian language pack."
      if [[ -d /workdir/moodledata/lang/ru ]]
      then
          echo "Russian language pack already installed, skipping."
      else
          mkdir -p /workdir/moodledata/lang
          ${unzip}/bin/unzip ${moodle-langpack-ru} -d /workdir/moodledata/lang
      fi
      EOF
      chmod 555 $out/bin/moodle-install.sh
    '');
  });

in pkgs.dockerTools.buildLayeredImage rec {
  name = "docker-registry.intr/apps/moodle";
  tag = "latest";
  contents =
    [ bashInteractive coreutils gnused gnutar patch gzip entrypoint nss-certs ];
  config = {
    Entrypoint = "${entrypoint}/bin/moodle-install.sh";
    Env = [
      "TZ=Europe/Moscow"
      "TZDIR=${tzdata}/share/zoneinfo"
      "LOCALE_ARCHIVE_2_27=${glibcLocales}/lib/locale/locale-archive"
      "LOCALE_ARCHIVE=${glibcLocales}/lib/locale/locale-archive"
      "LC_ALL=en_US.UTF-8"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
    ];
    WorkingDir = "/workdir";
  };
  extraCommands = ''
    set -x -e

    mkdir -p {etc,home/alice,root,tmp}
    chmod 755 etc
    chmod 777 home/alice
    chmod 777 tmp

    cat > etc/passwd << 'EOF'
    root:!:0:0:System administrator:/root:/bin/sh
    alice:!:1000:997:Alice:/home/alice:/bin/sh
    EOF

    cat > etc/group << 'EOF'
    root:!:0:
    users:!:997:
    EOF

    cat > etc/nsswitch.conf << 'EOF'
    hosts: files dns
    EOF
  '';
}