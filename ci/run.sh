#!/bin/bash

set -e
set -x

uname -a

pwd

crystal version
shards
crystal spec
