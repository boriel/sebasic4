;	// SE Basic IV 4.2 Cordelia - A classic BASIC interpreter for the Z80 architecture.
;	// Copyright (c) 1999-2020 Source Solutions, Inc.

;	// SE Basic IV is free software: you can redistribute it and/or modify
;	// it under the terms of the GNU General Public License as published by
;	// the Free Software Foundation, either version 3 of the License, or
;	// (at your option) any later version.
;	// 
;	// SE Basic IV is distributed in the hope that it will be useful,
;	// but WITHOUT ANY WARRANTY; without even the implied warranty o;
;	// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;	// GNU General Public License for more details.
;	// 
;	// You should have received a copy of the GNU General Public License
;	// along with SE Basic IV. If not, see <http://www.gnu.org/licenses/>.

	output_bin "../bin/FIRMWA~1.BIN",$6000,40962

    org $6000
    import_bin "../ChloeVM.app/Contents/Resources/unodos3.rom";
    import_bin "../ChloeVM.app/Contents/Resources/se.rom";

    defb XOR_MEM($6000, $a000)
    defb SUM_MEM($6000, $a000)
