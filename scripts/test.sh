#!/bin/bash

# Variations of a Flex-Bison parser
# -- based on "A COMPACT GUIDE TO LEX & YACC" by Tom Niemann
# Copyright (C) 2011 Jerry Chen <mailto:onlyuser@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

show_help()
{
    echo "SYNTAX: `basename $0` <EXEC> <INPUT_MODE> <INPUT_FILE> <GOLD_KEYWORD> <GOLD_FILE> <OUTPUT_FILE_STEM>"
}

if [ $# -ne 6 ]; then
    echo "fail! -- expect 6 arguments! ==> $@"
    show_help
    exit 1
fi

TEMP_FILE_0=`mktemp`
trap "rm $TEMP_FILE_0" EXIT
TEMP_FILE_1=`mktemp`
trap "rm $TEMP_FILE_1" EXIT

EXEC=$1
INPUT_MODE=$2
INPUT_FILE=$3
GOLD_KEYWORD=$4
GOLD_FILE=$5
OUTPUT_FILE_STEM=$6
PASS_FILE=${OUTPUT_FILE_STEM}.pass
FAIL_FILE=${OUTPUT_FILE_STEM}.fail

if [ ! -f $INPUT_FILE ]; then
    echo "fail! -- <INPUT_FILE> not found! ==> $INPUT_FILE"
    exit 1
fi

if [ ! -f $GOLD_FILE ]; then
    echo "fail! -- <GOLD_FILE> not found! ==> $GOLD_FILE"
    exit 1
fi

case $INPUT_MODE in
    "file")
        $EXEC $INPUT_FILE | grep $GOLD_KEYWORD > $TEMP_FILE_0
        ;;
    "stdio")
        echo `cat $INPUT_FILE` | $EXEC | grep $GOLD_KEYWORD > $TEMP_FILE_0
        ;;
    "buf")
        $EXEC `cat $INPUT_FILE` | grep $GOLD_KEYWORD > $TEMP_FILE_0
        ;;
    *)
        echo "fail! -- invalid input mode"
        exit 1
        ;;
esac
diff $TEMP_FILE_0 $GOLD_FILE | tee $TEMP_FILE_1

if [ ${PIPESTATUS[0]} -ne 0 ]; then # $? captures the last pipe
    echo "fail!"
    cp $TEMP_FILE_1 $FAIL_FILE # TEMP_FILE_1 already trapped on exit
    exit 1
fi

echo "success!" | tee $PASS_FILE
exit 0
