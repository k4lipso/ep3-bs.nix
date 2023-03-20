{ config, lib, options, pkgs, ... }:

with lib;

let
  cfg = config.services.ep3-bs;

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

    nixosModules.ep3-bs = import ./ep3-bs.nix {
      ep3-bs-pkg = self.packages.x86_64-linux.ep3-bs;
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
            'password' => '${cfg.database.password}',
    
            'hostname' => 'localhost',
            'port' => null,
        ),
        'mail' => array(
            'type' => 'sendmail', // or 'smtp' or 'smtp-tls' (or 'file', to not send, but save to file (data/mails/))
            'address' => 'info@test.de',
                // Make sure 'bookings.example.com' matches the hosting domain when using type 'sendmail'
    
            'host' => '?', // for 'smtp' type only, otherwise remove or leave as is
            'user' => '?', // for 'smtp' type only, otherwise remove or leave as is
            'pw' => '?', // for 'smtp' type only, otherwise remove or leave as is
    
            'port' => 'auto', // for 'smtp' type only, otherwise remove or leave as is
            'auth' => 'plain', // for 'smtp' type only, change this to 'login' if you have problems with SMTP authentication
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

    mkdir /tmp

    #TODO: dont do this
    rm -rf ${cfg.stateDir}/*

    echo "echoing name: $(whoami)"
    echo "path of ep3bs: ${ep3-bs-pkg}"
    cp -r ${ep3-bs-pkg}/* ${cfg.stateDir}
    mkdir ${cfg.stateDir}/vendor
    mkdir ${cfg.stateDir}/vendor/symfony
    chmod -R 777 ${cfg.stateDir}

    cd ${cfg.stateDir}
    ${pkgs.php81Packages.composer}/bin/composer install --ignore-platform-reqs
    chmod -R 777 ${cfg.stateDir}
    ${pkgs.php81Packages.composer}/bin/composer install --ignore-platform-reqs

    cp ${cfg.stateDir}/config/init.php.dist ${cfg.stateDir}/config/init.php
    echo "path of cfg file: ${configFile}"

    cp -f ${configFile} ${cfg.stateDir}/config/autoload/local.php

    mv ${cfg.stateDir}/public/.htaccess_original ${cfg.stateDir}/public/.htaccess

    ${pkgs.php81}/bin/php ${cfg.stateDir}/public/setup.php
    #TODO: rm setup

    rm ${cfg.stateDir}/data/cache/*
    chmod -R 777 ${cfg.stateDir}

    if [ -d "${cfg.stateDir}" ]; then
      echo "${cfg.stateDir} already exists. Not doing anything..."
      exit 0
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

      user = mkOption {
        type = types.str;
        default = "ep3-bs";
        description = lib.mdDoc "User account under which ep3-bs runs.";
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

      database = {
        host = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = lib.mdDoc "Database host address.";
        };

        #port = mkOption {
        #  type = types.port;
        #  default = if !usePostgresql then 3306 else pg.port;
        #  defaultText = literalExpression ''
        #    if config.${opt.database.type} != "postgresql"
        #    then 3306
        #    else config.${options.services.postgresql.port}
        #  '';
        #  description = lib.mdDoc "Database host port.";
        #};

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

        password = mkOption {
          type = types.str;
          default = "";
          description = lib.mdDoc ''
            The password corresponding to {option}`database.user`.
            Warning: this is stored in cleartext in the Nix store!
            Use {option}`database.passwordFile` instead.
          '';
        };

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

  imports = [
    {
      environment.systemPackages = with pkgs; [
        php81
        php81Packages.composer
        php81Extensions.intl
        git
      ];

      networking.firewall.allowedTCPPorts = [ 80 ];
    }
  ];

  config = mkIf cfg.enable
  {
    #TODO: do some shit in prestart -> set everything up
    #start apache with document root pointing towards
    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 777 ${cfg.user} ep3-bs - -"
      "d '${cfg.stateDir}/config' 777 ${cfg.user} ep3-bs - -"
      "d '${cfg.stateDir}/config/autoload' 777 ${cfg.user} ep3-bs - -"
      "d '${cfg.stateDir}/vendor' 777 ${cfg.user} ep3-bs - -"
      "d '${cfg.stateDir}/vendor/symfony' 777 ${cfg.user} ep3-bs - -"
      "Z '${cfg.stateDir}' 777 ${cfg.user} ep3-bs - -"
    ];

    services.httpd = {
      enable = mkDefault true;
      user = mkDefault "${cfg.user}";
      enablePHP = true;
      phpPackage = pkgs.php81;
      adminAddr = mkDefault "alice@example.org";
      extraModules = [
        "rewrite"
      ];
      virtualHosts.localhost = {
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

    services.mysql = {
      enable = mkDefault true;
      package = mkDefault pkgs.mariadb;

      #GRANT ALL PRIVILEGES ON DATABASE ${cfg.database.name} TO '${cfg.database.user}'@'localhost';
      initialScript = pkgs.writeText "mysqlInitScript" ''
        CREATE USER '${cfg.database.user}'@localhost IDENTIFIED BY '${cfg.database.password}';
        CREATE DATABASE ${cfg.database.name};
        GRANT ALL PRIVILEGES ON *.* TO '${cfg.database.user}'@localhost IDENTIFIED BY '${cfg.database.password}';
        FLUSH PRIVILEGES;
      '';

      #ensureDatabases = [ cfg.database.name ];
      #ensureUsers = [
      #  { name = cfg.database.user;
      #    ensurePermissions = { "${cfg.database.name}.*" = "ALL PRIVILEGES"; };
      #  }
      #];
    };

    systemd.services.ep3-bs = {
      description = "ep3-bs";
      after = [ "network.target" "mysql.service" ];
      wantedBy = [ "multi-user.target" ];

      #TODO: here somehow the ep3-bs package should be listed?
      path = [ ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "ep3-bs";
        WorkingDirectory = cfg.stateDir;
        ExecStart = "${init_ep3bs}/bin/init_ep3bs";
        # Runtime directory and mode
        RuntimeDirectory = "ep3-bs";
        RuntimeDirectoryMode = "0755";
        # Access write directories
        ReadWritePaths = [ cfg.stateDir ];
        UMask = "777";
        # Capabilities
        #CapabilityBoundingSet = "";
        ## Security
        #NoNewPrivileges = true;
        ## Sandboxing
        #ProtectSystem = "strict";
        #ProtectHome = true;
        #PrivateTmp = true;
        #PrivateDevices = true;
        #PrivateUsers = true;
        #ProtectHostname = true;
        #ProtectClock = true;
        #ProtectKernelTunables = true;
        #ProtectKernelModules = true;
        #ProtectKernelLogs = true;
        #ProtectControlGroups = true;
        #RestrictAddressFamilies = [ "AF_UNIX AF_INET AF_INET6" ];
        #LockPersonality = true;
        #MemoryDenyWriteExecute = true;
        #RestrictRealtime = true;
        #RestrictSUIDSGID = true;
        #PrivateMounts = true;
        ## System Call Filtering
        #SystemCallArchitectures = "native";
        #SystemCallFilter = "~@clock @cpu-emulation @debug @keyring @module @mount @obsolete @raw-io @reboot @setuid @swap";
      };

      environment = {
        USER = cfg.user;
        HOME = cfg.stateDir;
        EP3-BS_WORK_DIR = cfg.stateDir;
      };
    };

    users.users = mkIf (cfg.user == "ep3-bs") {
      ep3-bs = {
        description = "ep3-bs Service";
        home = cfg.stateDir;
        useDefaultShell = true;
        group = "ep3-bs";
        isSystemUser = true;
      };
    };

    users.groups.ep3-bs = {};

  };
}

