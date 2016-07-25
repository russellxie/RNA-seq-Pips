#!/bin/tcsh

#SBATCH -J STAR_map1                   # job name
#SBATCH -p super                      # queue (partition) -- super, 128GB, 256GB, 384GB
#SBATCH -N 1                          # number of nodes
#SBATCH -t 0-4:00:00                 # run time (hh:mm:ss)
#SBATCH --mail-user=sh1iqi.xie@dtsouthwestern.edu
#SBATCH --mail-type=end               # email me when the job begins, ends, fails
#SBATCH -o map.out.%j       # output file name (%j expands to jobID, %a to array id)
#SBATCH -e map.err.%j       # error file name  (%j expands to jobID, %a to array id)

echo "hello world"
module load samtools
module load bedtools
modele load iGenomes

set STAR = /home2/s160875/lab/projects/shared/software/STAR-STAR_2.4.2a/source/STAR
set GENOME_INDEX = /home2/s160875/lab/projects/shared/data/indices/STAR/old/hg19-lentiCRISPRv2
set FILE = /project/GCRB/Hon_lab/shared/data/sequencing_data/2016/2016-06-02-Mcdermott-NextSeq/RNA-Seq
set run_name = Run14

mkdir ./bam_files/

foreach sample (\
		PZ341_S15\
               )
   echo $sample
  foreach lane (L001 L002 L003 L004)
  $STAR\
    --runThreadN $SLURM_CPUS_ON_NODE\
    --genomeDir $GENOME_INDEX\
    --readFilesIn $FILE/$sample\_$lane\_R1\_001.fastq.gz $FILE/$sample\_$lane\_R2\_001.fastq.gz\
    --readFilesCommand zcat\
    --outFileNamePrefix $sample.$lane.\
    --outSAMtype BAM SortedByCoordinate
  end

  samtools merge -f ./bam_files/$sample.bam\
		    $sample.L001.Aligned.sortedByCoord.out.bam\
		    $sample.L002.Aligned.sortedByCoord.out.bam\
		    $sample.L003.Aligned.sortedByCoord.out.bam\
		    $sample.L004.Aligned.sortedByCoord.out.bam

    rm $sample.L00*Aligned.sortedByCoord.out.bam

    set MARK_DUP = /cm/shared/apps/picard/1.117/MarkDuplicates.jar

    mkdir nodup_files

    java -Xmx128g -jar $MARK_DUP\
    INPUT=./bam_files/$sample.bam\
    OUTPUT=./nodup_files/$sample.nodup.bam\
    METRICS_FILE=./nodup_files/metrics.$sample.txt\
    REMOVE_DUPLICATES=true\
    ASSUME_SORTED=true\
    TMP_DIR=temp_dir.$sample

    samtools view\
	-q10\
	-b ./nodup_files/$sample.nodup.bam\
	-o ./nodup_files/$sample.nodup.filtered.bam

    samtools index ./nodup_files/$sample.nodup.filtered.bam

    mkdir bw_files

    set GENOME = /project/GCRB/Hon_lab/shared/data/indices/STAR/hg19-lentiCRISPRv2/combined_genome.fa.fai

    bedtools genomecov\
	-bga\
	-split\
	-ibam ./nodup_files/$sample.nodup.filtered.bam\
	-g $GENOME\
	> ./bw_files/$sample.bedgraph

    cat ./bw_files/$sample.bedgraph\
      | grep -v chrL\
      | perl -ne '@a = split(/\t/, $_); if($a[3] > 0){print;}'\
      > ./bw_files/$sample.bedgraph.processed
   
    module load UCSC_userApps/v317

    sort -k1,1 -k2,2n ./bw_files/$sample.bedgraph.processed\
		      > ./bw_files/$sample.bedgraph.processed.sorted
		      
    bedGraphToBigWig ./bw_files/$sample.bedgraph.processed.sorted\
		     $GENOME_INDEX/chrNameLength.txt\
                     ./bw_files/$sample.bw

end

