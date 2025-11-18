#!/bin/bash

function print_help() {
  echo -e "vtog.sh script usage
  \033[1m--input\033[0m, \033[1m-i\033[0m 
    path to video file, mandatory

  \033[1m--output\033[0m, \033[1m-o\033[0m
    output filename, cannot be path for now, optional, default res.gif

  \033[1m--ws\033[0m                      
    workspace, optional, default frames

  \033[1m--fps\033[0m
    determines how many frames per second to take from every video second, optional, default 4

  \033[1m--width\033[0m, \033[1m-w\033[0m
    resize frame to provided width, default no value

  \033[1m--height\033[0m, \033[1m-h\033[0m
    resize frame to provided width, default no value
    (?) if none of width, height passed, no resize takes place

  \033[1m--quality\033[0m
    frame percentage quality range, default 65-80

  \033[1m--maxthreads\033[0m
    maximum of threads to use while processing final GIF frames

    Examples:
    (...)
    "
    exit 0
  }
