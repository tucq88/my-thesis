# Global configuration parameters

global opt
set opt(chan)           Channel/Sat
set opt(bw_up)          100Mb; # Uplink bandwidth-- becomes downlink bw also
set opt(bw)		1000Mb
set opt(delay)		0ms
set opt(phy)            Phy/Sat
set opt(mac)            Mac/Sat
set opt(ifq)            Queue/DropTail
set opt(qlim)           100
set opt(qsize)		100
set opt(ll)             LL/Sat

Class TestSimpleRep

TestSimpleRep instproc init {} {
    $self instvar ns_ ngeo nsg1 nsg2 tcp1 f0 f1 tcpvar cwndfile seqfile
    set ns_ [new Simulator]
    $ns_ rtproto Dummy

    global argc argv argv0

    switch $argc {
      1 {
	      # at present does nothin expects on arg will fail othewise
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
              puts "Usage: ns $argv0 <tcp variant><tcp type>"
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
	$self instvar ns_ nsc  ngeo nsg1 nsg2 tcp1 f0 nf tcpvar tcptyp
	puts "Begin of the Test"

	global opt
#Define node
    set nsc [$ns_ node]
    set nds [$ns_ node]
 
    
# GEO VINASAT-1 at 132 degrees longitude West
	$self set ngeo [$ns_ satnode-geo-repeater 132 $opt(chan)]
# Two terminals: one in NY and one in SF 
	$self set nsg1 [$ns_ satnode-terminal 21.02 105.50]; # Hanoi
	$self set nsg2 [$ns_ satnode-terminal 10.46 106.40]; # HoChiMinh
# Add GSLs to geo satellites
	$nsg1 add-gsl geo $opt(ll) $opt(ifq) $opt(qlim) $opt(mac) $opt(bw_up) $opt(phy) [$ngeo set downlink_] [$ngeo set uplink_]
	$nsg2 add-gsl geo $opt(ll) $opt(ifq) $opt(qlim) $opt(mac) $opt(bw_up) $opt(phy) [$ngeo set downlink_] [$ngeo set uplink_]


#Linking nodes
	$ns_ duplex-link $nsc $nsg1 10Mb 2ms DropTail
	$ns_ duplex-link-op $nsc $nsg1 orient right
	$ns_ queue-limit $nsc $nsg1 $opt(qsize)

	$ns_ duplex-link $nsg2 $nds 10Mb 2ms DropTail
	$ns_ duplex-link-op $nsg2 $nds orient right
	$ns_ queue-limit $nsg2 $nds $opt(qsize)

# Add an error model to the receiving terminal node
	set em_ [new ErrorModel]
	$em_ unit pkt 
	$em_ set rate_ 0.02
	set exprv [new RandomVariable/Exponential] 
	# $exprv set avg_ 0.02
	$em_ ranvar $exprv
	$nsg2 interface-errormodel $em_
	

	# Attach agents for FTP
	$self set tcp1 [new Agent/TCP/$tcpvar]
	$tcp1 set eln_ 1
	$tcp1 set windowInit_ 1
	$ns_ attach-agent $nsg1 $tcp1
	set tcpsink1 [new Agent/TCPSink]
	set sack "Sack1"
	if [string match $tcpvar $sack] {
	    puts "sack1"
	    set tcpsink1 [new Agent/TCPSink/Sack1]
	}

	$ns_ attach-agent $nsg2 $tcpsink1

	set ftp1 [new Application/FTP]
	$ftp1 attach-agent $tcp1

	$ns_ connect $tcp1 $tcpsink1

        puts "at 0.0 record"
        $ns_ at 0.0 "$self record"

	puts "at 1.1 $ftp1 start"
	$ns_ at 1.0 "$ftp1 start"

        puts "at 100.0 finish"
        $ns_ at 100.0 "$self finish"

	set satrouteobject_ [new SatRouteObject]
	$satrouteobject_ compute_routes

        $ns_ run
	puts "Exiting..."
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
puts "after runtest"


ns test-bp.tcl Reno
ns test-bp.tcl Sack1
ns test-bp.tcl Newreno
