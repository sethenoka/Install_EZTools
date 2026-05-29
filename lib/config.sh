# Defaults track Eric Zimmerman's current net9 Linux download layout.
DOTNET_CHANNEL="9.0"
DOTNET_KIND="runtime"
INSTALL_ROOT="/opt/zimmermantools/net9"
PROFILE_FILE="${HOME}/.bashrc"
UPDATE_PROFILE=true
ASSUME_YES=false
DRY_RUN=false
FORCE=false
VERBOSE=false
ALLOW_ROOT=false
VERIFY_DOTNET_SIGNATURE=true
SELECTED_TOOLS="all"
WRAPPER_DIR="/usr/local/bin"
DOTNET_INSTALL_ROOT="${HOME}/.dotnet"
DOTNET_ROOT="${DOTNET_INSTALL_ROOT}"
DOTNET_BIN="${DOTNET_INSTALL_ROOT}/dotnet"
TMP_DIR=""

# Tool manifest schema:
# key|display name|zip URL|extract destination under INSTALL_ROOT|DLL path under destination|optional sha256
TOOL_MANIFEST=(
  "amcacheparser|AmcacheParser|https://download.ericzimmermanstools.com/net9/AmcacheParser.zip|AmcacheParser|AmcacheParser.dll|"
  "appcompatcacheparser|AppCompatCacheParser|https://download.ericzimmermanstools.com/net9/AppCompatCacheParser.zip|AppCompatCacheParser|AppCompatCacheParser.dll|"
  "bstrings|bstrings|https://download.ericzimmermanstools.com/net9/bstrings.zip|bstrings|bstrings.dll|"
  "evtxecmd|EvtxECmd|https://download.ericzimmermanstools.com/net9/EvtxECmd.zip|.|EvtxeCmd/EvtxECmd.dll|"
  "iisgeolocate|iisGeolocate|https://download.ericzimmermanstools.com/net9/iisGeolocate.zip|.|iisGeolocate/iisGeolocate.dll|"
  "jlecmd|JLECmd|https://download.ericzimmermanstools.com/net9/JLECmd.zip|JLECmd|JLECmd.dll|"
  "lecmd|LECmd|https://download.ericzimmermanstools.com/net9/LECmd.zip|LECmd|LECmd.dll|"
  "mftecmd|MFTECmd|https://download.ericzimmermanstools.com/net9/MFTECmd.zip|MFTEcmd|MFTECmd.dll|"
  "pecmd|PECmd|https://download.ericzimmermanstools.com/net9/PECmd.zip|PECmd|PECmd.dll|"
  "rbcmd|RBCmd|https://download.ericzimmermanstools.com/net9/RBCmd.zip|RBCmd|RBCmd.dll|"
  "recentfilecacheparser|RecentFileCacheParser|https://download.ericzimmermanstools.com/net9/RecentFileCacheParser.zip|RecentFileCacheParser|RecentFileCacheParser.dll|"
  "recmd|RECmd|https://download.ericzimmermanstools.com/net9/RECmd.zip|.|RECmd/RECmd.dll|"
  "rla|RLA|https://download.ericzimmermanstools.com/net9/rla.zip|rla|rla.dll|"
  "sbecmd|SBECmd|https://download.ericzimmermanstools.com/net9/SBECmd.zip|SBECmd|SBECmd.dll|"
  "sqlecmd|SQLECmd|https://download.ericzimmermanstools.com/net9/SQLECmd.zip|.|SQLECmd/SQLECmd.dll|"
  "srumecmd|SrumECmd|https://download.ericzimmermanstools.com/net9/SrumECmd.zip|SrumECmd|SrumECmd.dll|"
  "sumecmd|SumECmd|https://download.ericzimmermanstools.com/net9/SumECmd.zip|SumECmd|SumECmd.dll|"
  "vscmount|VSCMount|https://download.ericzimmermanstools.com/net9/VSCMount.zip|VSCMount|VSCMount.dll|"
  "wxtcmd|WxTCmd|https://download.ericzimmermanstools.com/net9/WxTCmd.zip|WxTCmd|WxTCmd.dll|"
)
