#!/usr/bin/env bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Start hadoop avatar daemons.
# Optinally upgrade or rollback dfs state.
# Run this on master node.

usage="Usage: start-avatar.sh [-upgrade|-rollback|-zero|-one|-help]"

params=$#
bin=`dirname "$0"`
bin=`cd "$bin"; pwd`
thishost=`hostname`

. "$bin"/hadoop-config.sh

# If no options are provided then start both AvatarNodes
instance0="-zero"
instance1="-one -sync -standby"

# get arguments
if [ $# -ge 1 ]; then
	nameStartOpt=$1
	shift
	case $nameStartOpt in
	  (-help)
                echo $usage
                echo "-zero:  Copy over transaction logs from remote machine to local machine."
                echo "        Start the instance of AvatarNode in standby avatar."
                echo "-one:   Copy transaction logs from this machine to remote machine."
                echo "        Start the instance of AvatarNode on remote machine in standby avatar."
                echo " If no parameters are specified then start the first instance of AvatarNode"
                echo "        in primary Avatar and the second instance in standby avatar."
		exit 1
	  	;;
	  (-upgrade)
	  	;;
	  (-rollback) 
	  	dataStartOpt=$nameStartOpt
	  	;;
	  (-zero) 
	  	instance0="-zero -standby"
	  	instance1=""
	  	;;
	  (-one) 
	  	instance0=""
	  	instance1="-one -standby"
	  	;;
	  (*)
		  echo $usage
		  exit 1
	    ;;
	esac
fi

# start avatar daemons
# start namenode after datanodes, to minimize time namenode is up w/o data
# note: datanodes will log connection errors until namenode starts
if [ -f "${HADOOP_CONF_DIR}/hadoop-env.sh" ]; then
  . "${HADOOP_CONF_DIR}/hadoop-env.sh"
fi
export HADOOP_OPTS="$HADOOP_OPTS $HADOOP_NAMENODE_OPTS"

# read the contents of the masters file
mastersfile="${HADOOP_CONF_DIR}/masters"

let numhost=0
host0==""
host1=""
for hosts in `cat "$mastersfile"|sed  "s/#.*$//;/^$/d"`; do
  if [ $numhost -ge 2 ] ; then
    echo "You must list only two entries in the masters file."
    echo "The first entry is the zero-th instance of the AvatarNode."
    echo "The second entry is the one-th instance of the AvatarNode."
    exit;
  fi
  if [ $numhost -eq 0 ] ; then
    host0=$hosts
  else
    host1=$hosts
  fi
  ((numhost++))
done

# check that there are only two elements in the masters file
if [ $numhost -ne 2 ] ; then
  echo "You must list only two entries in the masters file."
  echo "The first entry is the zero-th instance of the AvatarNode."
  echo "The second entry is the one-th instance of the AvatarNode."
  exit;
fi

# stop the zero-th  of AvatarNode
if [ "x$instance0" != "x" ]; then
  ssh $host0 "$bin"/hadoop-daemon.sh --config $HADOOP_CONF_DIR stop org.apache.hadoop.hdfs.server.namenode.AvatarNode
fi

# stop the one-th of AvatarNode
if [ "x$instance1" != "x" ]; then
  ssh $host1 "$bin"/hadoop-daemon.sh --config $HADOOP_CONF_DIR stop org.apache.hadoop.hdfs.server.namenode.AvatarNode
fi

# stop the AvatarDataNodes
"$bin"/hadoop-daemons.sh --config $HADOOP_CONF_DIR stop org.apache.hadoop.hdfs.server.datanode.AvatarDataNode
