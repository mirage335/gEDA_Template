#!/bin/bash

# Converts gEDA projects to files to suitable for CAD modeling.

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

PWD_SanityCheck generate-cad.sh

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
	
	cd $pcbname/
	
	gerbv -b \#FFFFFF --export svg --output combined.svg $pcbname.plated-drill.cnc $pcbname.outline.gbr
	inkscape -E combined.eps combined.svg && pstoedit -dt -f dxf combined.eps combined.dxf	#Inches. Circles will be approximate
	
	gerbv -b \#FFFFFF --export png --dpi 600x600 --output Render.png -f \#000000FF $pcbname.topsilk.gbr -f \#ccccccFF $pcbname.plated-drill.cnc -f \#8B2323FF $pcbname.top.gbr -f \#3A5FCDFF $pcbname.bottom.gbr -f \#104E8BFF $pcbname.outline.gbr
	
	convert Render.png -bordercolor white -border 1x1 -alpha set -channel RGBA -fuzz 1% -fill none -floodfill +0+0 white -shave 1x1 Render.png
	convert Render.png -fuzz 1% -transparent \#cccccc Render.png
	
	cd ..
	
done

find . -maxdepth 2 -regextype posix-egrep -regex ".*(silk|\.cnc|\.gbr|\.eps).*" -delete

echo -e '\E[1;32;46m Finished. \E[0m'