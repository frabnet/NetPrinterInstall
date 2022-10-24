# NetPrinterInstall

Printers can be installed manually or deployed automatically in Active directory environments. This scripts sits in the middle: the installation is manual, but very fast and easy to repeat.

**NOTE:** This script is tested on Windows 10 and Windows 11.

## Why

I was tired to install printers manually in little environments with no Active Directory.

## Setup

1. Download printer driver and copy them in a subfolder of this script folder.

2. Run NetPrinterInstall.cmd and follow instructions to create a configuration file

## Running

1. Once configured, copy all the script folder (including driver folder) to Client PC. Running directly from a file share is also supported.

2. Run NetPrinterInstall.cmd on the and the printer will be automatically installed. Admin rights are required.
