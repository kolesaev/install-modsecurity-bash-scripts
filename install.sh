#!/bin/bash

found_os=false

if which apt && [[ -d /etc/apt/sources.list.d ]]
then

    found_os=true
    bash ./debian-based.sh $1 $2

fi

# if which yum && [[ -d /etc/yum.repos.d ]]
# then

#     bash ./rhel-based.sh $1

# fi

if [[ "$found_os" == "false" ]]
then

    echo "Unsuppoted OS found"
    exit 1

fi