This is a powershell script for catalog search PC.
The script start the kiosk mode chrome browser and cleans up after patron usage.
Script starts when PC starts.
It opens a kiosk mode browser with menu.
Then it loops every 5 seconds and check
 - if there is no browser opened, it opens kiosk mode browser with menu.
 - if patron used this PC and PC has been idled for 3 minute, it closes all browser and open kiosk mode browser with menu.
