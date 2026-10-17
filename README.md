# Samsung ML-1640 / ML-1660 printer driver for Apple Silicon (M1 to M4) macOS

These printers are GDI/QPDL-only devices. They cannot interpret PDF or PostScript,
so the Mac must render every page to QPDL itself. This repo ships the arm64 build of
the open source SpliX `rastertoqpdl` filter plus PPDs for the ML-1640 and ML-1660.

*__Keep working hardware working.__ A laser printer like the ML-1640 is made of steel, aluminium, copper, plastic and electronics. Making one costs far more energy and raw material than it will ever use printing. When a driver disappears, none of that is worn out. The printer is fine, the toner is fine, only the software is gone.*

*Every year millions of printers end up as e-waste for exactly this reason. The fix here is a few kilobytes: an open source filter and a config file. If your old printer still turns on, it probably deserves the same chance before it goes to the recycling bin.*

Tested on:

- Apple M1, macOS Ventura
- Apple M4 Pro, macOS 27.0.1 (printer shared over the network from a Windows PC)

## Quick install (recommended)

```
git clone https://github.com/djwmarcx/Samsung-ML-Printer-Apple-Silicon.git
cd Samsung-ML-Printer-Apple-Silicon
sudo ./install.sh
```

The script copies the driver files, fixes ownership and permissions, removes the
quarantine flag that makes Gatekeeper block the filter, and checks that CUPS can
see the driver.

### Printer connected by USB

- Connect the printer
- Open **System Settings** > **Printers & Scanners** > **Add Printer**
- Select the printer and choose **Samsung ML-1640** (or ML-1660) as the driver
- If you get "The printer software was installed incorrectly", click **Repair**
- Print a test page

### Printer shared from another computer (Windows share, Linux CUPS, print server)

Do not add it as a "Generic" or raw printer. A Windows LPD share forwards the bytes
it receives straight to the printer, so the Mac must send QPDL, which means the
Samsung PPD must be attached to the queue on the Mac. Let the script create the
queue for you:

```
sudo ./install.sh --queue Samsung_ML_1640 --uri "lpd://192.0.2.10/Samsung%20ML-1640%20Series"
```

Replace the IP with the host that shares the printer and the share name with the
one configured on that host (spaces become `%20`). Use `--model 1660` for the ML-1660.
Then test:

```
lp -d Samsung_ML_1640 /path/to/file.pdf
```

If you prefer the GUI: **Add Printer** > **IP** tab, Protocol **LPD**, Address = host IP,
Queue = share name, and under **Use** choose **Select Software...** > **Samsung ML-1640**.

If you already added the printer and it never prints, check what driver it has:

```
lpoptions -p <queue name> | tr ' ' '\n' | grep make-and-model
```

If it says `Local Raw Printer` or `Generic`, fix it without deleting the queue:

```
lpadmin -p <queue name> -P "/Library/Printers/PPDs/Contents/Resources/Samsung ML-1640 Series.gz"
```

## Manual install

- copy the ``Samsung`` folder to ``/Library/Printers/``
- copy the ``.gz`` files from ``PPDs/Content/Resources`` to ``/Library/Printers/PPDs/Contents/Resources/``
- fix ownership:

```
sudo chown -R root:wheel /Library/Printers/Samsung
sudo chmod 755 /Library/Printers/Samsung/UPD/Filters/*
sudo chown root:wheel "/Library/Printers/PPDs/Contents/Resources/Samsung ML-1640 Series.gz"
sudo xattr -dr com.apple.quarantine /Library/Printers/Samsung
```

## Troubleshooting

- **"rastertoqpdl cannot be opened because the developer cannot be verified"**:
  open **System Settings** > **Privacy & Security**, scroll to the message about
  rastertoqpdl, click **Allow Anyway**, then print again. Running `install.sh`
  (which removes the quarantine flag) normally avoids this.
- **Verify the driver works without printing**:

```
printf 'hello\n' > /tmp/t.txt
gunzip -c "/Library/Printers/PPDs/Contents/Resources/Samsung ML-1640 Series.gz" > /tmp/ml1640.ppd
cupsfilter -p /tmp/ml1640.ppd -m printer/foo -e /tmp/t.txt > /tmp/out.qpdl
head -c 64 /tmp/out.qpdl | xxd
```

  The output must start with `1b25 2d31 3233 3435 58` (the PJL header).
- **Job disappears but nothing prints**: the queue is probably raw. See the
  network section above.
- **Debug CUPS**: `cupsctl --debug-logging`, print, then read `/var/log/cups/error_log`.

## Credits and origin of the code

This repository is a fork. None of the driver code was written here.

- The filters `rastertoqpdl` and `pstoqpdl` are unmodified arm64 builds of
  [SpliX](https://splix.sourceforge.net/) 2.0.0 by Aurelien Croc, licensed under the
  GNU GPL v2. SpliX source: https://sourceforge.net/projects/splix/
- The PPD files were generated with the CUPS PPD compiler from the SpliX `.drv`
  definitions for the ML-1640 and ML-1660, also GPL v2.
- The icons, `Version.plist` and `autosetupinfo.plist` under `Samsung/` come from
  Samsung's own macOS Universal Print Driver 3.92.00. They are Samsung copyright and
  are included only so the printer gets its proper icon and USB auto setup. Printing
  works without them.
- Original packaging and Ventura instructions by
  [MTz12](https://github.com/MTz12/Samsung-ML-1640-Printer-Ventura-Apple-Silicon),
  ML-1660 support by [molind](https://github.com/molind/Samsung-ML-Printer-Apple-M1).
  Neither parent repository declares a license.
- This fork adds M4 and macOS 27 testing, the network share instructions, and
  `install.sh`.

## License

The SpliX filters and the PPDs are GPL v2, see [LICENSE](LICENSE). The README and
`install.sh` written in this fork are released under the same GPL v2 terms. The
Samsung files listed above remain Samsung's property and are not covered by that
license.
