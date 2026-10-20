# Disk formatting

New disk images default to ProDOS. DOS 3.3 is available for 140 KB media and uses
DOS-order `.do` images. ProDOS uses block-order `.po` or `.hdv` images,
with a 2IMG container for 800 KB media. Unformatted images contain zero-filled
sector data. Formatting does not install operating system files. ProDOS formatting does include
the bootstrap needed to load `PRODOS` after an operating system is installed.

The ProDOS formatter writes the standard loader in block 0, a four-block volume directory and the allocation
bitmap, reserving the boot, directory and bitmap blocks. Its volume name is
adapted from the destination filename. The DOS formatter writes the VTOC and
15 empty catalog sectors, reserving tracks 0–2 and 17; its volume number is 254.

Existing HFS images can still be used by GS/OS with the appropriate filesystem
support. The builder does not format new HFS volumes.

References:

- [ProDOS volume directory and bitmap specification](https://prodos8.com/docs/techref/file-organization/)
- [CiderPress DOS filesystem notes](https://ciderpress2.com/formatdoc/DOS-notes.html)

Run `scripts/test-disk-image-device.sh` for capacity, allocation, directory and
container checks, including unformatted media and incompatible-format failures.
For independent validation, use CiderPress II's `test`, `add` and `extract`
commands against copies of generated disks. AppleCommander 15.0 adds an extra
bitmap block at exact multiples of 4,096 ProDOS blocks; its checker and writer
therefore disagree with valid 10 MB and 20 MB volumes. Do not alter our allocation
map to match that behavior.

## ProDOS bootstrap provenance

The 512-byte standard loader matches the GS/OS 6.0.1 System Disk boot block.
The byte sequence is reproduced from CiderPress II 1.2.0,
`DiskArc/FS/ProDOS.cs` (`sBootBlock0`), which credits Apple Computer, Inc.
CiderPress II's source file is copyright 2022 faddenSoft, licensed under the
Apache License 2.0. Its license is included in `Resources/CiderPress-LICENSE.txt`.
No CiderPress executable or operating system files are bundled.

A volume can be usable for saving files while still being unable to boot. System
installation does not necessarily replace the boot block on an existing volume.
The regression checks therefore require a loader on formatted ProDOS media,
while unformatted images must still contain only zero-filled sectors.
