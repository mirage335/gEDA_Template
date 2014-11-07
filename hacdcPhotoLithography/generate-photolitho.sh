#!/bin/bash

# Converts gEDA projects to files to suitable for PCB fabrication and assembly, using CNC milling to cut holes, photolithography to form traces, and (optionally) laser cutting to create a solder paste stencil.

# The MIT License (MIT)
# Copyright (c) 2013 Shawn Nock

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#Derived from generate-gerbers.sh by Shawn Nock. Modified by mirage335, under same copyright as above.

#"$1" = File to check.
PWD_SanityCheck() {
	if [[ $(ls -ld ./"$1") ]]
	then
		echo -e '\E[1;32;46m Found file '"$1"', proceeding. \E[0m'
	else
		echo -e '\E[1;33;41m *DANGER* Did not find file '"$1"'! *DANGER* \E[0m'
		echo -e '\E[1;33;41m Aborting! \E[0m'
		exit
	fi
}

PWD_SanityCheck generate-photolitho.sh

echo -e '\E[1;32;46m Diffing millproject.drill and millproject.outline: \E[0m'
diff millproject.drill millproject.outline
echo -e '\E[1;32;46m Diff complete, please review. \E[0m'

# Generate Gerbers for each pcb file in the parent directory
count=0
for pcbname in `ls .. |sed -n -e '/\.pcb/s/\.pcb$//p'`; do
    if [[ ${pcbname: -4} = ".new" ]]; then
        echo "Warning: Assuming $pcbname.pcb is a development artifact, skipping"
        continue
    fi
    if [[ ! -e $pcbname ]]; then
	mkdir $pcbname
    fi
    pcb -x gerber --all-layers --name-style fixed --gerberfile $pcbname/$pcbname ../$pcbname.pcb
	
	cp OpenSCAM_Config $pcbname/
	
	cd $pcbname/
	
	cp ../millproject.drill ./millproject
	sed 's/PCB/'$pcbname'/g' -i ./millproject
	pcb2gcode
	
	cp ../millproject.outline ./millproject
	sed 's/PCB/'$pcbname'/g' -i ./millproject
	pcb2gcode
	
	rm ./wrong.ngc
	
	echo -e "T2\nM6" > ./OpenSCAM_toolchange.ngc
	
	gerbv -b \#FFFFFF -f \#000000FF --export png --dpi 2400x2400 --output $pcbname.top.png $pcbname.top.gbr -f \#000000FF $pcbname.outline.gbr
	gerbv -b \#FFFFFF -f \#000000FF --export png --dpi 2400x2400 --output $pcbname.bottom.png $pcbname.bottom.gbr -f \#000000FF $pcbname.outline.gbr
	convert -flop -density 2400x2400 $pcbname.top.png $pcbname.top_mirror.png
	montage -density 2400x2400 -mode concatenate -bordercolor \#000000 -border 4 -geometry '+1200+1200' $pcbname.top_mirror.png $pcbname.top_mirror.png $pcbname.bottom.png $pcbname.bottom.png Lithomask.pdf
	rm ./*.png
	
	gerbv -b \#FFFFFF --export png --dpi 2400x2400 --output Model.png -f \#000000FF $pcbname.topsilk.gbr -f \#ccccccFF $pcbname.plated-drill.cnc -f \#8B2323FF $pcbname.top.gbr -f \#3A5FCDFF $pcbname.bottom.gbr -f \#104E8BFF $pcbname.outline.gbr
	convert -density 2400x2400 Model.png Model.pdf
	
	cd ..
	
done

find . -name drill.ngc -exec sed -i 's/.*S10000.*/&\nM3\nG91.1\nG0 Z0.10000/' {} \;
find . -maxdepth 2 -regextype posix-egrep -regex ".*(silk|fab\.gbr|plated-drill\.cnc|mask\.gbr|\.png).*" -delete

echo -e '\E[1;32;46m Finished. \E[0m'