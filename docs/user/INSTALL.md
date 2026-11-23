# Installing CybroidOS

## What you need

- A 64-bit Intel or AMD computer with 2 GB of memory (4 GB recommended) and
  at least 15 GB of disk.
- A USB stick of 8 GB or more.

## Steps

1. Download the ISO and its checksum, and check it:
   `sha256sum -c cybroidos-desktop-amd64.iso.sha256`.
2. Write it to the USB stick with a tool such as balenaEtcher, Rufus (DD mode)
   or `dd`. Everything on the stick is erased.
3. Start the computer from the stick (often F12, F9 or Esc at power-on chooses
   the boot device).
4. Choose **Try or install CybroidOS**. The desktop starts from the stick;
   nothing on the computer changes yet. On a slow stick, **Try CybroidOS from
   memory** runs smoother.
5. Open **Install CybroidOS** in the dock and follow the steps: language,
   time zone, keyboard, disk, and your account. To keep Windows, choose
   **Install alongside** on the disk page.
6. Restart and remove the stick when asked.

If the screen stays black, start again and choose **Try CybroidOS with safe
graphics**.
