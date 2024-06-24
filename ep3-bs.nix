{ config, lib, pkgs, ... }:

  with lib;


let
  cfg = config.services.ep3-bs;
  useSmtp = cfg.mail.type == "smtp" || cfg.mail.type == "smtp-tls";

  ep3-bs-pkg =
    with pkgs;
    stdenv.mkDerivation {
      name = "ep3-bs";
    
      src = fetchFromGitHub {
        owner = "tkrebs";
        repo = "ep3-bs";
        rev = "1.8.1";
        sha256 = "sha256-mcuFgi1ebawaAyuEREsC9jdIqGA0BeMabqwiVcXsKSY=";
      };

      installPhase = ''
        runHook preInstall
        mkdir -p $out/
        cp -R . $out/
        runHook postInstall
      '';

    };

  configFile = pkgs.writeText "local.php" ''
    <?php
    /**
     * Local application configuration
     *
     * Insert your local database credentials here
     * and provide the email address the system should use.
     */
    
    return array(
        'db' => array(
            'database' => '${cfg.database.name}',
            'username' => '${cfg.database.user}',
            'password' => '%%PASSWORD_DB%%',
    
            'hostname' => 'localhost',
            'port' => null,
        ),
        'mail' => array(
            'type' => '${cfg.mail.type}', // or 'smtp' or 'smtp-tls' (or 'file', to not send, but save to file (data/mails/))
            'address' => '${cfg.mail.address}',
                // Make sure 'bookings.example.com' matches the hosting domain when using type 'sendmail'
    
            'host' => '${cfg.mail.host}', // for 'smtp' type only, otherwise remove or leave as is
            'user' => '${cfg.mail.user}', // for 'smtp' type only, otherwise remove or leave as is
            'pw' => '%%PASSWORD_MAIL%%',  // for 'smtp' type only, otherwise remove or leave as is
    
            'port' => '${cfg.mail.port}', // for 'smtp' type only, otherwise remove or leave as is
            'auth' => '${cfg.mail.auth}', // for 'smtp' type only, change this to 'login' if you have problems with SMTP authentication
        ),
        'i18n' => array(
            'choice' => array(
                'en-US' => 'English',
                'de-DE' => 'Deutsch',
    
                // More possible languages:
                // 'fr-FR' => 'Français',
                // 'hu-HU' => 'Magyar',
            ),
    
            'currency' => 'EUR',
    
            // The language is usually detected from the user's web browser.
            // If it cannot be detected automatically and there is no cookie from a manual language selection,
            // the following locale will be used as the default "fallback":
            'locale' => 'de-DE',
        ),
    );
  '';

  init_ep3bs = pkgs.writeScriptBin "init_ep3bs" ''
    #!${pkgs.stdenv.shell}

    cp -r ${ep3-bs-pkg}/* ${cfg.stateDir}
    chmod -R 0770 ${cfg.stateDir}
    mkdir ${cfg.stateDir}/vendor
    mkdir ${cfg.stateDir}/vendor/symfony
    cp ${cfg.stateDir}/config/init.php.dist ${cfg.stateDir}/config/init.php
    mv ${cfg.stateDir}/public/.htaccess_original ${cfg.stateDir}/public/.htaccess
    rm ${cfg.stateDir}/config/init.php.dist
    rm ${cfg.stateDir}/config/autoload/local.php.dist
    rm ${cfg.stateDir}/data/cache/*

    touch "${cfg.stateDir}/.is_initialized"
  '';

  update_ep3bs = pkgs.writeScriptBin "update_ep3bs" ''
    #!${pkgs.stdenv.shell}

    cd ${cfg.stateDir}
    ${pkgs.php81Packages.composer}/bin/composer install --ignore-platform-reqs
    cp ${cfg.favicon} ${cfg.stateDir}/public/imgs-client/icons/fav.ico
    cp ${cfg.logo} ${cfg.stateDir}/public/imgs-client/layout/logo.png

    cp -f ${configFile} ${cfg.stateDir}/config/autoload/local.php

    sed -i s/%%PASSWORD_DB%%/$(cat ${cfg.database.passwordFile})/ ${cfg.stateDir}/config/autoload/local.php
    sed -i s/%%PASSWORD_MAIL%%/$(cat ${cfg.mail.passwordFile})/ ${cfg.stateDir}/config/autoload/local.php


    if "${if cfg.in_production == true then "true" else "false"}"
    then
      rm ${cfg.stateDir}/public/setup.php
      sed -i "s/define('EP3_BS_DEV_TAG', true);/define('EP3_BS_DEV_TAG', false);/g" ${cfg.stateDir}/config/init.php
    else
      cp ${ep3-bs-pkg}/public/setup.php ${cfg.stateDir}/public/setup.php
      sed -i "s/define('EP3_BS_DEV_TAG', false);/define('EP3_BS_DEV_TAG', true);/g" ${cfg.stateDir}/config/init.php
    fi
  '';
in
{
  options = {
    services.ep3-bs = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = lib.mdDoc "Enable ep3-bs Service.";
      };

      in_production = mkOption {
        default = false;
        type = types.bool;
        description = lib.mdDoc ''
          If true it is assumed that database is setup correctly.
          If true, database setup will not be available in frontend anymore.
          Also debug and error logs are disabled in frontend.
        '';
      };

      user = mkOption {
        type = types.str;
        default = "ep3-bs";
        description = lib.mdDoc "User for ep3-bs.";
      };

      group = mkOption {
        type = types.str;
        default = "${config.services.httpd.group}";
        description = lib.mdDoc "Group for ep3-bs.";
      };

      favicon = mkOption {
        type = types.path;
        default = "${ep3-bs-pkg}/public/imgs-client/icons/fav.ico";
      };

      logo = mkOption {
        type = types.path;
        default = "${ep3-bs-pkg}/public/imgs-client/layout/logo.png";
        description  = ''png file with size 75x75'';
      };

      webserver = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Enable Apache HTTP Server running virtualHost on given Port
          '';
        };

        domain = mkOption {
          type = types.str;
          default = "localhost";
          description = ''
            Domain that webserver should listen for, like www.example.com.
          '';
        };

        port = mkOption {
          type = types.port;
          default = 80;
        };
      };

      extraConfig = mkOption {
        type = with types; nullOr str;
        default = null;
        description = lib.mdDoc "Configuration lines appended to the generated gitea configuration file.";
      };

      stateDir = mkOption {
        default = "/var/lib/ep3-bs";
        type = types.str;
        description = lib.mdDoc "ep3-bs data directory.";
      };

      mail = mkOption {
        description = "mail stuff";
        default = {};
        type = with types; submodule {
          options = {
            type = mkOption {
              type = types.enum [ "smtp" "smtp-tls" "sendmail" "file" ];
              default = "sendmail";
              description = lib.mdDoc ''
                The way mails are send.
                When set to smtp or smtp-tls it is necessary to set:
                host, user, password, port and auth."
              '';
            };

            address = mkOption {
              type = types.str;
              default = "";
              description = lib.mDoc "Address to send mails from.";
            };

            host = mkOption {
              type = types.str;
              default = "?";
            };

            user = mkOption {
              type = types.str;
              default = "?";
            };

            password = mkOption {
              type = types.str;
              default = "?";
            };

            passwordFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              example = "/run/keys/mail-passwd";
              description = lib.mdDoc ''
                A file containing the password corresponding to
                {option}`database.user`.
              '';
            };

            port = mkOption {
              type = types.str;
              default = "auto";
            };

            auth = mkOption {
              type = types.enum [ "plain" "login" ];
              default = "plain";
            };

          };
        };
      };

      database = {
        host = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = lib.mdDoc "Database host address.";
        };

        name = mkOption {
          type = types.str;
          default = "ep3bsdb";
          description = lib.mdDoc "Database name.";
        };

        user = mkOption {
          type = types.str;
          default = "ep3bs";
          description = lib.mdDoc "Database user.";
        };

        #password = mkOption {
        #  type = types.str;
        #  default = "";
        #  description = lib.mdDoc ''
        #    The password corresponding to {option}`database.user`.
        #    Warning: this is stored in cleartext in the Nix store!
        #    Use {option}`database.passwordFile` instead.
        #  '';
        #};

        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          example = "/run/keys/gitea-dbpassword";
          description = lib.mdDoc ''
            A file containing the password corresponding to
            {option}`database.user`.
          '';
        };

        createDatabase = mkOption {
          type = types.bool;
          default = true;
          description = lib.mdDoc "Whether to create a local database automatically.";
        };
      };
    };
  };

  config = mkIf cfg.enable
  {

    environment.systemPackages = with pkgs; [
      php81
      php81Packages.composer
      php81Extensions.intl
      git
    ];

    networking.firewall.allowedTCPPorts = [ 80 ];

    assertions = [
      {
        assertion = !(cfg.mail.type != "file" && cfg.mail.address == ""); 
        message = ''
          You need to specify mail.address.
          If you dont want to send email set mail.type to "file".
        '';
      }
      {
        assertion = if useSmtp then cfg.mail.host != "?" else true; 
        message = ''
          You need to specify mail.host when using mail.type "smtp" or "smtp-tls".
        '';
      }
      {
        assertion = if useSmtp then cfg.mail.user != "?" else true; 
        message = ''
          You need to specify mail.user when using mail.type "smtp" or "smtp-tls".
        '';
      }
      {
        assertion = if useSmtp then cfg.mail.password != "?" else true; 
        message = ''
          You need to specify mail.password when using mail.type "smtp" or "smtp-tls".
        '';
      }
    ];

    services.httpd = {
      enable = mkDefault true;
      enablePHP = true;
      phpPackage = mkDefault pkgs.php81;
      adminAddr = mkDefault "alice@example.org";
      extraModules = [
        "rewrite"
      ];
      virtualHosts."${cfg.webserver.domain}" = {
        documentRoot = mkDefault "${cfg.stateDir}/public/";
        extraConfig = ''
          <Directory ${cfg.stateDir}/public/>
          DirectoryIndex index.php index.htm index.html
          Allow from *
          Options +FollowSymlinks
          AllowOverride All
          Require all granted
          php_admin_flag display_errors on
          php_admin_value error_reporting 22517
          </Directory>
        '';
      };
    };

    services.mysql = mkIf (cfg.database.createDatabase == true) {
      enable = mkDefault true;
      package = mkDefault pkgs.mariadb;

      initialScript = pkgs.writeText "mysqlInitScript" ''
        CREATE USER '${cfg.database.user}'@localhost IDENTIFIED BY 'PW FOO';
        CREATE DATABASE ${cfg.database.name};
        GRANT ALL PRIVILEGES ON *.* TO '${cfg.database.user}'@localhost IDENTIFIED BY 'PW FOO';
        FLUSH PRIVILEGES;
      '';

      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        { name = cfg.database.user;
          ensurePermissions = { "${cfg.database.name}.*" = "ALL PRIVILEGES"; };
        }
      ];
    };

    systemd.services.ep3-bs-init = {
      description = "Initialize ep3-bs Data Directory";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        mkdir -m 0770 -p "${cfg.stateDir}"
        chown "${cfg.user}:${cfg.group}" "${cfg.stateDir}"
      '';

      unitConfig.ConditionPathExists = "!${cfg.stateDir}/.is_initialized";

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        PermissionsStartOnly = true;
        PrivateNetwork = false;
        PrivateDevices = false;
        PrivateTmp = true;
        ExecStart = "${init_ep3bs}/bin/init_ep3bs";
      };

      environment = {
        USER = cfg.user;
        HOME = cfg.stateDir;
      };
    };

    systemd.services.ep3-bs-update = {
      description = "Update ep3-bs Configuration";
      after = [ "network.target" "ep3-bs-init.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        PermissionsStartOnly = true;
        PrivateNetwork = false;
        PrivateDevices = false;
        PrivateTmp = true;
        ExecStart = "${update_ep3bs}/bin/update_ep3bs";
      };

      environment = {
        USER = cfg.user;
        HOME = cfg.stateDir;
      };
    };

    users.users = mkIf (cfg.user == "ep3-bs") {
      ep3-bs = {
        description = "ep3-bs Service User";
        group = "${cfg.group}";
        isNormalUser = true;
      };
    };

  };
}

