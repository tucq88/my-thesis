#
# Contributed by Tom Henderson, November 2001 
#
# Extension of the sat-mixed.tcl script to support integration of
# non-satellite nodes (wired and satellite nodes).  See the documentation
# for usage instructions.  
# 
# $Header: /local/cvsroot/ns-2.33/tcl/ex/sat-wired.tcl,v 1.1.1.1 2008/06/18 09:33:19 hc07r Exp $

global ns
set ns [new Simulator]
# Note:  Even though "Static" is normally reserved for static
#        topologies, the satellite code will trigger a recalculation
#        of the routing tables whenever the topology changes.
#	 Therefore, it is not so much "static" as "omniscient", in that
#        topology changes are known instantly throughout the topology.
#        See documentation for discussion of dynamic routing protocols.
$ns rtproto Static

###########################################################################
# Global configuration parameters                                         #
###########################################################################

HandoffManager/Term set elevation_mask_ 8.2
HandoffManager/Term set term_handoff_int_ 10
HandoffManager set handoff_randomization_ false

global opt
set opt(chan)           Channel/Sat
set opt(bw_down)	1.5Mb; # Downlink bandwidth (satellite to ground)
set opt(bw_up)		1.5Mb; # Uplink bandwidth
set opt(bw_isl)		25Mb
set opt(phy)            Phy/Sat
set opt(mac)            Mac/Sat
set opt(ifq)            Queue/DropTail
set opt(qlim)		50
set opt(ll)             LL/Sat
set opt(wiredRouting)	ON

set opt(alt)		780; # Polar satellite altitude (Iridium)
set opt(inc)		90; # Orbit inclination w.r.t. equator

# IMPORTANT This tracing enabling (trace-all) must precede link and node 
#           creation.  Then following all node, link, and error model
#           creation, invoke "$ns trace-all-satlinks $outfile" 
set outfile [open out.tr w]
$ns trace-all $outfile

###########################################################################
# Set up satellite and terrestrial nodes                                  #
###########################################################################

# Let's first create a single orbital plane of Iridium-like satellites
# 11 satellites in a plane

# Set up the node configuration

$ns node-config -satNodeType polar \
		-llType $opt(ll) \
		-ifqType $opt(ifq) \
		-ifqLen $opt(qlim) \
		-macType $opt(mac) \
		-phyType $opt(phy) \
		-channelType $opt(chan) \
		-downlinkBW $opt(bw_down) \
		-wiredRouting $opt(wiredRouting)

# GEO satellite:  above North America-- lets put it at 100 deg. W
$ns node-config -satNodeType geo
set n11 [$ns node]
$n11 set-position -100

# Terminals:  Let's put two within the US, two around the prime meridian
$ns node-config -satNodeType terminal 
set n100 [$ns node]; set n101 [$ns node]
$n100 set-position 37.9 -122.3; # Berkeley
$n101 set-position 42.3 -71.1; # Boston

###########################################################################
# Set up links                                                            
###########################################################################

# Add any necessary ISLs or GSLs
# GSLs to the geo satellite:
$n100 add-gsl geo $opt(ll) $opt(ifq) $opt(qlim) $opt(mac) $opt(bw_up) \
  $opt(phy) [$n11 set downlink_] [$n11 set uplink_]
$n101 add-gsl geo $opt(ll) $opt(ifq) $opt(qlim) $opt(mac) $opt(bw_up) \
  $opt(phy) [$n11 set downlink_] [$n11 set uplink_]

###########################################################################
# Set up wired nodes                                                      
###########################################################################
# Connect $n300 <-> $n301 <-> $n100 <-> $n11 <-> $n101 <-> $n303
# 
# Packets from n303 to n300 should bypass n302 (node #18 in the trace)
# (i.e., these packets should take the following path:  19,13,11,12,17,16)
#
$ns unset satNodeType_
set n300 [$ns node]; # node 16 in trace
set n301 [$ns node]; # node 17 in trace
set n302 [$ns node]; # node 18 in trace
set n303 [$ns node]; # node 19 in trace
$ns duplex-link $n300 $n301 5Mb 2ms DropTail; # 16 <-> 17
$ns duplex-link $n303 $n101 5Mb 2ms DropTail; # 19 <-> 13
$ns duplex-link $n301 $n100 5Mb 2ms DropTail; # 17 <-> 11

###########################################################################
# Tracing                                                                 #
###########################################################################
$ns trace-all-satlinks $outfile
###########################################################################
# Attach agents                                                           #
###########################################################################

set udp0 [new Agent/UDP]
$ns attach-agent $n100 $udp0
set cbr0 [new Application/Traffic/CBR]
$cbr0 attach-agent $udp0
$cbr0 set interval_ 60.01

set udp1 [new Agent/UDP]
$ns attach-agent $n200 $udp1
$udp1 set class_ 1
set cbr1 [new Application/Traffic/CBR]
$cbr1 attach-agent $udp1
$cbr1 set interval_ 90.5

set null0 [new Agent/Null]
$ns attach-agent $n101 $null0
set null1 [new Agent/Null]
$ns attach-agent $n201 $null1

$ns connect $udp0 $null0
$ns connect $udp1 $null1

###########################################################################
# Set up connection between wired nodes                                   #
###########################################################################
set udp2 [new Agent/UDP]
$ns attach-agent $n303 $udp2
set cbr2 [new Application/Traffic/CBR]
$cbr2 attach-agent $udp2
$cbr2 set interval_ 300
set null2 [new Agent/Null]
$ns attach-agent $n300 $null2

$ns connect $udp2 $null2
$ns at 10.0 "$cbr2 start"

###########################################################################
# Satellite routing                                                       #
###########################################################################

set satrouteobject_ [new SatRouteObject]
$satrouteobject_ compute_routes
#$satrouteobject_ set wiredRouting_ true

$ns at 1.0 "$cbr0 start"
$ns at 305.0 "$cbr1 start"
#$ns at 0.9 "$cbr1 start"

$ns at 9000.0 "finish"

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

