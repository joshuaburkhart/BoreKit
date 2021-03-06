#!/bin/bash

#Usage: wyeomyia_velvetg.sh </full/path/to/input/dir> <maximum kmer frequency (in thousands)> <minimum kmer frequency> <k> <expected kmer coverage> [<queue> <procs> <node name>]

#Example: wyeomyia_velvetg.sh /home13/jburkhar/out/velvet_out/velveth_400-1-71/ 400 1 71 24 longfat 32 un5

QUEUE=$6
PROCS=$7
NODE_NAME=$8

: ${QUEUE:="longfat"}
: ${PROCS:="32"}
: ${NODE_NAME:="un5"}

inputdir=$(echo $1 | awk -F'/velvet_out/' '{print $NF}')

if [ -z "$inputdir" ]
then
	inputdir=$(echo $1 | awk -F'/velvet_out/' '{print $(NF -1)}')
fi

echo path to input dir: $1
echo contents of input dir: $(ls $1/*)
echo max kmer frequency: $2
echo min kmer frequency: $3
echo k: $4
echo expected coverage: $5
echo QUEUE: $QUEUE
echo PROCS: $PROCS
echo NODE_NAME: $NODE_NAME
echo input directory: $inputdir

qsubmit.rb \
"mkdir -p /scratch/$USER/\$PBS_JOBID/velvet_out/$inputdir && \
cp $1/* /scratch/$USER/\$PBS_JOBID/velvet_out/$inputdir/ && \
velvetg /scratch/$USER/\$PBS_JOBID/velvet_out/$inputdir -min_contig_lgth 400 -ins_length 500 -exp_cov $5 -cov_cutoff 2 -max_coverage 300" \
-q $QUEUE -m velvet -j vlvtg_$2-$3_k$4 -p $PROCS
