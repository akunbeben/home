{ pkgs }:

pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencode";
  version = "1.15.3";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/opencode-ai/-/opencode-ai-${finalAttrs.version}.tgz";
    sha256 = "05z3gxxfbjzcxxkjl32950aialkwa3q4hssnna4jiznlyq4jqa5y";
  };

  binarySrc = pkgs.fetchurl {
    url = "https://registry.npmjs.org/opencode-darwin-arm64/-/opencode-darwin-arm64-${finalAttrs.version}.tgz";
    sha256 = "0abnfrrisvsh16vyr1pxi56gnpzri0knpaqgiq20d2xqfs6kg8a3";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/share/doc/opencode" "$TMPDIR/opencode-ai"

    tar -xzf "$binarySrc" -C "$TMPDIR"
    install -m755 "$TMPDIR/package/bin/opencode" "$out/bin/opencode"

    tar -xzf "$src" -C "$TMPDIR/opencode-ai"
    install -m644 "$TMPDIR/opencode-ai/package/LICENSE" "$out/share/doc/opencode/LICENSE"

    runHook postInstall
  '';

  meta = {
    description = "AI coding agent built for the terminal";
    homepage = "https://opencode.ai";
    license = pkgs.lib.licenses.mit;
    mainProgram = "opencode";
    platforms = [ "aarch64-darwin" ];
  };
})
