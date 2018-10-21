#
# Contributed by Tom Henderson, UCB Daedalus Research Group, June 1999
#
# $Header: /local/cvsroot/ns-2.33/tcl/ex/sat-repeater.tcl,v 1.1.1.1 2008/06/18 09:33:19 hc07r Exp $
#
# Simple script with a geostationary satellite and two terminals
# and an error module on the receiving terminal.  The traffic consists of
# a FTP source and a CBR stream  
# 

global ns
set ns [new Simulator]

# Global configuration parameters
# We'll set these global options for the satellite terminals

global opt
set opt(chan)           Channel/Sat
set opt(bw_up)		2Mb
set opt(bw_down)	2Mb
set opt(phy)            Phy/Sat
set opt(mac)            Mac/Sat
set opt(ifq)            Queue/DropTail
set opt(qlim)		50
set opt(ll)             LL/Sat
set opt(wiredRouting)   ON

# XXX This tracing enabling must precede link and node creation 
set outfile [open out.tr w]
$ns trace-all $outfile

# Set up satellite and terrestrial nodes

# Configure the node generator for bent-pipe satellite
# geo-repeater uses type Phy/Repeater
$ns node-config -satNodeType geo-repeater \
		-phyType Phy/Repeater \
		-channelType $opt(chan) \
		-downlinkBW $opt(bw_down)  \
		-wiredRouting $opt(wiredRouting)

# GEO satellite at 95 degrees longitude West
set n1 [$ns node]
$n1 set-position -95

# Configure the node generator for satellite terminals
$ns node-config -satNodeType terminal \
                -llType $opt(ll) \
                -ifqType $opt(ifq) \
                -ifqLen $opt(qlim) \
                -macType $opt(mac) \
                -phyType $opt(phy) \
                -channelType $opt(chan) \
                -downlinkBW $opt(bw_down) \
                -wiredRouting $opt(wiredRouting)

# Two terminals: one in NY and one in SF 
set n2 [$ns node]
$n2 set-position 40.9 -73.9; # NY
set n3 [$ns node]
$n3 set-position 37.8 -122.4; # SF

# Add GSLs to geo satellites
$n2 add-gsl geo $opt(ll) $opt(ifq) $opt(qlim) $opt(mac) $opt(bw_up) \
    $opt(phy) [$n1 set downlink_] [$n1 set uplink_]
$n3 add-gsl geo $opt(ll) $opt(ifq) $opt(qlim) $opt(mac) $opt(bw_up) \
    $opt(phy) [$n1 set downlink_] [$n1 set uplink_]
#Two end nodes
$ns node-config -reset
set nsc [$ns node]
set nds [$ns node]
set nsnoop [$ns node]
#Linking nodes
	$ns duplex-link $nsc $nsnoop 10Mb 2ms DropTail
	$ns duplex-link $nsnoop $n2 10Mb 2ms DropTail
	$ns duplex-link $n3 $nds 10Mb 2ms DropTail

# Add an error model to the receiving terminal node
set em_ [new ErrorModel]
$em_ unit pkt
$em_ set rate_ 0.02
$em_ ranvar [new RandomVariable/Uniform]
$n3 interface-errormodel $em_ 

$ns trace-all-satlinks $outfile

# Attach agents for CBR traffic generator 
set tcp1 [new Agent/TCP]
$ns attach-agent $nsc $tcp1
set ftp1 [new Application/FTP]
$ftp1 attach-agent $tcp1
set tcpsink1 [new Agent/TCPSink]
$ns attach-agent $nds $tcpsink1
$ns connect $tcp1 $tcpsink1

# Attach agents for FTP  
set tcp1 [$ns create-connection TCP $n2 TCPSink $n3 0]
set ftp1 [$tcp1 attach-app FTP]
$ns at 7.0 "$ftp1 produce 100"

# We use centralized routing
set satrouteobject_ [new SatRouteObject]
$satrouteobject_ compute_routes

$ns at 1.0 "$ftp1 start"
$ns at 50.0 "finish"

proc finish {} {
	global ns outfile
	$ns flush-trace
	close $outfile

	exit 0
}

$ns run



maintained by Jos Akhtman
	ViewVC Help
Powered by ViewVC 1.0.3 	 

