*/2 * * * * ( /home/pi/firewalla/scripts/brofish-ping.sh  >/dev/null 2>&1 )
*/1 * * * * ( /home/pi/firewalla/etc/zeek-mem-check >/dev/null 2>&1 )
*/10 * * * * /home/pi/firewalla/scripts/flow-check.sh >/dev/null 2>&1
