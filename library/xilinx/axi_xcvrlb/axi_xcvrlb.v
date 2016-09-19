// ***************************************************************************
// ***************************************************************************
// Copyright 2011(c) Analog Devices, Inc.
// 
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//     - Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     - Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in
//       the documentation and/or other materials provided with the
//       distribution.
//     - Neither the name of Analog Devices, Inc. nor the names of its
//       contributors may be used to endorse or promote products derived
//       from this software without specific prior written permission.
//     - The use of this software may or may not infringe the patent rights
//       of one or more patent holders.  This license does not release you
//       from the requirement that you obtain separate licenses from these
//       patent holders to use this software.
//     - Use of the software either in source or binary form, must be run
//       on or directly connected to an Analog Devices Inc. component.
//    
// THIS SOFTWARE IS PROVIDED BY ANALOG DEVICES "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED.
//
// IN NO EVENT SHALL ANALOG DEVICES BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, INTELLECTUAL PROPERTY
// RIGHTS, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF 
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/1ps

module axi_xcvrlb #(

  // parameters

  parameter   NUM_OF_LANES = 1) (

  // transceiver interface

  input                         ref_clk,
  input   [(NUM_OF_LANES-1):0]  rx_p,
  input   [(NUM_OF_LANES-1):0]  rx_n,
  output  [(NUM_OF_LANES-1):0]  tx_p,
  output  [(NUM_OF_LANES-1):0]  tx_n,

  // axi interface

  input                         s_axi_aclk,
  input                         s_axi_aresetn,
  input                         s_axi_awvalid,
  input   [31:0]                s_axi_awaddr,
  input   [ 2:0]                s_axi_awprot,
  output                        s_axi_awready,
  input                         s_axi_wvalid,
  input   [31:0]                s_axi_wdata,
  input   [ 3:0]                s_axi_wstrb,
  output                        s_axi_wready,
  output                        s_axi_bvalid,
  output  [ 1:0]                s_axi_bresp,
  input                         s_axi_bready,
  input                         s_axi_arvalid,
  input   [31:0]                s_axi_araddr,
  input   [ 2:0]                s_axi_arprot,
  output                        s_axi_arready,
  output                        s_axi_rvalid,
  output  [ 1:0]                s_axi_rresp,
  output  [31:0]                s_axi_rdata,
  input                         s_axi_rready);

  // internal registers

  reg                           up_wack = 'd0;
  reg     [31:0]                up_scratch = 'd0;
  reg                           up_resetn = 'd0;
  reg     [31:0]                up_status = 'd0;
  reg                           up_rack = 'd0;
  reg     [31:0]                up_rdata = 'd0;

  // internal signals

  wire                          up_rstn;
  wire                          up_clk;
  wire                          up_wreq_s;
  wire    [ 7:0]                up_waddr_s;
  wire    [31:0]                up_wdata_s;
  wire                          up_rreq_s;
  wire    [ 7:0]                up_raddr_s;
  wire    [31:0]                up_status_s;

  // defaults

  assign up_rstn = s_axi_aresetn;
  assign up_clk = s_axi_aclk;
  assign up_status_s[31:NUM_OF_LANES] = 'd0;

  // register access

  always @(negedge up_rstn or posedge up_clk) begin
    if (up_rstn == 0) begin
      up_wack <= 'd0;
      up_scratch <= 'd0;
      up_resetn <= 'd0;
      up_status <= 'd0;
    end else begin
      up_wack <= up_wreq_s;
      if ((up_wreq_s == 1'b1) && (up_waddr_s == 8'h02)) begin
        up_scratch <= up_wdata;
      end
      if ((up_wreq_s == 1'b1) && (up_waddr_s == 8'h04)) begin
        up_resetn <= up_wdata[0];
      end
      if ((up_wreq_s == 1'b1) && (up_waddr_s == 8'h05)) begin
        up_status <= up_status_s | (up_status & ~up_wdata);
      end else begin
        up_status <= up_status_s | up_status;
      end
    end
  end

  always @(negedge up_rstn or posedge up_clk) begin
    if (up_rstn == 0) begin
      up_rack <= 'd0;
      up_rdata <= 'd0;
    end else begin
      up_rack <= up_rreq_s;
      if (up_rreq_s == 1'b1) begin
        case (up_raddr_s)
          10'h000: up_rdata <= VERSION;
          10'h001: up_rdata <= ID;
          10'h002: up_rdata <= up_scratch;
          10'h004: up_rdata <= {31'd0, up_resetn};
          10'h005: up_rdata <= up_status;
          default: up_rdata <= 32'd0;
        endcase
      end else begin
        up_rdata <= 32'd0;
      end
    end
  end

  // instantiations

  genvar n;
  generate
  for (n = 0; n < NUM_OF_LANES; n = n + 1) begin: g_lanes
  axi_xcvrlb_1 i_xcvrlb_1 (
    .ref_clk (ref_clk),
    .rx_p (rx_p[n]),
    .rx_n (rx_n[n]),
    .tx_p (tx_p[n]),
    .tx_n (tx_n[n]),
    .up_rstn (up_rstn),
    .up_clk (up_clk),
    .up_resetn (up_resetn),
    .up_status (up_status_s[n]));
  end
  endgenerate

  up_axi #(.ADDRESS_WIDTH (8)) i_axi (
    .up_rstn (up_rstn),
    .up_clk (up_clk),
    .up_axi_awvalid (s_axi_awvalid),
    .up_axi_awaddr (s_axi_awaddr),
    .up_axi_awready (s_axi_awready),
    .up_axi_wvalid (s_axi_wvalid),
    .up_axi_wdata (s_axi_wdata),
    .up_axi_wstrb (s_axi_wstrb),
    .up_axi_wready (s_axi_wready),
    .up_axi_bvalid (s_axi_bvalid),
    .up_axi_bresp (s_axi_bresp),
    .up_axi_bready (s_axi_bready),
    .up_axi_arvalid (s_axi_arvalid),
    .up_axi_araddr (s_axi_araddr),
    .up_axi_arready (s_axi_arready),
    .up_axi_rvalid (s_axi_rvalid),
    .up_axi_rresp (s_axi_rresp),
    .up_axi_rdata (s_axi_rdata),
    .up_axi_rready (s_axi_rready),
    .up_wreq (up_wreq_s),
    .up_waddr (up_waddr_s),
    .up_wdata (up_wdata_s),
    .up_wack (up_wack_s),
    .up_rreq (up_rreq_s),
    .up_raddr (up_raddr_s),
    .up_rdata (up_rdata),
    .up_rack (up_rack));

endmodule

// ***************************************************************************
// ***************************************************************************

