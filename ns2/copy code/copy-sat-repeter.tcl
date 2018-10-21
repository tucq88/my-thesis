#
# Contributed by Tom Henderson, UCB Daedalus Research Group, June 1999
#
# $Header: /local/cvsroot/ns_-2.33/tcl/ex/sat-repeater.tcl,v 1.1.1.1 2008/06/18 09:33:19 hc07r Exp $
#
# Simple script with a geostationary satellite and two terminals
# and an error module on the receiving terminal.  The traffic cons_ists of
# a FTP source and a CBR stream  
# 

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

Class TestSimpleRep

TestSimpleRep instproc init {} {
    $self instvar ns_ ngeo nsg1 nsg2 tcp1 f0 f1 tcpvar cwndfile seqfile
    set ns_ [new Simulator]
    global argc argv argv0
    switch $argc {
      1 {
              set test $argv
              set test1 "E2E"
        }
      2 {
              set test [lindex $argv 0]
              set test1 [lindex $argv 1]
              if {($test1 != "Snoop")} {
              	puts "Error!"
              	exit 0
              	}
        }
      default {
              puts "Usage: ns_ $argv0 <tcp variant><tcp type>"
	      exit 0
       }
    }
    
    set tcpvar $test
    set tcptyp $test1
    

    set cwndfile "SAT $tcptyp cwnd."
    lappend cwndfile $tcpvar
    set f0 [open $cwndfile w]
    
    set seqfile "SAT $tcptyp seq."
    lappend seqfile $tcpvar
    set f1 [open $seqfile w]
}
TestSimpleRep instproc run {} {
	$self instvar ns_ nsc ngeo nsg1 nsg2 nds tcp1 f0 nf tcpvar tcptyp
	set nsc [$ns_ node]
	set nds [$ns_ node]
	set nsnoop [$ns_ node]
	set opt(chan)           Channel/Sat
	set opt(bw_up)		2Mb
	set opt(bw_down)	2Mb
	set opt(phy)            Phy/Sat
	set opt(mac)            Mac/Sat
	set opt(ifq)            Queue/DropTail
	set opt(qlim)		50
	set opt(ll)             LL/Sat
	set opt(wiredRouting)   ON

	$ns_ node-config -satNodeType geo-repeater \
			-phyType Phy/Repeater \
			-channelType $opt(chan) \
			-downlinkBW $opt(bw_down)  \
			-wiredRouting $opt(wiredRouting)

# GEO satellite at 95 degrees longitude West
set ngeo [$ns_ node]
$ngeo set-position -95

# Configure the node generator for satellite terminals
$ns_ node-config -satNodeType terminal \
                -llType $opt(ll) \
                -ifqType $opt(ifq) \
                -ifqLen $opt(qlim) \
                -macType $opt(mac) \
                -phyType $opt(phy) \
                -channelType $opt(chan) \
                -downlinkBW $opt(bw_down) \
                -wiredRouting $opt(wiredRouting)

# Two terminals: one in NY and one in SF

set nsg1 [$ns_ node]
$nsg1 set-position 40.9 -73.9; # NY
set nsg2 [$ns_ node]
$nsg2 set-position 37.8 -122.4; # SF

# Add GSLs to geo satellites
$nsg1 add-gsl geo $opt(ll) $opt(ifq) $opt(qlim) $opt(mac) $opt(bw_up) \
    $opt(phy) [$ngeo set downlink_] [$ngeo set uplink_]
$nsg2 add-gsl geo $opt(ll) $opt(ifq) $opt(qlim) $opt(mac) $opt(bw_up) \
    $opt(phy) [$ngeo set downlink_] [$ngeo set uplink_]
    
#Two end nodes
#set nsc [$ns node]
#set nds [$ns node]
#set nsnoop [$ns node]
#Linking nodes
	$ns_ duplex-link $nsc $nsnoop 10Mb 2ms DropTail
	$ns_ duplex-link $nsnoop $nsg1 10Mb 2ms DropTail
	$ns_ duplex-link $nds $nsg2 10Mb 2ms DropTail
	
# Add an error model to the receiving terminal node
set em_ [new ErrorModel]
$em_ unit pkt
$em_ set rate_ 0.02
$em_ ranvar [new RandomVariable/Uniform]
$nsg2 interface-errormodel $em_ 

# Attach agents for FTP traffic generator

# tcp1 => nsc
$self set tcp1 [new Agent/TCP/$tcpvar]
$tcp1 set eln_ 1
$tcp1 set windowInit_ 1
$ns_ attach-agent $nsc $tcp1
# ftp1 => tcp1
set ftp1 [new Application/FTP]
$ftp1 attach-agent $tcp1

# tcpsink => nds 
set tcpsink1 [new Agent/TCPSink]
set sack "Sack1"
if [string match $tcpvar $sack] {
    puts "sack1"
    set tcpsink1 [new Agent/TCPSink/Sack1]
}
$ns_ attach-agent $nds $tcpsink1

# tcp1 <=> tcpsink1
$ns_ connect $tcp1 $tcpsink1

# Attach agents for FTP  
#set tcp2 [$ns_ create-connection TCP $n2 TCPSink $n3 0]
#set ftp2 [$tcp2 attach-app FTP]

# We use centralized routing
set satrouteobject_ [new SatRouteObject]
$satrouteobject_ compute_routes

        puts "at 0.0 record"
        $ns_ at 0.0 "$self record"

	puts "at 1.1 $ftp1 start"
	$ns_ at 1.0 "$ftp1 start"

        puts "at 100.0 finish"
        $ns_ at 100.0 "$self finish"
}

TestSimpleRep instproc record {} {
	$self instvar ns_ tcp1 f0 f1
        #Set the time after which the procedure should be called again
        set time 0.5
        # current cwnd
        set bw0 [$tcp1 set cwnd_]
	set bw1 [$tcp1 set t_seqno_]
        #Get the current time
        set now [$ns_ now]

        # puts "$now $bw0"
        puts $f0 "$now $bw0"
        puts $f1 "$now $bw1"
        #Re-schedule the procedure
        $ns_ at [expr $now+$time] "$self record"
}

TestSimpleRep instproc finish {} {
	$self instvar ns_ f0 cwndfile seqfile
        puts "Finishing.."
        $ns_ flush-trace
        close $f0
        # close $nf

        # puts "running nam..."
        # exec nam out.nam &
        # exec xgraph $cwndfile &
        # exec xgraph $seqfile &
        exit 0
}

set trep [new TestSimpleRep]

$trep run
#puts "after runtest"


