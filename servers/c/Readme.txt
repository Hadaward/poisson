====Updates====================================================================
The Windows/Mac/Linux folders still contain 0.1, compile PSERVER.C in src to
 get 0.2. The 'Tested on' list below is of 0.1.

0.2:
    Added a way to stop server, "/shutdown" in game if using a Blocked Name
        with an allowed IP. (RestrictedNames/RestrictedAllowIP in CONFIG.INI)
    Improved getSetting.
    Improved readSWF.
    Changed setConfig to work with the new getSetting.
    endServer fixed.
        
===============================================================================

====Tested on==================================================================
Windows\16: Borland C++ 4.5 on Windows 3.11
Windows\32: Microsoft Visual C++ 6.0 on Windows 98
Windows\64: Microsoft Visual Studio Professional 2013 set to x64 on Windows 8

Mac\3: Xcode 1.0 on OS X 10.3.9 (iMac G3)
Mac\5: Xcode 3.1.4 on OS X 10.5.8 (PowerMac G5)
Mac\9: Xcode 5.1 on OS X 10.9.2 (MacBook Pro Late 2013)

Linux: gcc 4.7.3 on Xubuntu/Ubuntu 13.04

===============================================================================

====Notes======================================================================
On Windows 3.11 use WINSOCK.LIB. On newer versions, use Ws2_32.lib.

Command to compile on linux: gcc -x c -Wall -Wextra -o server PSERVER.C

===============================================================================


Send bug reports to: room32.tfm@gmail.com