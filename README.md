# Disclaimer
Though this is now a rock solid setup for me, don't hold me responsible for anything ranging from system instability to catastrophic data loss. You've been warned.

I'm a total newcomer to nix and all of the code was co-written with Gemini. Please only use the contents of this repo and the binaries on Cachix, if you are fine with the risks of using vibecoded configs. I'm mostly publishing this repo for myself. Hopefully someone more competent will carry the torch for me.

# Bitwig yabridge setup recipe (Updated April 14, 2026)
This repo contains my wine-musicprod.nix, that compiles and sets up:
- Some kind of system Wine install
- [Giang17's fork of Wine 11.0](https://github.com/giang17/wine/tree/d2d1-dcomp-11.0) for Serum 2
- The new-wine10-embedding branch of yabridge so that plugins requiring a version of Wine newer than 9.21 (like Serum 2) won't have too many problems
- An FHS setup for Bitwig Studio 6.0 so it will have less trouble loading Linux native VSTs
- **A Wine router that shouldn't conflict with launchers such as Lutris or Heroic, that redirects wine to Giang17's fork if ``$WINEPREFIX`` contains ``serum`` or ``vst-wine-prefixes/default``. You might want to change this depending on your setup.**
- A Winetricks router so you can continue to use that.

Note that you will have to supply your own copy of the Bitwig Studio .deb file, and the config assumes [a bitwig.jar that is patched for custom themes.](https://github.com/Berikai/bitwig-theme-editor) 

Another pitfall is the bitbridge from yabridge gets nuked due to some sort of error while compiling yabridge. No more Delay Lama, sadly :(

I've also set up a Cachix cache containing the binaries for everything except Bitwig so you don't have to spend up to a few hours of your time and CPU power compiling 2 builds of Wine and a build of yabridge.
```nix
{
  nix.settings = {
    substituters = [
      "https://jake0x539.cachix.org"
    ];
    trusted-public-keys = [
      "jake0x539.cachix.org-1:WqPqua70tU6xqb+e91lc35VeTkF2ANdC9ZaPtmqCM9o="
    ];
  };
}
```

## Step 0
If you trust me and my computer to be secure, add my Cachix cache to your substituters to avoid recompiling stuff.

## Step 1 
Procure your own Bitwig Studio install .deb, extract the .jar, patch it with the theme editor.

Use ``nix hash file [filename]`` on both your .deb and patched .jar, run ``nix-store --add-fixed sha256 [filename]`` on both of them, then go to lines 113 and 119 in wine-musicprod.nix and fill in your hashes.

## Step 3
Import wine-musicprod.nix in home-manager (or your config otherwise? I don't know). Ensure Wine or winetricks isn't installed in other ways. I suppose Nix will complain if it's necessary.
```nix
imports = [ ./wine-musicprod.nix ]
```

## Step 4
Make sure you install your plugins into a WINEPREFIX containing ``serum`` to use wine-giang17, or into ``vst-wine-prefixes/default``, to use Wine 9.21-staging.

## Step 5
Set up yabridge as normal and make music.

# License
The contents of this repo are [unlicensed](https://unlicense.org). **Wine and yabridge, including the binaries on Cachix, are subject to their own licenses** (LGPL for Wine and GPL for yabridge, I think).

```
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <https://unlicense.org/>
```
