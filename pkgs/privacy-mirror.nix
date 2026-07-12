{ lib, stdenv, swift, swiftPackages }:
stdenv.mkDerivation {
  pname = "privacy-mirror";
  version = "0.1.0";

  src = lib.cleanSourceWith {
    src = ../apps/privacy-mirror;
    filter = path: type:
      let name = baseNameOf path;
      in !builtins.elem name [ ".build" ".swiftpm" ];
  };

  nativeBuildInputs = [ swift swiftPackages.swiftpm ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    export HOME="$TMPDIR"
    swift build -c release --disable-sandbox
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    app="$out/Applications/Privacy Mirror.app/Contents"
    mkdir -p "$app/MacOS" "$app/Resources"
    install -m755 .build/release/PrivacyMirror "$app/MacOS/PrivacyMirror"
    install -m644 Info.plist "$app/Info.plist"
    mkdir -p "$out/bin"
    install -m755 privacy-mirror-move.sh "$out/bin/privacy-mirror-move"

    runHook postInstall
  '';

  postFixup = ''
    /usr/bin/codesign --force --deep --sign - \
      --identifier com.benny.PrivacyMirror \
      "$out/Applications/Privacy Mirror.app"
  '';

  meta = {
    description = "Shareable screen mirror that hides configured AeroSpace workspaces";
    platforms = lib.platforms.darwin;
  };
}
