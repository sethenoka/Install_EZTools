# Install_EZTools
Bash script to install EZ Tools on Linux with .NET9

This script will install necessary pre-requisites, followed by MS .NET9, then select EZ Tools (MFTECmd, PECmd, RECmd, and EvtxECmd by default).

To add or remove tools from the list, edit the calls to the **download_and_unzip** function. The function takes a URL to the relevant .zip and a destination directory into which the archive will be expanded.

If you want aliases for the tools to make them easier to run from the cmdline, don't forget to add aliases to the end of the script following the sample format available in the script.
