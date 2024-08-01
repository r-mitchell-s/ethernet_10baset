/* 
This file contains the top module for the ethernet implementation that will be used to send UDP packets from FPGA to PC. It does so at a rate of approximately 10 Mb/s (thus the name 10BASE-T).

The only input to the module is a clock signal (i_clk), which requires a custom clock divider based on the frequency of the FPGA used to synthesize. i_clk must oscillate at 20 MHz, which means 20 MHz must be equal to (FPGA clk / clock divider N value).

The two outputs from the module are a differential pair (o_pos and o_neg) that communicates the current bit of data, which will be sent from the FPGA to the client.  
*/

module top(
	input i_clk,
	output o_pos, o_neg);

	// IP address of the source (in this case the FPGA)
	parameter ip_src1 = ;
	parameter ip_src2 = ;
	parameter ip_src3 = ;
	parameter ip_src4 = ;

	// IP address of the client PC receiving the packet
	parameter ip_dst1 = ;
	parameter ip_dst2 = ;
	parameter ip_dst3 = ;
	parameter ip_dst4 = ;

	// The physical address of the PC receiving the packet
	parameter phys_addr1 = ;
	parameter phys_addr2 = ;
	parameter phys_addr3 = ;
	parameter phys_addr4 = ;
	parameter phys_addr5 = ;
	parameter phys_addr6 = ;

	// clock divider implementation to enable a packet send roughly once per second
	reg [23:0] counter;
	reg start_send;

	// count up until counter is 24 bits of 1 and then begin to send a packet
	always @(posedge i_clk) begin
		counter <= counter + 1;
		start_send <= &counter;
	end

	/*----- declaration of IP header fields (segmented into 16-bit pieces) for checksum calculation -----*/
	
	// version, IHL and type of service
	parameter ip_field1 = 16'h4500;

	// total length of package
	parameter ip_field2 = 16'h002E;

	// ID field
	parameter ip_field3 = 16'h0000;

	// flags and fragment offset
	parameter ip_field4 = 16'h0000;

	// TTL and protocol
	parameter ip_field5 = 16'h8011;

	// the sum of all header fields is part of the checksum sum
	parameter ip_field_sum = ip_field1 + ip_field2 + ip_field3 + ip_field4 + ip_field5; 

	// combine each half of the 2 ip addresses into a 16 bit word (each segment of IPv4 is an 8-bit binary #)
	// NOTE: we left shift the less significant bytes because UDP is big endian
	parameter ip_src_half1 = (ip_src1 << 8) + ip_src2;
	parameter ip_src_half2 = (ip_src3 << 8) + ip_src4;
	parameter ip_dst_half1 = (ip_dst1 << 8) + ip_dst2;
	parameter ip_dst_half2 = (ip_dst3 << 8) + ip_dst4;
	parameter ip_src_sum = ip_src_half1 + ip_src_half2;
	parameter ip_dst_sum = ip_dst_half1 + ip_dst_half2;

	// calculate the checksum for the UDP packet by first summing the ip 
	parameter checksum_sum = ip_field_sum + ip_src_sum + ip_dst_sum;
 
	// then fold the sum twice to ensure no overflow 16 bit value (change from a 32 bit nmuber to a 16 bit by adding the two halves as 16-bit numbers)
	parameter checksum_fold1 = (checksum_sum & 32'h0000FFFF) + checksum_sum >> 16;
	parameter checksum_fold2 = (checksum_fold1 & 32'h0000FFFF) + checksum_fold1 >> 16;

	// complete the checksum by taking the one's complement
	parameter checksum_1comp = ~checksum_fold2;
	
	// declare packet registers - one to hold an individual data byte, and one to one to index into the UDP packet
	reg [6:0] read_addr;
	reg [7:0] pkt_data;

	// ethernet packet generation is based on the value of the address pointer
	always @(posedge i_clk) begin
		case(read_addr)

			// Ethernet preamble synchronized the source and destination hosts (D5 indicates header starting on next cycle)
			7'h00: pkt_data <= 8'h55;
			7'h01: pkt_data <= 8'h55;
			7'h02: pkt_data <= 8'h55;
			7'h03: pkt_data <= 8'h55;
			7'h04: pkt_data <= 8'h55;
			7'h05: pkt_data <= 8'h55;
			7'h06: pkt_data <= 8'h55;
			7'h07: pkt_data <= 8'hD5;
			
			// Ethernet header (6 bytes of MAC address, followed by type and length of the payload)
			7'h08: pkt_data <= phys_addr1;
			7'h09: pkt_data <= phys_addr2;
			7'h0A: pkt_data <= phys_addr3;
			7'h0B: pkt_data <= phys_addr4;
			7'h0C: pkt_data <= phys_addr5;
			7'h0D: pkt_data <= phys_addr6;
			7'h0E: pkt_data <= 8'h00;
			7'h0F: pkt_data <= 8'h12;
			7'h10: pkt_data <= 8'h34;
			7'h11: pkt_data <= 8'h56;
			7'h12: pkt_data <= 8'h78;
			7'h13: pkt_data <= 8'h90;
			
			// IP header (Contains a lot of info, including IP version, source and destination IPs, and the checksum we calculated)
			7'h14: pkt_data <= 8'h08;
			7'h15: pkt_data <= 8'h00;
			7'h16: pkt_data <= 8'h45;
			7'h17: pkt_data <= 8'h00;
			7'h18: pkt_data <= 8'h00;
			7'h19: pkt_data <= 8'h2E;
			7'h1A: pkt_data <= 8'h00;
			7'h1B: pkt_data <= 8'h00;
			7'h1C: pkt_data <= 8'h00;
			7'h1D: pkt_data <= 8'h00;
			7'h1E: pkt_data <= 8'h80;
			7'h1F: pkt_data <= 8'h11;
			7'h20: pkt_data <= checksum_1comp[15:8];
			7'h21: pkt_data <= checksum_1comp[ 7:0];
			7'h22: pkt_data <= ip_src1;
			7'h23: pkt_data <= ip_src2;
			7'h24: pkt_data <= ip_src3;
			7'h25: pkt_data <= ip_src4;
			7'h26: pkt_data <= ip_dst1;
			7'h27: pkt_data <= ip_dst2;
			7'h28: pkt_data <= ip_dst3;
			7'h29: pkt_data <= ip_dst4;
			
			// UDP header port addressing info, as well as another similarly calculated checksum (optional according to IPv4 standard so we will leave out for now)
			7'h2A: pkt_data <= 8'h04;
			7'h2B: pkt_data <= 8'h00;
			7'h2C: pkt_data <= 8'h04;
			7'h2D: pkt_data <= 8'h00;
			7'h2E: pkt_data <= 8'h00;
			7'h2F: pkt_data <= 8'h1A;
			7'h30: pkt_data <= 8'h00;
			7'h31: pkt_data <= 8'h00;
			
			// payload (the data that we actually want to send, hard codded in)
			7'h32: pkt_data <= 8'h00; 
			7'h33: pkt_data <= 8'h01; 
			7'h34: pkt_data <= 8'h02; 
			7'h35: pkt_data <= 8'h03; 
			7'h36: pkt_data <= 8'h04; 
			7'h37: pkt_data <= 8'h05; 
			7'h38: pkt_data <= 8'h06; 
			7'h39: pkt_data <= 8'h07; 
			7'h3A: pkt_data <= 8'h08; 
			7'h3B: pkt_data <= 8'h09; 
			7'h3C: pkt_data <= 8'h0A; 
			7'h3D: pkt_data <= 8'h0B; 
			7'h3E: pkt_data <= 8'h0C; 
			7'h3F: pkt_data <= 8'h0D; 
			7'h40: pkt_data <= 8'h0E; 
			7'h41: pkt_data <= 8'h0F; 
			7'h42: pkt_data <= 8'h10; 
			7'h43: pkt_data <= 8'h11; 
			
			// if nothing is being transmitted, then the PC should be seeing zeroes
			default: pkt_data <= 8'h00;
    	endcase
	end 
	
	/*----- END OF PACKET GENERATION -----*/

	// create a counter to track the duration of the packet transmission
	reg [3:0] shift_count;
	
	// 
	send_pkt;

	// 
	always @(posedge i_clk) begin
		// if start signal is on, 
		if (start_send)
			send_pkt <= 1;
		else if (shift_count == 14 && read_addr == 7'h48)
			send_pkt <= 0;
endmodule