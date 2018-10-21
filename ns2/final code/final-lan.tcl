#Chu Quang Tu
#TTM k51 - Vien CNTT & TT - DHBK HN
#
#
#Topo thu nghiem End to End
#
#FTP
#TCP/tcpvar         LL                                                         TCPSink
#(nsc) -----------(repeter--nsg1) ----------(ngeo) ----------(nsg2) ----------- (nds)
#       10Mb, 2ms      100Mb       2Mb, 250ms      2Mb, 250ms        10Mb,2ms
#                      0ms        <-> lost 0.02   <->lost 0.02
#
# 
#
#
#Topo thu nghiem Snoop
#
#FTP
#TCP/tcpvar         LL/LLSink                                                 TCPSink
#(nsc) -----------(snoop--nsg1) ----------(ngeo) ----------(nsg2) ----------- (nds)
#       10Mb, 2ms    100Mb       2Mb, 250ms      2Mb, 250ms        10Mb,2ms
#                    0ms        <-> lost 0.02   <->lost 0.02
#
#

global opt
set opt(qsize)        100
set opt(bw)           1000Mb
set opt(delay)        0ms
set opt(ll)           LL
set opt(ifq)          Queue/DropTail
set opt(mac)          Mac/802_3
set opt(chan)         Channel

Class TestSimpleRep
TestSimpleRep instproc init {} {
    $self instvar ns_ nsc nsg1 ngeo nsg2 nds tcp1 f0 f1 f2 nf tcpvar tcptyp cwndfile seqfile
    set ns_ [new Simulator]
    # $ns_rtproto Dummy
    
    global argc argv argv0
    switch $argc {
	1 {
	# at present does nothin expects on arg will fail otherwise
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
	    puts "Usage: ns $argv0 <tcp variant>"
	    exit 0
	}
    }
    
    set tcpvar $test
    set tcptyp $test1
    
    set cwndfile "$tcptyp cwnd."
    lappend cwndfile $tcpvar
    set f0 [open $cwndfile w]

    set seqfile " $tcptyp seq."
    lappend seqfile $tcpvar
    set f1 [open $seqfile w]

    set out "OUT-$tcptyp-$tcpvar-client"
    set f2 [open $out w]
    $ns_ trace-all $f2
}

TestSimpleRep instproc run {} {
$self instvar ns_ nsc nsg1 ngeo nsg2 nds nsnoop tcp1 f0 nf tcpvar tcptyp
puts "Begin of Test!"

global opt
#Define node
    set nsc [$ns_ node]
    set nsnoop [$ns_ node]
    set nsg1 [$ns_ node]
    set ngeo [$ns_ node]
    set nsg2 [$ns_ node]
    set nds [$ns_ node]
#Define node repeter/snoop
lappend nodelist $nsg1
    set lan [$ns_ make-lan $nodelist $opt(bw) $opt(delay) $opt(ll) $opt(ifq) $opt(mac) $opt(chan)]
    if {$tcptyp == "Snoop"} {
	set opt(ll) LL/LLSnoop
	set opt(ifq) $opt(ifq)
	$opt(ifq) set limit_ 1000
    }
    $lan addNode [list $nsnoop] $opt(bw) $opt(delay) $opt(ll) $opt(ifq) $opt(mac)
#Linking nodes
$ns_ duplex-link $nsc $nsnoop 10Mb 2ms DropTail
$ns_ duplex-link-op $nsc $nsnoop orient right
$ns_ queue-limit $nsc $nsnoop $opt(qsize)

$ns_ duplex-link $nsg1 $ngeo 2Mb 250ms DropTail
$ns_ duplex-link-op $nsg1 $ngeo orient right
$ns_ queue-limit $nsg1 $ngeo $opt(qsize)

$ns_ duplex-link $ngeo $nsg2 2Mb 250ms DropTail
$ns_ duplex-link-op $ngeo $nsg2 orient right
$ns_ queue-limit $ngeo $nsg2 $opt(qsize)

$ns_ duplex-link $nsg2 $nds 10Mb 2ms DropTail
$ns_ duplex-link-op $nsg2 $nds orient right
$ns_ queue-limit $nsg2 $nds $opt(qsize)

#Generating random error
#set loss_model(1) [new ErrorModel/Uniform 0.02pkt]
#$ns_ lossmodel $loss_model(1) $nsg1 $ngeo
#$loss_model(1) drop-target [new Agent/Null]

#set loss_model(2) [new ErrorModel/Uniform 0.02pkt]
#$ns_ lossmodel $loss_model(2) $ngeo $nsg2
#$loss_model(2) drop-target [new Agent/Null]

#set loss_model(3) [new ErrorModel/Uniform 0.02pkt]
#$ns_ lossmodel $loss_model(3) $ngeo $nsg1
#$loss_model(3) drop-target [new Agent/Null]

#set loss_model(4) [new ErrorModel/Uniform 0.02pkt]
#$ns_ lossmodel $loss_model(4) $nsg2 $ngeo
#$loss_model(4) drop-target [new Agent/Null]

#Create TCP and generate traffic over links
if {$tcpvar =="Tahoe"} {
    Agent/TCP set nam_tracevar_ true
    $self set tcp1 [new Agent/TCP]
}
if {$tcpvar != "Tahoe"} {
    Agent/TCP/$tcpvar set nam_tracevar_ true
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
    set tcp
    set tcpsink1 [new Agent/TCPSink/Sack1]
}

$ns_ attach-agent $nds $tcpsink1

set ftp1 [new Application/FTP]
$ftp1 attach-agent $tcp1

# set cbr1 [new Application/Traffic/CBR]
# $cbr1 attach-agent $tcp1

$ns_ connect $tcp1 $tcpsink1

puts "at 0.0 record"
$ns_ at 0.0 "$self record"

puts "at 1.1 $ftp1 start"
$ns_ at 1.0 "$ftp1 start"

# puts "at 1.1 $cbr1 start"
# $ns_ at 1.0 "$cbr1 start"

puts "at 3000.0 finish"
$ns_ at 3000.0 "$self finish"
$ns_ run
# puts "Exiting testSimpleRep run"
}

TestSimpleRep instproc record {} {
$self instvar ns_ tcp1 f0 f1
    #Set time after whitch the procedure should be called again
    set time 0.5
    #Current cwnd
    set bw0 [$tcp1 set cwnd_]
    set bw1 [$tcp1 set t_seqno_]
    #Get the current time
    set now [$ns_ now]
    
    #puts "$now $bw0"
    puts $f0 "$now $bw0"
    puts $f1 "$now $bw1"
    #Re-schedule the procedure
    $ns_ at [expr $now+$time] "$self record"

}

TestSimpleRep instproc finish {} {
$self instvar ns_ f0 nf tcptyp cwndfile seqfile
    puts "Finishing..."
    $ns_ flush-trace
    close $f0
   # close $nf
   # close $tcptyp
   # close $cwndfile
   # close $seqfile

    #puts "Filtering for NAM..."
    #exec /home/tucq/ns-allinone-2.34/nam-1.14/bin/namfilter.tcl $tcptyp$tcpvar.nam
    puts "Test OK! End of the test!"

    #puts "Running NAM..."
    #exec nam out.nam &
    #exec xgraph $cwndfile &
    #exec xgraph $seqfile &
    exit 0
}

set trep [new TestSimpleRep]
$trep run

puts "After Runtest"
ns sp.tcl Reno
ns sp.tcl Sack1
ns sp.tcl SackRH
ns sp.tcl Newreno
ns sp.tcl Vegas
ns sp.tcl Fack
ns sp.tcl Asym
ns sp.tcl RFC793edu
