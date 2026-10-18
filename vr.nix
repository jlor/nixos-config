{ pkgs, ... }:

# The Quest 3 as a PC VR headset, over WiVRn.
#
# Meta's own Quest Link — both the USB and the Air Link half — is a Windows-only
# stack, so there is no way to use the headset as a plain tethered display here.
# WiVRn replaces it end to end: a server on this machine encodes each eye on the
# GPU and streams it over the LAN to a client app on the headset, and sends the
# headset's pose and the controllers back. It carries its own patched Monado, so
# it *is* the OpenXR runtime — there's no separate runtime to install or select.
#
# The headset side is a free app on the Meta Horizon Store ("WiVRn"), and is the
# one piece that can't come from this repo; the README's install steps cover it.
#
# This machine is on ethernet (enp113s0), which is the half of the link that
# matters most — the headset's own Wi-Fi hop to the router is then the only
# wireless leg. 5 GHz or 6 GHz, same subnet as this machine.

{
  services.wivrn = {
    enable = true;

    # 9757/tcp+udp for the stream. The module also switches Avahi on, so the
    # headset finds this machine by mDNS instead of a typed-in IP address.
    openFirewall = true;

    # Run the server from login, so putting the headset on and opening the
    # client is the whole startup sequence — no reaching for the keyboard.
    autoStart = true;

    # Installs wivrn-server setuid-free but with cap_sys_nice, which is what
    # lets the compositor outrank the game's render threads. Without it a frame
    # that misses its deadline tears instead of being reprojected.
    highPriority = true;

    # Steam only exposes OpenXR runtimes to a game if it knew about them when
    # the game launched; this sets PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES so
    # Proton titles can see WiVRn. Needs a logout to take effect.
    steam.importOXRRuntimes = true;

    # NVENC is compiled out of the default build because it needs CUDA, which
    # leaves WiVRn on the Vulkan encoder — and Vulkan Video encode tops out at
    # H.265. The 5090 encodes AV1, which is the codec the Quest 3 decodes
    # best, so it's worth the override. cache.nixos-cuda.org (already a trusted
    # substituter, see configuration.nix) has this build, so it doesn't compile.
    package = pkgs.wivrn.override { cudaSupport = true; };

    config = {
      enable = true;
      json = {
        # One entry applies to every stream: both eyes and the alpha channel.
        # Default would be vulkan/h265 on this GPU.
        encoder = {
          encoder = "nvenc";
          codec = "av1";
        };
      };
    };
  };

  # Most sim racing titles are OpenVR (SteamVR), not OpenXR. The wivrn package
  # is built with both translation layers — xrizer and OpenComposite — baked
  # into its OVR search path, so an OpenVR game is redirected into WiVRn's
  # OpenXR runtime without SteamVR being installed at all. xrizer is tried
  # first; the dashboard can switch a game to OpenComposite if it misbehaves.
}
