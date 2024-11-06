# GPTar

You know GUID Partition Tables. You *love* [the tape archive format][tar].
Now you can have **both**!

With GPTar you can now create a GPT-formatted disk image which is also a valid tar archive!
Put a partition right after the GPT partition table and you can store your real tar archive data there.
Create more partitions to store elsewhere on the disk for Full Performance™.

```
$ fdisk -l disk.img
Disk disk.img: 512 KiB, 524288 bytes, 1024 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: 54A6B56C-9BBA-4AC9-A8B5-B25EA2F4057C

Device     Start End Sectors Size Type
disk.img1     34  37       4   2K unknown
```

Are you somehow unable to mount the disk, but still curious what files are in the tar archive?
Well, no fret!
Use standard tar utilities to inspect or extract the contents:
```
$ tar -tvf disk.img # GNU tar
Vr-------- 0/0           16896 1970-01-01 01:00 GPTAR--Volume Header--
-rw-r--r-- 0/0              14 1970-01-01 01:00 test.txt
$ bsdtar -tvf disk.img # version >= 3.7.5
-rw-r--r--  0 0      0          14 Jan  1  1970 test.txt
```

## How does this black magic work!?

A GPT formatted disk starts with a so-called "protective" MBR.
Thankfully, tar headers only use the first few hundreds of bytes which would end up in the MBR bootstrap code if merged into a MBR.
So the protective MBR is modified to have as bootstrap code a dummy tar header for a GNU volume header `GPTAR` whose length covers the rest of the first LBA (if block size is greater than 512 bytes), the GPT table header and the partition table entries.
A GNU volume header is not extractable, and in some tar implementations they are silently ignored.
The remaining space can be used as a tar archive.

## Why though?!

We at [Robur][robur] implemented an [opam mirror][opam-mirror] that uses the disk *mainly* as a tar archive, but some data is cached at the end of the disk using [mirage-block-partition][mirage-block-partition].
This works fine, and we can list the contents of the tar archive on disk using traditional tar utilities.
However, a problem is the disk partitioning information is not stored on the disk and must be passed on the commandline.
This could lead to data corruption if the wrong offsets are used.
Using a table such as GPT or MBR would work, but then we lose the ability to inspect the tar archive.
This ungodly hack is a compromise giving us an on-disk partition table while preserving the ability to inspect the archive - at the cost of the `GPTAR` dummy file (and my soul, allegedly).

[tar]: https://en.wikipedia.org/wiki/Tar_(computing)
[robur]: https://robur.coop/
[opam-mirror]: https://git.robur.coop/robur/opam-mirror
[mirage-block-partition]: https://github.com/reynir/mirage-block-partition
