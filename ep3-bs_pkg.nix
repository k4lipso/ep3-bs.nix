{ config, lib, pkgs, ... }:

  stdenv.mkDerivation rec {
    pname = "ep3-bs";

    src = fetchFromGitHub {
      owner = "tkrebs";
      repo = "ep3-bs";
      rev = "1.8.1";
      sha256 = "sha256-UqlUhzkt1Xj/LHw9LrJqQ5ldg+Mib1gMUlwG9cBWeBI=";
    };

    patches = [];

    #passthru.tests = nixosTests.nextcloud;

    #installPhase = ''
    #  runHook preInstall
    #  mkdir -p $out/
    #  cp -R . $out/
    #  runHook postInstall
    #'';

    #meta = with lib; {
    #  changelog = "https://nextcloud.com/changelog/#${lib.replaceStrings [ "." ] [ "-" ] version}";
    #  description = "Sharing solution for files, calendars, contacts and more";
    #  homepage = "https://nextcloud.com";
    #  maintainers = with maintainers; [ schneefux bachp globin ma27 ];
    #  license = licenses.agpl3Plus;
    #  platforms = with platforms; unix;
    #  knownVulnerabilities = extraVulnerabilities
    #    ++ (optional eol "Nextcloud version ${version} is EOL");
    #};
  };
