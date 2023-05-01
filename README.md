# tn9k_f18a
 
Tang Nano 9K F18a Clone

This project recreates the F18a FPGA Board using the over the counter Sipeed's Tang Nano 9K board plus a designed set of boards to be stacked on top where the TMS9118 was located.

The bitstream file is fpga/tn9k_f18a/impl/pnr/tn9k_f19A.fs

The BOM can be found here https://www.digikey.ca/short/2t98zrjw

Or transcribed here

Quantity	Part Number					Description

1			123-A-HDF15A-KG-TAXB-ND		CONN D-SUB HD RCPT 15P R/A SLDR
3			123-AR20-HZL-TT-ND			CONN IC DIP SOCKET 20POS TIN
2			S7022-ND					CONN HDR 24POS 0.1 TIN PCB
1			2449-KT04RTH-ND				SWITCH SLIDE DIP 4POS 25MA 24V
3			296-8503-5-ND				IC TXRX NON-INVERT 3.6V 20DIP
3			1109PHCT-ND	CAP 			CER 0.1UF 50V X7R AXIAL
2			2057-PH2RA-16-UA-ND			CONN HEADER R/A 16POS 2.54MM
2			A835AR-ND					CONN HDR DIP POST 20POS GOLD
1			ED3048-5-ND					CONN IC DIP SOCKET 40POS TIN
1			2057-ICM-640-1-GT-HT-ND		MACHINE PIN SOCKET, IC, DIP, 40P
1			1528-5294-ND				GPIO RIBBON CABLE 2X10 IDC CABLE
3			CF14JT2K20CT-ND				RES 2.2K OHM 5% 1/4W AXIAL
2			CF14JT47R0CT-ND				RES 47 OHM 5% 1/4W AXIAL
3			CF14JT4K70CT-ND				RES 4.7K OHM 5% 1/4W AXIAL
3			CF14JT1K00CT-ND				RES 1K OHM 5% 1/4W AXIAL
3			CF14JT470RCT-ND				RES 470 OHM 5% 1/4W AXIAL

Notes:
1) CONN HDR DIP POST 20POS GOLD: It is expensive on DigiKey but it can be sourced elsewhere cheaper, even Amazon.
2) GPIO RIBBON CABLE 2X10 IDC CABLE : It was supposed to be 2x8 but is out of stock. The 2x10 just works. Or build your own.
3) The capacitors need to be soldered manually on the bottom of each IC's. There are no pads for them to reduce the size of the board. See back.jpg photo for reference.
4) There are 2 DIP 40 sockets in this list: one machined other normal. The machined socket you will use to connect the board on top, thus protecting the pins. The machined pins for the board will connect easily to a machined socket. Then you stack this machined socked over the normal one (notice little force is necessary), and then finally you stack them at the NABU PC's TMS9118 socket. This will protect both the NABU and the TN9K_F18A pins.

