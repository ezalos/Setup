# Plan: Reinstall Windows 11 on /dev/sdc (P3-1TB ~1TB SSD)

## Context
Louis has a broken Windows install on a ~1TB SATA SSD that self-destructed while trying to "fix" a multiboot setup. He's 100% OK losing all data. Goal: clean Windows 11 reinstall from a bootable USB created on Linux.

## Hardware Map
| Device | Size | Model | Role |
|--------|------|-------|------|
| `nvme0n1` | 931G | Seagate BarraCuda Q5 | **Linux root** (DO NOT TOUCH) |
| `nvme1n1` | 3.7T | Predator SSD GM6 | **Linux /home** (DO NOT TOUCH) |
| **`sdc`** | **954G** | **P3-1TB** | **Target: broken Windows → reinstall here** |
| `sdb` | 1.8T | ST2000DM008 | Unknown/NTFS (leave alone) |
| `sda` | 2.7T | ST3000DM007 | NTFS data (leave alone) |
| **`sdd`** | **60G** | **SanDisk Extreme** | **USB stick for installer** (currently mounted at `/media/ezalos/3172-A36A`) |

## Step 1: Download Windows 11 ISO

Download the official Windows 11 ISO from Microsoft. Their site serves the ISO directly if we fake a non-Windows User-Agent:

```bash
# Use browser: https://www.microsoft.com/software-download/windows11
# Or use the Fido script which automates the direct download
```

Alternatively, use `fido` (a shell script that fetches official Microsoft ISOs):
```bash
# Download fido
wget https://raw.githubusercontent.com/pbatard/Fido/master/Fido.sh
chmod +x Fido.sh
# Run it to get the download link
./Fido.sh
```

The ISO will be ~6GB.

## Step 2: Create Bootable USB with Ventoy

**Why Ventoy:** It's the simplest method from Linux. You install Ventoy on the USB once, then just copy ISO files onto it. It handles UEFI boot, large ISOs, and the >4GB `install.wim` problem automatically.

```bash
# 1. Download latest Ventoy
wget https://github.com/ventoy/Ventoy/releases/download/v1.1.05/ventoy-1.1.05-linux.tar.gz
tar xzf ventoy-1.1.05-linux.tar.gz
cd ventoy-1.1.05

# 2. Unmount USB first
sudo umount /dev/sdd1

# 3. Install Ventoy on the USB (THIS WIPES THE USB)
sudo ./Ventoy2Disk.sh -i /dev/sdd

# 4. Mount the Ventoy data partition and copy the ISO
# (Ventoy creates a large exFAT partition automatically)
# Mount it, then:
cp ~/Downloads/Win11_*.iso /media/ezalos/<ventoy-partition>/
```

**Alternative if Ventoy fails:** Manual method with split WIM using `wimlib-imagex` (more complex, would need to install `wimtools` package).

## Step 3: Boot from USB & Install Windows

1. **Reboot** the machine
2. **Enter UEFI boot menu** (usually F12, F2, or Del during POST — depends on motherboard)
3. **Select the SanDisk USB** as boot device (pick the UEFI entry if available)
4. In Windows Setup:
   - Language/keyboard → Next
   - "Install now"
   - "I don't have a product key" → skip
   - Choose Windows 11 Home or Pro
   - **"Custom: Install Windows only (advanced)"**
   - **CRITICAL: Identify the right disk!** Look for the ~954GB / ~1TB drive. It should show ~3 partitions totaling ~954GB
   - **Delete ALL partitions** on that drive (and only that drive!)
   - Select the resulting "Unallocated Space" on the 954GB drive
   - Click Next → Windows installs

## Step 4: Post-Install — Fix Linux Boot (if needed)

Windows might overwrite the UEFI boot order so Linux/GRUB no longer appears. To fix:

**Option A: UEFI boot menu still shows Linux**
- Just use BIOS boot menu (F12) to select Linux, then:
```bash
sudo update-grub
```

**Option B: GRUB is gone from UEFI**
- Boot from a Linux live USB (or the existing Linux install if accessible)
```bash
sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi
sudo update-grub
```

**Option C: Use `efibootmgr`** to restore the Linux boot entry if the EFI partition is intact (it should be — it's on `nvme0n1p1`, not on the Windows SSD).

Since Linux's EFI partition is on a **separate NVMe drive** (`nvme0n1p1`), Windows likely won't touch it. The UEFI boot order might just need to be changed back.

## Verification
- [ ] Windows 11 boots from `/dev/sdc`
- [ ] Linux boots from GRUB on `nvme0n1` (fix with `update-grub` if needed)
- [ ] Both OSes accessible via UEFI boot menu or GRUB
