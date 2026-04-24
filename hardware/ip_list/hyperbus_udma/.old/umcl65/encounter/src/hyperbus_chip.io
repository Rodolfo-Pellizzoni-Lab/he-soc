#
# This is an io-template for umcL65 ninth_module QFN40
#
# - Every "Offset: xxx" line defines a possible placement location/slot for one pad.
# - The "#pin no.: nn" comment shows the corresponding pin number for the QFN40 package.
# - Make sure that the side specifiers (N/S/E/W) are correct as the placement
#   location of a pad is solely determined by its offset and side specifier.
# - Do not change the offset numbers ("offset= xxx").
# - Do not change the placement of the supply pads.
# - In this template file, all I/O pins are commented out. If you use this file
#   do not forget to uncomment the lines. See chip-ep.io-example


# v1.0 - <muheim@ee.ethz.ch> - Thu Apr 24 15:42:38 CEST 2014
#  - coppy freom old QFN32 v1.1
#    adjusted to ninth_module QFN40

# adjusted to Faraday libraries for umcL65
#   pins                     40
#                            36     I/O
#                             2 (2) Core power
#                             2 (2) Pad  power
# 
#   grid is multiple of       0.1
#   pad dimensions           60.0 x   88.8 
#   total area (seal ring) 1252.0 x 1252.0
#   die area (seal ring)   1200.0 x 1200.0
#   core area              1022.4 x 1022.4
#   pad pitch                90

######################################################
#                                                    #
# File for I/O placement                             #
#                                                    #
######################################################
(globals
    version = 3
    io_order = default
)


# see 
# http://eda.ee.ethz.ch/index.php/UmcL65#Ninth_Modules

(iopad
  (topleft
    (inst name="pad_corner1"  offset=1111.2 )
  )
# perl -e '$i=120; for (1..11){printf "%7.2f\n",$i; $i=$i+90}'

### left side (W, bottom to top)
  (left
    (inst name=""   offset= 120.00 ) # pin no: 10
    (inst name=""   offset= 210.00 ) # pin no:  9
    (inst name=""   offset= 300.00 ) # pin no:  8
    (inst name=""   offset= 390.00 ) # pin no:  7
    (inst name=""   offset= 480.00 ) # pin no:  6
    (inst name="pad_vdd_c1"    offset= 570.00 ) # pin no:  5
    (inst name="pad_vss_c1"    offset= 660.00 ) #
    (inst name=""  offset= 750.00 ) # pin no:  4
    (inst name=""  offset= 840.00 ) # pin no:  3
    (inst name=""  offset= 930.00 ) # pin no:  2
    (inst name=""  offset=1020.00 ) # pin no:  1
  )
  (bottomleft
    (inst name="pad_corner2"     offset=0)
  )
### bottom side (S, left to right)
  (bottom
    (inst name="pad_vdd_p1"    offset= 120.00 ) # pin no: 11 
    (inst name=""  offset= 210.00 ) # pin no: 12
    (inst name=""  offset= 300.00 ) # pin no: 13
    (inst name=""  offset= 390.00 ) # pin no: 14
    (inst name=""  offset= 480.00 ) # pin no: 15
    (inst name=""  offset= 570.00 ) # pin no: 16
    (inst name=""  offset= 660.00 ) # pin no: 17
    (inst name=""  offset= 750.00 ) # pin no: 18
    (inst name=""  offset= 840.00 ) # pin no: 19
    (inst name=""  offset= 930.00 ) # pin no: 20
    (inst name="pad_vss_p1"    offset=1020.00 ) #
  )
  (bottomright
    (inst name="pad_corner3" offset=0)
  )
### right side (E, bottom to top)
  (right
    (inst name=""   offset= 120.00 ) # pin no: 21
    (inst name=""   offset= 210.00 ) # pin no: 22
    (inst name=""   offset= 300.00 ) # pin no: 23
    (inst name=""   offset= 390.00 ) # pin no: 24
    (inst name="pad_vss_c2"      offset= 480.00 ) # 
    (inst name="pad_vdd_c2"      offset= 570.00 ) # pin no: 25
    (inst name=""   offset= 660.00 ) # pin no: 26
    (inst name=""   offset= 750.00 ) # pin no: 27
    (inst name=""   offset= 840.00 ) # pin no: 28
    (inst name=""   offset= 930.00 ) # pin no: 29
    (inst name=""   offset=1020.00 ) # pin no: 30 
  )
### top side (N, left to right)
  (topright
    (inst name="pad_corner4"  offset=1111.2)
  )
  (top
    (inst name="pad_vss_p2"    offset= 120.00 ) # 
    (inst name=""   offset= 210.00 ) # pin no: 40
    (inst name=""   offset= 300.00 ) # pin no: 39
    (inst name=""   offset= 390.00 ) # pin no: 38
    (inst name=""   offset= 480.00 ) # pin no: 37
    (inst name=""   offset= 570.00 ) # pin no: 36
    (inst name=""   offset= 660.00 ) # pin no: 35
    (inst name=""   offset= 750.00 ) # pin no: 34
    (inst name=""   offset= 840.00 ) # pin no: 33
    (inst name=""   offset= 930.00 ) # pin no: 32
    (inst name="pad_vdd_p2"    offset=1020.00 ) # pin no: 31
  )
)
