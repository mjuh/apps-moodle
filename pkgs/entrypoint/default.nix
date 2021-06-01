{ stdenv
, writeScript

, moodle
, moodle-language-pack-ru

, bash
, gnutar
, coreutils
, gnused
, gzip
, patch
, php }:

let
  installCommand = builtins.concatStringsSep " " [
    "${php}/bin/php"
    "admin/cli/install.php"
    "--non-interactive"
    "--agree-license"
    "--lang=ru"
    "--dataroot=/workdir/moodledata"
    "--wwwroot=$PROTOCOL://\"$DOMAIN_NAME\""
    "--dbtype=mariadb"
    "--dbhost=\"$DB_HOST\""
    "--dbname=\"$DB_NAME\""
    "--dbpass=\"$DB_PASSWORD\""
    "--dbuser=\"$DB_USER\""
    "--adminuser=\"$ADMIN_USERNAME\""
    "--adminemail=\"$ADMIN_EMAIL\""
    "--adminpass=\"$ADMIN_PASSWORD\""
    "--fullname=\"$APP_TITLE\""
    "--shortname=\"$APP_TITLE\""
  ];
in stdenv.mkDerivation {
  name = "moodle-install";
  src = false;
  dontUnpack = true;
  checkPhase = if (moodle.version == moodle-language-pack-ru.version)
               then
                 false
               else
                 abort "moodle version doesn't match moodle-language-pack-ru version";
  builder = writeScript "builder.sh" (''
    source $stdenv/setup
    mkdir -p $out/bin
    cat > $out/bin/moodle-install.sh <<'EOF'
    #!${bash}/bin/bash
    set -ex
    export PATH=${gzip}/bin:${gnutar}/bin:${coreutils}/bin:${gnused}/bin:${patch}/bin:$PATH

    echo "Extract installer archive."
    tar xf ${moodle}/tarballs/moodle-*.tar.gz

    echo "Generate 'moodledata/.htaccess' file."
    mkdir moodledata
    cat > moodledata/.htaccess <<'EOH'
    order deny,allow
    deny from all
    EOH

    echo "Install Russian language pack."
    if [[ -d /workdir/moodledata/lang/ru ]]
    then
        echo "Russian language pack already installed, skipping."
    else
        mkdir -p /workdir/moodledata/lang
        ${gnutar}/bin/tar -xzf ${moodle-language-pack-ru} -C /workdir/moodledata/lang
    fi

    echo "Install."
    ${installCommand}

    echo "Post install fixup."
    sed -i "s@'/workdir/moodledata'@__DIR__.'/moodledata'@" config.php
    EOF
    chmod 555 $out/bin/moodle-install.sh
  '');
}
