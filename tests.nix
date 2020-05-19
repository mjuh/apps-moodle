{ nixpkgs ? (import <nixpkgs> { }).fetchgit {
  url = "https://github.com/NixOS/nixpkgs.git";
  rev = "ce9f1aaa39ee2a5b76a9c9580c859a74de65ead5";
  sha256 = "1s2b9rvpyamiagvpl5cggdb2nmx4f7lpylipd397wz8f0wngygpi";
}, overlayUrl ? "git@gitlab.intr:_ci/nixpkgs.git", overlayRef ? "master"
, phpRef ? "master" }:

with import nixpkgs {
  overlays = [
    (import (builtins.fetchGit {
      url = overlayUrl;
      ref = overlayRef;
    }))
    (self: super: {
      containerImageApache = import (builtins.fetchGit {
        url = "git@gitlab.intr:webservices/apache2-php72.git";
        ref = phpRef;
      }) { };
    })
  ];
};

with lib;

let
  containerImageMoodle = import ./default.nix { };

  loadContainers = { extraContainers ? [ ] }:
    writeScript "pullContainers.sh" ''
      #!${bash}/bin/bash
      PATH=${pkgs.docker}/bin:$PATH
      ${builtins.concatStringsSep "; "
      (map (container: "docker load --input ${container}")
        ([ containerImageMoodle containerImageApache ] ++ extraContainers))}
    '';

  runApache = writeScript "runApache.sh" ''
    #!${bash}/bin/bash
    PATH=${pkgs.docker}/bin:$PATH
    set -e -x
    rsync -av /etc/{passwd,group,shadow} /opt/etc/ > /dev/null
    ${
      (lib.importJSON
        (containerImageApache.baseJson)).config.Labels."ru.majordomo.docker.cmd"
    } &
  '';

  runCms = writeScript "runCms.sh" ''
    #!${bash}/bin/bash
    PATH=${pkgs.docker}/bin:$PATH
    exec -a "$0" docker run                              \
        --rm                                             \
        --user 12345:100                                 \
        --volume /home/u12345/moodle.intr/www:/workdir   \
        --env DB_NAME=b12345_moodle                      \
        --env DB_PASSWORD=qwerty123admin                 \
        --env DB_USER=u12345_moodle                      \
        --env DB_HOST=127.0.0.1                          \
        --env ADMIN_PASSWORD=qwerty123admin              \
        --env ADMIN_USERNAME=admin                       \
        --env ADMIN_EMAIL=root@example.com               \
        --env APP_TITLE=moodle                           \
        --env DOMAIN_NAME=moodle.intr                    \
        --env DOCUMENT_ROOT=/home/u12345/moodle.intr/www \
        --network=host                                   \
        --workdir /workdir                               \
        docker-registry.intr/apps/moodle:latest
  '';

  mariadbInit = ''
    CREATE USER 'u12345_moodle'@'%' IDENTIFIED BY 'qwerty123admin';
    CREATE DATABASE b12345_moodle;
    GRANT ALL PRIVILEGES ON b12345_moodle . * TO 'u12345_moodle'@'%';
    FLUSH PRIVILEGES;
  '';

  runMariadb = writeScript "runMariadb.sh" ''
    #!${bash}/bin/bash
    PATH=${pkgs.docker}/bin:$PATH
    set -ex
    install -Dm644 ${
      pkgs.writeText "mariadb-init.sql" mariadbInit
    } /tmp/mariadb/init.sql
    docker run --env MYSQL_ROOT_PASSWORD=root123pass --volume /tmp/mariadb:/tmp/mariadb --detach --rm --name mariadb --network host mysql:5.5
    sleep 15 # wait for container start up
    docker exec mariadb mysql -h localhost -u root -proot123pass -e "source /tmp/mariadb/init.sql;"
  '';

  vmTemplate = {
    environment.etc.testBitrix.source = runMariadb;
    virtualisation = {
      cores = 3;
      memorySize = 4 * 1024;
      diskSize = 4 * 1024;
      docker.enable = true;
    };
    networking.extraHosts = "127.0.0.1 moodle.intr";
    users.users = {
      u12345 = {
        isNormalUser = true;
        password = "secret";
        uid = 12345;
      };
      www-data = {
        isNormalUser = false;
        uid = 33;
      };
    };

    # Environment variables for Apache container
    environment.variables.SECURITY_LEVEL = "default";
    environment.variables.SITES_CONF_PATH =
      "/etc/apache2-php72-default/sites-enabled";
    environment.variables.SOCKET_HTTP_PORT = "80";

    boot.initrd.postMountCommands = ''
      for dir in /apache2-php72-default /opcache /home \
                 /opt/postfix/spool/public /opt/postfix/spool/maildrop \
                 /opt/postfix/lib; do
          mkdir -p /mnt-root$dir
      done

      mkdir /mnt-root/apache2-php72-default/sites-enabled

      # Used as Docker volume
      #
      mkdir -p /mnt-root/opt/etc
      for file in group gshadow passwd shadow; do
        mkdir -p /mnt-root/opt/etc
        cp -v /etc/$file /mnt-root/opt/etc/$file
      done
      #
      mkdir -p /mnt-root/opcache/moodle.intr
      chmod -R 1777 /mnt-root/opcache

      mkdir -p /mnt-root/etc/apache2-php72-default/sites-enabled/
      cat <<EOF > /mnt-root/etc/apache2-php72-default/sites-enabled/5d41c60519f4690001176012.conf
      <VirtualHost 127.0.0.1:80>
          ServerName moodle.intr
          ServerAlias www.moodle.intr
          ScriptAlias /cgi-bin /home/u12345/moodle.intr/www/cgi-bin
          DocumentRoot /home/u12345/moodle.intr/www
          <Directory /home/u12345/moodle.intr/www>
              Options +FollowSymLinks -MultiViews +Includes -ExecCGI
              DirectoryIndex index.php index.html index.htm
              Require all granted
              AllowOverride all
          </Directory>
          AddDefaultCharset UTF-8
        UseCanonicalName Off
          AddHandler server-parsed .shtml .shtm
          php_admin_flag allow_url_fopen on
          php_admin_value mbstring.func_overload 0
          php_admin_value opcache.revalidate_freq 0
          php_admin_value opcache.file_cache "/opcache/moodle.intr"
          <IfModule mod_setenvif.c>
              SetEnvIf X-Forwarded-Proto https HTTPS=on
              SetEnvIf X-Forwarded-Proto https PORT=443
          </IfModule>
          <IfFile  /home/u12345/logs>
          CustomLog /home/u12345/logs/www.moodle.intr-access.log common-time
          ErrorLog /home/u12345/logs/www.moodle.intr-error_log
          </IfFile>
          MaxClientsVHost 20
          AssignUserID #12345 #100
      </VirtualHost>
      EOF

      mkdir -p /mnt-root/home/u12345/moodle.intr/www
      chown 12345:100 -R /mnt-root/home/u12345
    '';
  };

in [
  (import (nixpkgs + /nixos/tests/make-test.nix) ({ pkgs, lib, ... }: {
    name = "moodle-mariadb-5.5";
    nodes = { dockerNode = { pkgs, ... }: vmTemplate; };

    testScript = [''
      print "Tests entry point.\n";
      startAll;

      print "Start services.\n";
      $dockerNode->sleep(10);
    ''] ++ [

      (dockerNodeTest {
        description = "Load containers";
        action = "succeed";
        command = loadContainers {
          extraContainers = [
            (pkgs.dockerTools.pullImage {
              imageName = "mysql";
              imageDigest =
                "sha256:12da85ab88aedfdf39455872fb044f607c32fdc233cd59f1d26769fbf439b045";
              sha256 = "0cw4hvjif5pnb774vxxh45nbsa8jrnm6bvz589s4v3d7iyqy5s3f";
              finalImageName = "mysql";
              finalImageTag = "5.5";
            })
          ];
        };
      })

      (dockerNodeTest {
        description = "Start MariaDB container";
        action = "succeed";
        command = runMariadb;
      })

      (dockerNodeTest {
        description = "Start Apache container";
        action = "succeed";
        command = runApache;
      })

      (dockerNodeTest {
        description = "Install Moodle";
        action = "succeed";
        command = runCms;
      })

      (dockerNodeTest {
        description = "Take Moodle screenshot";
        action = "succeed";
        command = builtins.concatStringsSep " " [
          "${firefox}/bin/firefox"
          "--headless"
          "--screenshot=/tmp/xchg/coverage-data/moodle.png"
          "http://moodle.intr/"
        ];
      })
    ];
  }) { })

  (import (nixpkgs + /nixos/tests/make-test.nix) ({ pkgs, lib, ... }: {
    name = "moodle-mariadb-nix-upstream";
    nodes = {
      dockerNode = { pkgs, ... }:
        vmTemplate // {
          services.mysql.enable = true;
          services.mysql.initialScript = pkgs.writeText "mariadb-init.sql" ''
            ALTER USER root@localhost IDENTIFIED WITH unix_socket;
            DELETE FROM mysql.user WHERE password = ''' AND plugin = ''';
            DELETE FROM mysql.user WHERE user = ''';
            ${mariadbInit}
          '';
          services.mysql.package = pkgs.mariadb;
        };
    };

    testScript = [''
      print "Tests entry point.\n";
      startAll;

      print "Start services.\n";
      $dockerNode->waitForUnit("mysql");
      $dockerNode->sleep(10);
    ''] ++ [

      (dockerNodeTest {
        description = "Load containers";
        action = "succeed";
        command = loadContainers { };
      })

      (dockerNodeTest {
        description = "Start Apache container";
        action = "succeed";
        command = runApache;
      })

      (dockerNodeTest {
        description = "Install Moodle";
        action = "succeed";
        command = runCms;
      })

      (dockerNodeTest {
        description = "Take Moodle screenshot";
        action = "succeed";
        command = builtins.concatStringsSep " " [
          "${firefox}/bin/firefox"
          "--headless"
          "--screenshot=/tmp/xchg/coverage-data/moodle.png"
          "http://moodle.intr/"
        ];
      })
    ];
  }) { })
]
