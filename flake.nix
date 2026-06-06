{
  description = "Ramboplay RA2 launcher via Wine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        name = "ramboplay-wine";

        nativeBuildInputs = with pkgs; [
          p7zip
          wineWow64Packages.stable
          winetricks
          curl
          unzip
          caddy
          dxvk
        ];

        ASPNETCORE_URL = "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/5.0.17/aspnetcore-runtime-5.0.17-win-x86.zip";

        shellHook = ''
          export WINEPREFIX="$PWD/.wine"
          export WINEARCH=win64
          export WINEDEBUG=-all
          export WINEDLLOVERRIDES="mscoree,mshtml="

          # Extract archive
          if [ ! -d "client" ]; then
            echo "[ramboplay] Extracting ramboply.2.2.6_full.7z ..."
            7z x -y ramboply.2.2.6_full.7z
            echo "[ramboplay] Extraction complete."
          fi
          # Install ASP.NET Core 5.0 runtime in wine prefix if missing
          DOTNET_DIR="$WINEPREFIX/drive_c/Program Files (x86)/dotnet"
          if [ ! -f "$DOTNET_DIR/host/fxr/5.0.17/hostfxr.dll" ]; then
            echo "[ramboplay] ASP.NET Core 5.0 runtime not found, installing..."
            mkdir -p "$DOTNET_DIR"
            curl -fsSL --retry 3 -o /tmp/aspnetcore5.zip "$ASPNETCORE_URL"
            unzip -o /tmp/aspnetcore5.zip -d "$DOTNET_DIR" > /dev/null
            rm -f /tmp/aspnetcore5.zip
            echo "[ramboplay] ASP.NET Core 5.0.17 installed."
          fi

          # Install DXVK for GPU acceleration (WebView2/Chromium rendering)
          if [ ! -f "$WINEPREFIX/drive_c/windows/system32/dxgi.dll" ]; then
            echo "[ramboplay] Installing DXVK for GPU acceleration..."
            setup_dxvk.sh install --symlink
            echo "[ramboplay] DXVK installed."
          fi

          echo ""
          echo "============================================"
          echo "  Ramboplay (蓝博玩) RA2 — Wine Environment"
          echo "============================================"
          echo ""
          echo "  Terminal 1 — start the backend:"
          echo "    wine client/ramboplay.ra2.exe"
          echo ""
          echo "  Terminal 2 — start the local proxy:"
          echo "    caddy run --config Caddyfile"
          echo ""
          echo "  Then open in your browser:"
          echo "    http://localhost:3601"
          echo ""
          echo "  The proxy combines the remote frontend"
          echo "  (client.ok-skins.com) with the local"
          echo "  backend so everything is same-origin."
          echo "============================================"
          echo ""
        '';
      };
    };
}
