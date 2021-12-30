# Script for flashing EdgeRouter X SFP with OpenWrt

## Usage

- Connect to eth0 of EdgeRouter X SFP with default configuration
- Set ethernet IP of your PC to 192.168.1.5/24
- Ensure that no other device in your network has IP 192.168.1.20 or 192.168.1.1
- execute [./flash_openwrt.sh](./flash_openwrt.sh)
- wait
- Connect to eth1 of EdgeRouter when instructed to do
- wait for finishing

## Demonstration

![](asciicast.svg)

## How it works

- It downloads
  - Ubiquiti EdgeOS 2.0.6 stock firmware with new bootloader e51_002_4c817
  - OpenWrt 18.06-snapshot-r7911 initramfs factory with small enough kernel for flashing through EdgeOS
  - OpenWrt 21.02.1 sysupgrade image
- Ensures that only one firmware image is stored on device
- Installs EdgeOS 2.0.6
- Checks bootloader version an upgrades to boodloader that enables TFTP recovery in case something goes wrong
- Installs OpenWrt initramfs factory image and then sysupgrade to current verion
- Shows if it worked

## See also

[EdgeRouter - Manual TFTP Recovery](https://help.ui.com/hc/en-us/articles/360018189493)
[EdgeRouter - How to Update the Bootloader](https://help.ui.com/hc/en-us/articles/360009932554-EdgeRouter-How-to-Update-the-Bootloader)

## License

Copyright &copy; 2021 Daniel A. Maierhofer
