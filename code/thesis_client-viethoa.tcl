#Chu Quang Tu
#TTM k51 - Vien CNTT & TT - DHBK HN
#
#
#Topo thu nghiem End to End
#
#     FTP
#  TCP/tcpvar           LL                                                                                         TCPSink
#    (nsc)------------(repeter-|-nsg1)------------------------------(ngeo) -----------------------(nsg2) ----------- (nds)
#           10Mb, 2ms    100Mb,0ms.HN           2Mb                 VINASAT-1          2Mb          HCM   10Mb,2ms
#                                            <->lost 0.02                         <->lost 0.02
#
# 
#
#
#Topo thu nghiem Snoop
#
#     FTP
#  TCP/tcpvar         LL/LLSnoop                                                                                 TCPSink
#    (nsc)------------(snoop-|-nsg1)------------------------------(ngeo) -----------------------(nsg2) ----------- (nds)
#           10Mb, 2ms    100Mb,0ms.HN          2Mb                 VINASAT-1          2Mb          HCM    10Mb,2ms
#                                            <->lost 0.02                         <->lost 0.02
#
#


# Cau hinh cac thong so
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

Class Thesis

Thesis instproc init {} {
    $self instvar ns_ ngeo nsg1 nsg2 tcp1 tcp2 f0 f1 f2 tcpvar tcptyp cwndfile seqfile
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
      		puts "******************************************************************************************"
      		puts "					HUONG DAN SU DUNG					"
      		puts "Cach dung 	: ns $argv0 <tcp variant> <tcp type>					"	
      		puts "<tcp variant> 	: Tahoe, Reno, Newreno, Sack1						"
      		puts "<tcp type> 	: Snoop									"
      		puts "		: Empty =>'End-to-end'								"
      		puts "												"
      		puts "Ket qua 	: tcptyp cwnd.tcpvar, tcpyp seq.tcpvar, OUT-tcptyp-tcpvar(throughput)		"
      		puts "												"
      		puts "		Build by Chu Quang Tu - TTM K51 - Vien CNTT & TT - DH Bachkhoa HN		"
      		puts "******************************************************************************************"
	      exit 0
       }
    }
    
    set tcpvar $test
    set tcptyp $test1
    

    set cwndfile "$tcptyp cwnd."
    lappend cwndfile $tcpvar
    set f0 [open $cwndfile w]
    
    set seqfile "$tcptyp seq."
    lappend seqfile $tcpvar
    set f1 [open $seqfile w]
    
    set out "OUT-$tcptyp-$tcpvar-client"
    set f2 [open $out w]
    $ns_ trace-all $f2
}


Thesis instproc run {} {
	$self instvar ns_ nsc  ngeo nsg1 nsg2 tcp1 tcp2 f0 nf tcpvar tcptyp
	puts "Bat dau thu nghiem"

	global opt

# Dinh nghia cac node
   
# Ve tinh dia tinh (GEO) VINASAT-1 vi tri 132 do Dong
	$ns_ node-config -satNodeType 	geo-repeater \
			-llType		LL/Sat \
			-macType	Mac/Sat \
			-phyType 	Phy/Repeater \
			-channelType 	Channel/Sat \
			-downlinkBW 	2Mb \
			-wiredRouting 	ON
			
	set ngeo [$ns_ node]
	$ngeo set-position 132
	$ns_ node-config -reset
	
# Hai tram mat dat : Mot o HaNoi(HN), mot o HoChiMinh(HCM) 
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
	
# Thiet lap ket noi giua ve tinh va hai tram mat dat
	$nsg1 add-gsl geo LL/Sat Queue/DropTail 100 Mac/Sat 2Mb Phy/Sat [$ngeo set downlink_] [$ngeo set uplink_]
	$nsg2 add-gsl geo LL/Sat Queue/DropTail 100 Mac/Sat 2Mb Phy/Sat [$ngeo set downlink_] [$ngeo set uplink_]
	$ns_ node-config -reset
	$ns_ unset satNodeType_
	
# Cac tram dau cuoi va tram Repeter/Snoop	
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
	set lan [$ns_ make-lan $nodelist 100Mb 0ms $opt(ll) Queue/DropTail Mac/802_3 Channel]
    	if {$tcptyp == "Snoop"} {
		set opt(ll) LL/LLSnoop
		set opt(ifq) $opt(ifq)
		$opt(ifq) set limit_ 1000
		set nsnoop [$ns_ node $opt(ll)]
	}
    	#puts $opt(ll)
    	$lan addNode [list $nsnoop] 100Mb 0ms $opt(ll) Queue/DropTail Mac/802_3
    	if {$opt(ll) == "LL"} {
    		puts "Su dung ket noi End-to-end ve tinh truyen thong"
    		}
    	if {$opt(ll) == "LL/LLSnoop"} {
    		puts "Su dung Snoop cho ket noi ve tinh"
    		}
    	

#Lien ket cac node
	$ns_ duplex-link $nsc $nsnoop 10Mb 2ms DropTail
	$ns_ queue-limit $nsc $nsnoop $opt(qsize)
	
	$ns_ duplex-link $nsg2 $nds 10Mb 2ms DropTail
	$ns_ queue-limit $nsg2 $nds $opt(qsize)

#Tao loi ngau nhien tren ket noi ve tinh
	set em1_ [new ErrorModel]
	$em1_ unit pkt 
	$em1_ set rate_ 0.02
	#set exprv1 [new RandomVariable/Uniform] 
	#$em1_ ranvar $exprv1
	$em1_ ranvar [new RandomVariable/Uniform]
	$nsg1 interface-errormodel $em1_
	
	set em2_ [new ErrorModel]
	$em2_ unit pkt 
	$em2_ set rate_ 0.02
	#set exprv2 [new RandomVariable/] 
	#$em2_ ranvar $exprv2
	$em2_ ranvar [new RandomVariable/Uniform]
	$nsg2 interface-errormodel $em2_
	

# Khai bao TCP cho client
	if {$tcpvar =="Tahoe"} {
  		$self set tcp1 [new Agent/TCP]
  	}
	if {$tcpvar != "Tahoe"} {
    		$self set tcp1 [new Agent/TCP/$tcpvar]
    	}
	
	$tcp1 set windowInit_ 1
	$tcp1 set packetSize_ 1000
	$ns_ attach-agent $nsc $tcp1
	
	$ns_ add-agent-trace $tcp1 tcp
	$ns_ monitor-agent-trace $tcp1
	$tcp1 tracevar cwnd_
	$tcp1 tracevar t_seqno_
	
# Khai tao TCP cho server	
	set tcpsink1 [new Agent/TCPSink]
	set sack "Sack1"
	if [string match $tcpvar $sack] {
	    #puts "sack1"
	    set tcpsink1 [new Agent/TCPSink/Sack1]
	}
	$ns_ attach-agent $nds $tcpsink1
	
# Gan FTP cho thuc the TCP client
	set ftp1 [new Application/FTP]
	$ftp1 attach-agent $tcp1
	
# Ket noi TCP client va TCP server
	$ns_ connect $tcp1 $tcpsink1
	
        puts "Bat dau ghi o thoi diem 0.0s"
        $ns_ at 0.0 "$self record"

	puts "FTP $ftp1 bat dau chay o thoi diem 1.1s"
	$ns_ at 1.0 "$ftp1 start"

        puts "Dung o thoi diem 5000s"
        $ns_ at 5000.0 "$self finish"

	set satrouteobject_ [new SatRouteObject]
	$satrouteobject_ compute_routes

        $ns_ run
	puts "Ket thuc."
}

Thesis instproc record {} {
	$self instvar ns_ tcp1 tcp2 f0 f1 f2
        #Chu ky ghi
        set time 0.5
        
        set bw0 [$tcp1 set cwnd_]
	set bw1 [$tcp1 set t_seqno_]
	        
        set now [$ns_ now]

        puts $f0 "$now $bw0"
        puts $f1 "$now $bw1"
        
        #Sap xep lai cac thu tuc
        $ns_ at [expr $now+$time] "$self record"
}

Thesis instproc finish {} {
	$self instvar ns_ f0 f1 f2 cwndfile seqfile
        puts "Finishing.."
        $ns_ flush-trace
        close $f0
        close $f1
        close $f2
      
        exit 0
}

set trep [new Thesis]

$trep run

