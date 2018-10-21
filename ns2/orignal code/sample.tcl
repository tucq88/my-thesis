# Global configuration parameters

global opt
set opt(chan)           Channel/Sat
set opt(bw_up)          2Mb; # Uplink bandwidth-- becomes downlink bw also
set opt(phy)            Phy/Sat
set opt(mac)            Mac/Sat
set opt(ifq)            Queue/DropTail
set opt(qlim)           50
set opt(ll)             LL/Sat

Class TestSimpleRep

TestSimpleRep instproc init {} {
    $self instvar ns_ n1 n2 n3 tcp1 f0 f1 tcpvar cwndfile seqfile
    set ns_ [new Simulator]
    $ns_ rtproto Dummy

    global argc argv argv0

    switch $argc {
      1 {
	      # at present does nothin expects on arg will fail othewise
              set test $argv
        }
      2 {
              set test [lindex $argv 0]
        }
      default {
              puts "Usage: ns $argv0 <tcp variant>"
	      exit 0
       }
    }
    set tcpvar $test
    puts "opening trace file f0"
    set cwndfile "cwnd."
    lappend cwndfile $tcpvar
    set f0 [open $cwndfile w]
    set seqfile "seq."
    lappend seqfile $tcpvar
    set f1 [open $seqfile w]
}


TestSimpleRep instproc run {} {
	$self instvar ns_ n1 n2 n3 tcp1 f0 tcpvar
	puts "In TestSimpleRep run"

	global opt

	# GEO satellite at 95 degrees longitude West
	$self set n1 [$ns_ satnode-geo-repeater -95 $opt(chan)]

	# Two terminals: one in NY and one in SF 
	$self set n2 [$ns_ satnode-terminal 40.9 -73.9]; # NY
	$self set n3 [$ns_ satnode-terminal 37.8 -122.4]; # SF

	# Add GSLs to geo satellites
	$n2 add-gsl geo $opt(ll) $opt(ifq) $opt(qlim) $opt(mac) $opt(bw_up) \
            $opt(phy) [$n1 set downlink_] [$n1 set uplink_]
	$n3 add-gsl geo $opt(ll) $opt(ifq) $opt(qlim) $opt(mac) $opt(bw_up)  \
	    $opt(phy) [$n1 set downlink_] [$n1 set uplink_]

	# Add an error model to the receiving terminal node
	set em_ [new ErrorModel]
	$em_ unit pkt 
	$em_ set rate_ 0.05
	set exprv [new RandomVariable/Exponential] 
	# $exprv set avg_ 0.05
	$em_ ranvar $exprv
	$n3 interface-errormodel $em_

	# Attach agents for FTP
	$self set tcp1 [new Agent/TCP/$tcpvar]
	$tcp1 set eln_ 1
	$tcp1 set windowInit_ 1
	$ns_ attach-agent $n2 $tcp1
	set tcpsink1 [new Agent/TCPSink]
	set sack "Sack1"
	if [string match $tcpvar $sack] {
	    puts "sack1"
	    set tcpsink1 [new Agent/TCPSink/Sack1]
	}

	$ns_ attach-agent $n3 $tcpsink1

	set ftp1 [new Application/FTP]
	$ftp1 attach-agent $tcp1

	#set cbr1 [new Application/Traffic/CBR]
	#$cbr1 attach-agent $tcp1

	$ns_ connect $tcp1 $tcpsink1

        puts "at 0.0 record"
        $ns_ at 0.0 "$self record"

	#puts "at 1.1 $cbr1 start"
	#$ns_ at 1.0 "$cbr1 start"
	puts "at 1.1 $ftp1 start"
	$ns_ at 1.0 "$ftp1 start"

        puts "at 25.0 finish"
        $ns_ at 25.0 "$self finish"

	set satrouteobject_ [new SatRouteObject]
	$satrouteobject_ compute_routes

        $ns_ run
	puts "exiting testSimpleRep run"
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
xgraph cwnd.\ Sack1 cwnd.\ Reno cwnd.\ Newreno &
xgraph seq.\ Sack1 seq.\ Reno seq.\ Newreno &
