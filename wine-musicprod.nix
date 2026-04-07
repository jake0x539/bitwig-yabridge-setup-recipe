{
  pkgs,
  lib,
  ...
}: let
  # The most recent staging wine in nixpkgs for my system wine. Change this if you want
  systemWine = pkgs.wineWow64Packages.stagingFull_11;

  # Wine 9.21 for stability for some plugins
  wine921 = pkgs.wineWow64Packages.yabridge;

  wineGiang = pkgs.wineWow64Packages.full.overrideAttrs (oldAttrs: {
    version = "11.0-giang17";
    src = pkgs.fetchFromGitHub {
      owner = "giang17";
      repo = "wine";
      rev = "bc035cc4260d14a199d4158d3b28ebfd0f3bdb6a";
      hash = "sha256-fnHeCQY8ect5Z0lBUarEh4mXTvlxF0dtTncRZH121pE="; # Replace with 'got' hash
    };

    patches = [];

    prePatch = "";
  });

  # The "Wine 10/11" specialized bridge
  yabridge-custom =
    (pkgs.yabridge.override {
      wine = wineGiang;
    }).overrideAttrs (oldAttrs: {
      pname = "yabridge";
      version = "6.0.0-embedding-beta";

      src = pkgs.fetchFromGitHub {
        owner = "robbert-vdh";
        repo = "yabridge";
        rev = "945528cd7f898d717d772b93f939343dad122d91";
        hash = "sha256-qjyBnwdd/yRIiiAApHyxc/XkkEwB33YP0GpIjG4Upro=";
      };

      patches = [];

      # Turn off 32-bit bit bridge
      mesonFlags =
        (builtins.filter (f: !lib.hasPrefix "-Dbitbridge=" f) (oldAttrs.mesonFlags or []))
        ++ [
          "-Dbitbridge=false"
        ];

      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin $out/lib

        # Only install the 64-bit host binaries
        cp yabridge-host.exe $out/bin/ || true
        cp yabridge-host.exe.so $out/bin/ || true

        for type in vst2 vst3 clap; do
          src=$(ls *yabridge-$type.so 2>/dev/null | head -n 1)
          if [ -n "$src" ]; then
            cp "$src" "$out/lib/libyabridge-$type.so"
            ln -s "$out/lib/libyabridge-$type.so" "$out/lib/libyabridge-chainloader-$type.so"
          fi
        done

        runHook postInstall
      '';

      doCheck = false;
    });

  patchedJar = pkgs.requireFile {
    name = "bitwig-patched.jar";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    message = "Run: nix-store --add-fixed sha256 bitwig-patched.jar";
  };

  bitwigDeb = pkgs.requireFile {
    name = "bitwig-studio-6.0.deb";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    message = "Run: nix-store --add-fixed sha256 bitwig-studio-6.0.deb";
  };

  # 5. The Local Bitwig Build
  bitwig6-local = pkgs.stdenv.mkDerivation {
    pname = "bitwig-studio-local";
    version = "6.0";
    src = bitwigDeb;

    nativeBuildInputs = [pkgs.dpkg pkgs.makeWrapper];
    unpackPhase = "dpkg-deb -x $src .";

    installPhase = ''
      mkdir -p $out/bin $out/libexec $out/share

      # Copy the app files
      cp -r opt/bitwig-studio/* $out/libexec/

      # COPY THE ICONS AND DESKTOP FILES (This was missing!)
      cp -r usr/share/* $out/share/

      # Overwrite original JAR with your patched one
      rm $out/libexec/bin/bitwig.jar
      cp ${patchedJar} $out/libexec/bin/bitwig.jar

      # Link the binary
      ln -s $out/libexec/bitwig-studio $out/bin/bitwig-studio
    '';
  };

  # 6. The FHS Safety Bubble
  bitwig-fhs = pkgs.buildFHSEnv {
    name = "bitwig-studio";
    targetPkgs = p:
      with p; [
        bitwig6-local
        zlib
        libjack2
        libpulseaudio
        icu
        # Graphics & X11
        xorg.libX11
        xorg.libXcursor
        xorg.libXext
        xorg.libXfixes
        xorg.libXi
        xorg.libXrender
        xorg.libXtst
        libxcb
        xcbutilxrm
        xorg.xcbutilwm
        xorg.xcbutilimage
        libxcb-util
        xorg.xcbutilkeysyms
        xorg.xcbutilrenderutil
        libxcursor
        libx11
        libxtst
        libxkbcommon
        harfbuzz
        curl
        libudev-zero
        # System Deps
        alsa-lib
        at-spi2-atk
        cairo
        cups
        dbus
        expat
        fontconfig
        freetype
        mesa
        gdk-pixbuf
        glib
        gtk3
        libGL
        libglvnd
        libxkbcommon
        nspr
        nss
        pango
        pipewire
        stdenv.cc.cc.lib
        vulkan-loader
        zlib
        libGLU
        libGLX
        libGL
        freeglut
        libglvnd
        glibc
      ];
    runScript = "bitwig-studio";
    extraInstallCommands = ''
      mkdir -p $out/share/icons/hicolor/scalable/apps
      mkdir -p $out/share/applications

      # Link icons from our fixed local build
      # Note: Using a wildcard *bitwig* ensures we catch whatever name they used
      cp ${bitwig6-local}/share/icons/hicolor/scalable/apps/*.svg \
         $out/share/icons/hicolor/scalable/apps/bitwig-studio.svg

      # Link the desktop file
      cp ${bitwig6-local}/share/applications/*.desktop \
         $out/share/applications/bitwig-studio.desktop
    '';
  };

  wine-router = pkgs.writeShellScriptBin "wine" ''
    # If the prefix contains serum, use the Giang17 audio build
    # If the prefix contains vst-wine-prefixes/default, use wine 9.21 for yabridge
    if [[ "$WINEPREFIX" == *"/serum"* ]]; then
      export WINEDLLOVERRIDES="d3d11,dxgi,d3d10core,d3d9=b"
      exec ${wineGiang}/bin/wine "$@"
    elif [[ "$WINEPREFIX" == *"vst-wine-prefixes/default"* ]]; then
        exec ${wine921}/bin/wine "$@"
    else
      # Fall back to the system-wide modern Wine for everything else
      exec ${systemWine}/bin/wine "$@"
    fi
  '';

  wineserver-router = pkgs.writeShellScriptBin "wineserver" ''
    if [[ "$WINEPREFIX" == *"/serum"* ]]; then
        exec ${wineGiang}/bin/wineserver "$@"
    elif [[ "$WINEPREFIX" == *"vst-wine-prefixes/default"* ]]; then
        exec ${wine921}/bin/wineserver "$@"
    else
        # Fall back to the system-wide modern Wine for everything else
        exec ${systemWine}/bin/wineserver "$@"
    fi
  '';

  winetricks-router = pkgs.writeShellScriptBin "winetricks" ''
    if [[ "$WINEPREFIX" == *"/serum"* ]]; then
      export WINE="${wineGiang}/bin/wine"
      export WINESERVER="${wineGiang}/bin/wineserver"
    elif [[ "$WINEPREFIX" == *"vst-wine-prefixes/default"* ]]; then
      export WINE="${wine921}/bin/wine"
      export WINESERVER="${wine921}/bin/wineserver"
    else
      export WINE="${systemWine}/bin/wine"
      export WINESERVER="${systemWine}/bin/wineserver"
    fi

    # Run the real winetricks with the real binary paths injected
    exec ${pkgs.winetricks}/bin/winetricks "$@"
  '';
in {
  home.packages = [
    bitwig-fhs
    wine-router
    wineserver-router
    winetricks-router
    pkgs.curl
    pkgs.libGL
    pkgs.libGLU
    pkgs.libGLX
    pkgs.yabridgectl
    yabridge-custom
  ];

  # xdg.enable = true;
  # xdg.desktopEntries.bitwig = {
  #   name = "Bitwig Studio";
  #   exec = "bitwig-studio %U";
  #   icon = "bitwig-studio"; # This matches the name we just created
  #   comment = "My favorite DAW";
  #   categories = ["AudioVideo" "AudioVideoEditing"];
  #   terminal = false;
  # };

  home.sessionVariables = {
    # You need this for Kilohearts plugins
    WINEFSYNC = "1";
  };
}
