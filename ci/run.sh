#!/bin/bash

set -e
set -x

uname -a

pwd

crystal version

crystal deps

crystal spec
