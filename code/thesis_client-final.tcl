# Global configuration parameters

global opt
set opt(chan)           Channel/Sat
set opt(bw_up)          2Mb
set opt(bw_down)	2Mb
set opt(bw)		100Mb
set opt(delay)		0ms
set opt(phy)            Phy/Sat
set opt(mac)            Mac/Sat
set opt(ifq)            Queue/DropTail
set opt(qlim)           100
set opt(qsize)		100
set opt(ll)             LL/Sat
set opt(wiredRouting)   ON
Class TestSimpleRep

TestSimpleRep instproc init {} {
    $self instvar ns_ ngeo nsg1 nsg2 tcp1 tcp2 f0 f1 f2 tcpvar tcptyp cwndfile seqfile
    set ns_ [new Simulator]
   
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
    

    set cwndfile "$tcptyp cwnd client."
    lappend cwndfile $tcpvar
    set f0 [open $cwndfile w]
    
    set seqfile "$tcptyp seq client."
    lappend seqfile $tcpvar
    set f1 [open $seqfile w]
    
    set out "OUT-$tcptyp-$tcpvar-client"
    set f2 [open $out w]
    
    $ns_ trace-all $f2
}


TestSimpleRep instproc run {} {
	$self instvar ns_ nsc  ngeo nsg1 nsg2 tcp1 tcp2 f0 nf tcpvar tcptyp
	puts "Begin of the Test"

	global opt
#Define node
   
# GEO VINASAT-1 at 132 degrees longitude East
	$ns_ node-config -satNodeType 	geo-repeater \
			-llType		LL/Sat \
			-macType	Mac/Sat \
			-phyType 	Phy/Repeater \
			-channelType 	Channel/Sat \
			-downlinkBW 	2Mb  \
			-wiredRouting 	ON
			
			
	set ngeo [$ns_ node]
	$ngeo set-position 132
	$ns_ node-config -reset
# Two terminals: one in HN and one in HCM 
$ns_ node-config -satNodeType 	terminal \
                -llType 	LL/Sat \
                -ifqType 	Queue/DropTail \
                -ifqLen 	100 \
                -macType 	Mac\Sat \
                -phyType 	Phy\Sat \
                -channelType 	Channel/Sat \
                -downlinkBW 	2Mb \
                -wiredRouting 	ON
	set nsg1 [$ns_ node]
	$nsg1 set-position 21.02 105.50 ; # HaNoi
	set nsg2 [$ns_ node]
	$nsg2 set-position 10.46 106.40; # HoChiMinh
# Add GSLs to geo satellites
	$nsg1 add-gsl geo LL/Sat Queue/DropTail 100 Mac/Sat 2Mb Phy/Sat [$ngeo set downlink_] [$ngeo set uplink_]
	$nsg2 add-gsl geo LL/Sat Queue/DropTail 100 Mac/Sat 2Mb Phy/Sat [$ngeo set downlink_] [$ngeo set uplink_]


#$ns_ node-config -reset
$ns_ unset satNodeType_
$ns_ node-config -llType 	LL \
                -ifqType 	Queue/DropTail \
                -ifqLen 	100 \
                -macType 	Mac/802_3 \
                -phyType 	Phy \
                -channelType 	Channel

set nsc [$ns_ node]
set nds [$ns_ node]
set nsnoop [$ns_ node]
set opt(ll) LL
lappend nodelist $nsg1 
set lan [$ns_ make-lan $nodelist 100Mb 0ms LL Queue/DropTail Mac/802_3 Channel]
    if {$tcptyp == "Snoop"} {
	set opt(ll) LL/LLSnoop
	#set opt(ifq) $opt(ifq)
	$opt(ifq) set limit_ 1000
	set nsnoop [$ns_ node $opt(ll)]
		
   }
    puts $opt(ll)
    $lan addNode [list $nsnoop] 100Mb 0ms $opt(ll) Queue/DropTail Mac/802_3

#Linking nodes
	$ns_ duplex-link $nsc $nsnoop 10Mb 2ms DropTail
	$ns_ queue-limit $nsc $nsnoop $opt(qsize)
	
	$ns_ duplex-link $nsg2 $nds 10Mb 2ms DropTail
	$ns_ queue-limit $nsg2 $nds $opt(qsize)

# Add an error model to the receiving terminal node
	set em1_ [new ErrorModel]
	$em1_ unit pkt 
	$em1_ set rate_ 0.02
	set exprv1 [new RandomVariable/Exponential] 
	$em1_ ranvar $exprv1
	
	set em2_ [new ErrorModel]
	$em2_ unit pkt 
	$em2_ set rate_ 0.02
	set exprv2 [new RandomVariable/Exponential] 
	$em2_ ranvar $exprv2
	
	
	$nsg2 interface-errormodel $em1_
	$nsg1 interface-errormodel $em2_
	

	# Attach agents for FTP
	if {$tcpvar =="Tahoe"} {
  		$self set tcp1 [new Agent/TCP]
  		
  		
	}
	if {$tcpvar != "Tahoe"} {
    		$self set tcp1 [new Agent/TCP/$tcpvar]
    		

	}
	
	$tcp1 set eln_ 1
	$tcp1 set windowInit_ 1

	
	$ns_ attach-agent $nsc $tcp1
	
	$ns_ add-agent-trace $tcp1 tcp
	$ns_ monitor-agent-trace $tcp1
	$tcp1 tracevar cwnd_
	$tcp1 tracevar t_seqno_
	
	set tcpsink1 [new Agent/TCPSink]
	set sack "Sack1"
	if [string match $tcpvar $sack] {
	    puts "sack1"
	    set tcpsink1 [new Agent/TCPSink/Sack1]
	}
	
	$ns_ attach-agent $nds $tcpsink1
	
	set ftp1 [new Application/FTP]
	$ftp1 attach-agent $tcp1

	$ns_ connect $tcp1 $tcpsink1
	
        puts "at 0.0 record"
        $ns_ at 0.0 "$self record"

	puts "at 1.1 $ftp1 start"
	$ns_ at 1.0 "$ftp1 start"

        puts "at 500.0 finish"
        $ns_ at 5000.0 "$self finish"

	set satrouteobject_ [new SatRouteObject]
	$satrouteobject_ compute_routes

        $ns_ run
	puts "Exiting..."
}

TestSimpleRep instproc record {} {
	$self instvar ns_ tcp1 tcp2 f0 f1 f2
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
	$self instvar ns_ f0 f1 f2 cwndfile seqfile
        puts "Finishing.."
        $ns_ flush-trace
        close $f0
        close $f1
        close $f2
      
        exit 0
}

set trep [new TestSimpleRep]

$trep run

