{ stdenv, fetchurl, python3, lib }:

# Bluetooth firmware for the MediaTek MT7927 (Filogic 380) Wi-Fi 7 + BT 5.4
# combo chip — the BT side (MT6639, USB 0489:e13a) as found e.g. on the
# ASUS ROG STRIX X870-I GAMING WIFI.
#
# The in-tree BT driver (kernel >= 7.1) loads
# mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin, which is not (yet) in
# upstream linux-firmware; it only ships inside MediaTek's Windows drivers.
# This pins the ASUS support-page driver zip for MT7927 boards and extracts
# the blob into the standard firmware path.
#
# The Wi-Fi firmware (mediatek/mt7927/WIFI_*) already comes from
# linux-firmware, so only the BT half needed this.
#
# Blob source and the mtkwlan.dat container layout: see
# extract-mt7927-bt-firmware.py.
stdenv.mkDerivation {
  pname = "mt7927-bt-firmware";
  version = "20250709";

  src = fetchurl {
    # ASUS support CDN. The unsigned dlcdnets.asus.com host serves the same
    # file the support page downloads via its signed dlcdnta.asus.com token
    # API; pinning the stable unsigned URL.
    url =
      "https://dlcdnets.asus.com/pub/ASUS/mb/08WIRELESS/DRV_WiFi_MTK_MT7925_MT7927_TP_W11_64_V5603998_20250709R.zip";
    sha256 = "b377fffa28208bb1671a0eb219c84c62fba4cd6f92161b74e4b0909476307cc8";
  };

  nativeBuildInputs = [ python3 ];

  dontUnpack = true;

  buildPhase = ''
    runHook preBuild
    python3 ${./extract-mt7927-bt-firmware.py} \
      "$src" \
      "$out/lib/firmware/mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin"
    runHook postBuild
  '';

  meta = with lib; {
    description = "Bluetooth firmware (MT6639) for the MediaTek MT7927 Wi-Fi 7 + BT 5.4 combo chip";
    license = licenses.unfreeRedistributable;
    platforms = platforms.linux;
  };
}
