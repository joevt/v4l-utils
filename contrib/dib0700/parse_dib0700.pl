#!/usr/bin/perl

#   Copyright (C) 2008-2011 Mauro Carvalho Chehab
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, version 2 of the License.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#

use strict;

my %req_map = (
	0x0 => "REQUEST_SET_USB_XFER_LEN",
	0x2 => "REQUEST_I2C_READ",
	0x3 => "REQUEST_I2C_WRITE",
	0x4 => "REQUEST_POLL_RC",
	0x8 => "REQUEST_JUMPRAM",
	0xB => "REQUEST_SET_CLOCK",
	0xC => "REQUEST_SET_GPIO",
	0xF => "REQUEST_ENABLE_VIDEO",
	0x10 => "REQUEST_SET_I2C_PARAM",
	0x11 => "REQUEST_SET_RC",
	0x12 => "REQUEST_NEW_I2C_READ",
	0x13 => "REQUEST_NEW_I2C_WRITE",
	0x15 => "REQUEST_GET_VERSION",
);

my %gpio_map = (
	0 => "GPIO0",
	2 => "GPIO1",
	3 => "GPIO2",
	4 => "GPIO3",
	5 => "GPIO4",
	6 => "GPIO5",
	8 => "GPIO6",
	10 => "GPIO7",
	11 => "GPIO8",
	14 => "GPIO9",
	15 => "GPIO10",
);

sub type_req($)
{
	my $reqtype = shift;
	my $s;

	if ($reqtype & 0x80) {
		$s = "RD ";
	} else {
		$s = "WR ";
	}
	if (($reqtype & 0x60) == 0x20) {
		$s .= "CLAS ";
	} elsif (($reqtype & 0x60) == 0x40) {
		$s .= "VEND ";
	} elsif (($reqtype & 0x60) == 0x60) {
		$s .= "RSVD ";
	}

	if (($reqtype & 0x1f) == 0x00) {
		$s .= "DEV ";
	} elsif (($reqtype & 0x1f) == 0x01) {
		$s .= "INT ";
	} elsif (($reqtype & 0x1f) == 0x02) {
		$s .= "EP ";
	} elsif (($reqtype & 0x1f) == 0x03) {
		$s .= "OTHER ";
	} elsif (($reqtype & 0x1f) == 0x04) {
		$s .= "PORT ";
	} elsif (($reqtype & 0x1f) == 0x05) {
		$s .= "RPIPE ";
	} else {
		$s .= sprintf "RECIP 0x%02x ", $reqtype & 0x1f;
	}

	$s =~ s/\s+$//;
	return $s;
}

while (<>) {
	tr/A-F/a-f/;
	if (m/([0-9a-f].) ([0-9a-f].) ([0-9a-f].) ([0-9a-f].) ([0-9a-f].) ([0-9a-f].) ([0-9a-f].) ([0-9a-f].)[\<\>\s]+(.*)/) {
		my $reqtype = hex($1);
		my $req = hex($2);
		my $wvalue = hex("$4$3");
		my $windex = hex("$6$5");
		my $wlen = hex("$8$7");
		my $payload = $9;
		my @bytes = split(/ /, $payload);
		for (my $i = 0; $i < scalar(@bytes); $i++) {
			$bytes[$i] = hex($bytes[$i]);
		}

		if (defined($req_map{$req})) {
			$req = $req_map{$req};
		} else {
			$req = sprintf "0x%02x", $req;
		}

		my $ok = 0;
		if ($req eq "REQUEST_I2C_READ") {
			my $txlen = ($wvalue >> 8) + 2;
			my $addr = sprintf "0x%02x >> 1", $wvalue & 0xfe;
			my $val;

			if ($txlen == 2) {
				$ok = 1;
				printf("dib0700_i2c_read($addr); /* txlen=$txlen, $payload */\n");
			} elsif ($txlen == 3) {
				$val = $windex >> 8;
				$ok = 1;
				printf("dib0700_i2c_read($addr, %d); /* txlen=$txlen, $payload */\n", $val);
			} elsif ($txlen == 4) {
				$val = $windex;
				printf("dib0700_i2c_read($addr, %d); /* txlen=$txlen, $payload */\n", $val);
				$ok = 1;
			}			
		}

		if ($req eq "REQUEST_I2C_WRITE") {
			if ($wlen == 5 || $wlen == 6) {
				my $addr = sprintf "0x%02x >> 1", $bytes[1];
				my $reg = sprintf "0x%04x", $bytes[2] << 8 | $bytes[3];
				my $val;
				if ($wlen == 6) {
					$val = sprintf "%d", $bytes[4] << 8 | $bytes[5];
				} else {
					$val = sprintf "%d", $bytes[4];
				}
				printf("dib0700_i2c_write($addr, $reg, $val);\n");
				$ok = 1;
			}
		}
			
		if ($req eq "REQUEST_SET_GPIO") {
				my $gpio = $bytes[1];
				my $v = $bytes[2];

				my $dir = "GPIO_IN";
				my $val = 0;

				$dir = "GPIO_OUT" if ($v & 0x80);
				$val = 1 if ($v & 0x40);

				if (!($v & 0x3f)) {
					$gpio = $gpio_map{$gpio} if (defined($gpio_map{$gpio}));
					printf("dib0700_set_gpio(adap->dev, $gpio, $dir, $val);\n");
					$ok = 1;
				}
		}

		if (!$ok) {
			printf("%s, Req %s, wValue: 0x%04x, wIndex 0x%04x, wlen %d: %s\n",
				type_req($reqtype), $req, $wvalue, $windex, $wlen, $payload);
		}
	}
}
