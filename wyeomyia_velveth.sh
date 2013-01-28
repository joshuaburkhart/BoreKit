#!/bin/bash

#Usage: wyeomyia_velveth.sh </full/path/to/inputfile1> </full/path/to/inputfile2> <maximum kmer frequency (in thousands)> <minimum kmer frequency> <k> [<single reads1> <single reads2> <queue> <procs> <node name> <subdir>]

#Example: wyeomyia_velveth.sh /home13/jburkhar/out/kmr_fltr/400_71_1.fq_1 /home13/jburkhar/out/kmr_fltr/400_71_1.fq_2 400 1 71 /short/reads.fq1 /short/reads.fq2 longfat 2 un5 un5_execution_$(date)

QUEUE=$8
PROCS=$9
NODE_NAME=${10}
SUBDR=${11}/

: ${QUEUE:="fatnodes"}
: ${PROCS:="32"}
: ${NODE_NAME:="un5"}
: ${SUBDR:=""}

inputfile1=$(echo $1 | awk -F'/' '{print $NF}')
inputfile2=$(echo $2 | awk -F'/' '{print $NF}')
inputfile3=$(echo $6 | awk -F'/' '{print $NF}')
inputfile4=$(echo $7 | awk -F'/' '{print $NF}')

echo path to inputfile1: $1
echo path to inputfile2: $2
echo max kmer frequency: $3
echo min kmer frequency: $4
echo k: $5
echo QUEUE: $QUEUE
echo PROCS: $PROCS
echo NODE_NAME: $NODE_NAME
echo SUBDR: $SUBDR
echo inputfile1: $inputfile1
echo inputfile2: $inputfile2
echo inputfile3: $inputfile3
echo inputfile4: $inputfile4

mkdir -p /home11/mmiller/Wyeomyia/output/velvet_out/velveth_maxfq-$3K_minfq-$4_k$5/$SUBDR; \
qsubmit.rb \
"mkdir -p /scratch/$USER/\$PBS_JOBID && \
cp $1 /scratch/$USER/\$PBS_JOBID/ && \
cp $2 /scratch/$USER/\$PBS_JOBID/ && \
cp $6 /scratch/$USER/\$PBS_JOBID/ && \
cp $7 /scratch/$USER/\$PBS_JOBID/ && \
mkdir -p /scratch/$USER/\$PBS_JOBID/velvet_out/velveth_maxfq-$3K_minfq-$4_k$5/$SUBDR/ && \
velveth /scratch/$USER/\$PBS_JOBID/velvet_out/velveth_maxfq-$3K_minfq-$4_k$5/$SUBDR $5 -shortPaired -separate -fastq /scratch/$USER/\$PBS_JOBID/$inputfile1 /scratch/$USER/\$PBS_JOBID/$inputfile2 -short /scratch/$USER/\$PBS_JOBID/$inputfile3 /scratch/$USER/\$PBS_JOBID/$inputfile4 -create_binary ; \
rm -f /scratch/$USER/\$PBS_JOBID/$inputfile1 ; \
rm -f /scratch/$USER/\$PBS_JOBID/$inputfile2 ; \
rm -f /scratch/$USER/\$PBS_JOBID/$inputfile3 ; \
rm -f /scratch/$USER/\$PBS_JOBID/$inputfile4" \
-q $QUEUE -j vlvth_$3-$4_k$5 -p $PROCS -m velvet
