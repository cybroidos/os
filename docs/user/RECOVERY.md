# When something goes wrong

## The computer won't start the desktop

Hold **Shift** (or press **Esc**) while it starts to show the boot menu, then
choose **Advanced options** and the recovery mode. From there you can repair
packages (`dpkg --configure -a`, `apt -f install`) or drop to a root shell.

## A forgotten password

Start in recovery mode, choose the root shell and run `passwd <your account>`.
With disk encryption you need the encryption passphrase.

## Black screen after an update

Choose the previous kernel under **Advanced options** in the boot menu, or add
`nomodeset` to the kernel line (press **e** on the entry) to start with basic
graphics, then update again.

## Starting over

Install again from the latest ISO. Back up your home folder first; the
installer can keep other partitions if you choose **Manual partitioning**.
