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
	
	cp ./millproject $pcbname/
	
	sed 's/PCB/'$pcbname'/g' -i $pcbname/millproject
	
	cd $pcbname/
	pcb2gcode
	
	gerbv --export rs274x --translate 0,0 --translate 3,0 --translate 0,3 --translate 3,3 --output=Panel.gbr $pcbname.top.gbr $pcbname.top.gbr $pcbname.bottom.gbr $pcbname.bottom.gbr
	gerbv -b \#FFFFFF -f \#00000000 --export pdf --output Lithomask.pdf Panel.gbr
	rm Panel.gbr
	
	gerbv -b \#FFFFFF --export pdf --output Model.pdf -f \#8B2323 $pcbname.top.gbr -f \#3A5FCD $pcbname.bottom.gbr -f \#104E8B $pcbname.outline.gbr
	cd ..
	
done

find . -name drill.ngc -exec sed -i 's/.*S10000.*/&\nM3\nG91.1/' {} \;
find . -maxdepth 2 -regextype posix-egrep -regex ".*(silk|fab\.gbr|plated-drill\.cnc|mask\.gbr|\.png).*" -delete

echo -e '\E[1;32;46m Finished. \E[0m'