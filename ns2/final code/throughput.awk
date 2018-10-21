	BEGIN {
	      bytes_recvd   = 0;
	      throughput    = 0;
	      interval      = 1;
	      current_time_instance = 0;
	      nxt_time_instance = current_time_instance + interval;
	}
	{
	        action  = $1;
	        time    = $2;
	        from    = $3;  
	        to  = $4;
	        type    = $5;  
        	pkt_size = $6; 
       		flow_id = $8;
	        src = $9;
	        dst = $10;
	        sequence_n0 = $11;
	        pkt_id  = $12;
	         
	        if (time < nxt_time_instance)
	           {            
	             if (action == "r")
	                 {
	                  bytes_recvd = bytes_recvd + pkt_size;                  
	                 }
	         }
	    else {
	        current_time_instance = nxt_time_instance;
	        nxt_time_instance += interval;
	        throughput = bytes_recvd / current_time_instance;
	        printf("%f %f\n",current_time_instance, throughput/1024);
	    }
	}
	END {
	}
