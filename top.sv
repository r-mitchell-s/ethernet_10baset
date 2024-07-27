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
 
	// then take the one's complement of the checksum_sum
endmodule
