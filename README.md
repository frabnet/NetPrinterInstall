# NetPrinterInstall

Printers can be installed manually (in little offices) or deployed by GPO in Active directory environments. This scripts sits in the middle: the installation is manual, but very fast and easy to repeat.

**NOTE:** This script is tested on PowerShell 4 or greater. You can download v4 from [Microsoft website](https://www.microsoft.com/en-us/download/details.aspx?id=40855).

## Why

I was tired to install printers manually in little environments with no Active Directory.

## Preparation

#### 1.  Download printer driver

- Download the "inf driver" for your printer. Usually it's smaller than others and it's named *no installer*, *Add Printer Wizard Driver*, or similar. 
- Extract the driver in a subfolder of the script folder.

#### 2. Discover driver_inf and driver_name

- Run **list_driver.cmd**
- Observe the output and search for the line with your exact printer model, example:
  `HP_LJ_Pro_M501_PCL-6_Win8_Plus_Print_Driver_no_Installer_19227\hpbi652A4_x64.inf:155:PRINTER1 = "HP LaserJet Pro M501
  PCL-6"`
- The first part is the driver_inf (*HP_LJ_Pro_M501_PCL-6_Win8_Plus_Print_Driver_no_Installer_19227\hpbi652A4_x64.inf*)
- The second part is the driver_name (*HP LaserJet Pro M501
  PCL-6*).
- These values needs to be copied in run_config.ini (see below)

#### 3. Configuration

Edit  **run_config.ini**:

- `remove_printer=`  If you need to remove a printer before installing the new one, write part of the printer name here. It's a wild-card value. Example: with *OfficeJet* you will remove any OfficeJet printer. Leave empty if not needed.
- `remove_port=` Same as above but for ports, example: *192.168.1.210*. Empty if not needed.
- `address=` IP Address for the new printer.
- `driver_inf=` Relative path to .inf file
- `driver_name=` Driver name / Model of the printer
- `printer_name=` Self explanatory
- `set_default=` 1 to set as default printer, empty if not needed.

## Running

Just run: **run.cmd** 

Since administrative rights are required, the UAC prompt may appear.

Old/stuck print jobs will be deleted automatically.

Every action (except for clearing print jobs) will need a confirmation (y/n).
