workflow sommut_workflow {
    File reads_1_trimming
    File reads_2_trimming
    Int threads
    Int num_forks
    String adapter_1_trimming
    String adapter_2_trimming
    String annotation_name
    String results_folder
    String annotation_folder
    String important_name
    String phenotypes_name
    String gwas_name
    File reference
    File referencefai
    File referencedict

    call report as initial_report_1_call {
      input:
        sampleName = basename(reads_1_trimming, ".fastq.gz"),
        file = reads_1_trimming
      }

    call report as initial_report_2_call {
      input:
        sampleName = basename(reads_2_trimming, ".fastq.gz"),
        file = reads_2_trimming
      }

    call atropos_illumina_trim_task as atropos_illumina_trim_call {
      input:
        reads_1_trimming = reads_1_trimming,
        reads_2_trimming = reads_2_trimming,
        adapter_1_trimming = adapter_1_trimming,
        adapter_2_trimming = adapter_2_trimming,
        threads = threads
    }

    call report as final_report_1_call {
        input:
          sampleName = basename(atropos_illumina_trim_call.out1, ".fastq.gz"),
          file = atropos_illumina_trim_call.out1
    }

    call report as final_report_2_call {
        input:
          sampleName = basename(atropos_illumina_trim_call.out2, ".fastq.gz"),
          file = atropos_illumina_trim_call.out2
        }

    call minimap2_task as minimap2_call {
            input:
                reads_1 = atropos_illumina_trim_call.out1,
                reads_2 = atropos_illumina_trim_call.out2,
                reference = reference
    }

    call samtools_conversion_task as samtools_conversion_call {
        input:
            sam = minimap2_call.out1
    }

    call picard_readgroups_sort_task as picard_readgroups_sort_call {
            input:
                bam = samtools_conversion_call.out
    }

    call picard_validation_task as picard_validation_call {
            input:
                bam = picard_readgroups_sort_call.out
    }

    call picard_indexbam_task as picard_indexbam_call {
            input:
                bam = picard_readgroups_sort_call.out
    }

    call mutect2_task as mutect2_call {
        input:
            bam = picard_readgroups_sort_call.out,
            bai = picard_indexbam_call.out,
            reference = reference,
            referencefai = referencefai,
            referencedict = referencedict
    }

    call vep_annotation {
        input:
            snp_result = mutect2_call.out,
            result_name = annotation_name,
            num_forks = num_forks
    }

    call vep_filter_important {
        input:
            full_annotation = vep_annotation.out,
            filter_name = important_name
    }

    call find_phenotypes {
        input:
            annotated_file = vep_filter_important.out,
            name = phenotypes_name
    }

    call find_OR {
        input:
            phenotypes = find_phenotypes.out,
            name = gwas_name    
    }

    call copy as copy_mutect {
        input:
            files = mutect2_call.out,
            destination = results_folder
    }

    call copy as copy_trimmed {
        input:
            files = [atropos_illumina_trim_call.out1, atropos_illumina_trim_call.out2],
            destination = results_folder + "/trimmed/"
    }

    call copy as copy_initial_quality_reports {
        input:
            files = [initial_report_1_call.out, initial_report_2_call.out],
            destination = results_folder + "/quality/initial/"
    }

    call copy as copy_cleaned_quality_reports {
        input:
            files = [final_report_1_call.out, final_report_2_call.out],
            destination = results_folder + "/quality/cleaned/"
    }

    call copy_annotated_files {
        input:
            files = [vep_annotation.out, vep_annotation.summary, vep_filter_important.out, find_phenotypes.out, find_OR.out],
            destination = annotation_folder 
    }

}


task atropos_illumina_trim_task {
    File reads_1_trimming
    File reads_2_trimming
    Int threads
    String adapter_1_trimming
    String adapter_2_trimming

    command {
        atropos trim \
        -a ${adapter_1_trimming} \
        -A ${adapter_2_trimming} \
        -pe1 ${reads_1_trimming} \
        -pe2 ${reads_2_trimming} \
        -o ${basename(reads_1_trimming, ".fastq.gz")}_trimmed.fastq.gz \
        -p ${basename(reads_2_trimming, ".fastq.gz")}_trimmed.fastq.gz \
        --minimum-length 35 \
        --aligner insert \
        -q 18 \
        -e 0.1 \
        --threads ${threads} \
        --correct-mismatches liberal
    }

    runtime {
        docker: "jdidion/atropos@sha256:c2018db3e8d42bf2ffdffc988eb8804c15527d509b11ea79ad9323e9743caac7"
    }

    output {
        File out1 = basename(reads_1_trimming, ".fastq.gz") + "_trimmed.fastq.gz"
        File out2 = basename(reads_2_trimming, ".fastq.gz") + "_trimmed.fastq.gz"
    }
}

task minimap2_task {
    File reads_1
    File reads_2
    File reference

    command {
        minimap2 \
        -ax \
        sr \
        -L \
        ${reference} \
        ${reads_1} \
        ${reads_2} \
        > aln.sam
    }

    runtime {
        docker: "genomicpariscentre/minimap2@sha256:536d7cc40209d4fd1b700ebec3ef9137ce1d9bc0948998c28b209a39a75458fa"
      }
    output {
      File out1 = "aln.sam"
    }
}

task samtools_conversion_task {
    File sam
    command {
        samtools \
        view \
        -bS \
        ${sam} \
        > aln.bam
    }
    runtime {
        docker: "biocontainers/samtools@sha256:fbda13f53abb21ffb5859492c063c13cc3d9b7b5f414b1c31ccc2a48109abfee"
    }
    output {
        File out = "aln.bam"
    }
}
task picard_readgroups_sort_task {
    File bam
    command {
        picard AddOrReplaceReadGroups \
        I= ${bam} \
        O= aln2.bam \
        RGID=4 \
        RGLB=lib1 \
        RGPL=illumina \
        RGPU=unit1 \
        RGSM=20 \
	SORT_ORDER=coordinate
    }

    runtime {
        docker: "biocontainers/picard@sha256:1dc72c0ffb8885428860fa97e00f1dd868e8b280f6b7af820a0418692c14ae00"
    }
    output {
        File out = "aln2.bam"
    }
}

task picard_validation_task {
    File bam
    command {
        picard ValidateSamFile \
        I=${bam} \
        O=log.txt \
        MODE=SUMMARY
    }

    runtime {
        docker: "biocontainers/picard@sha256:1dc72c0ffb8885428860fa97e00f1dd868e8b280f6b7af820a0418692c14ae00"
    }
    output {
        File out = "log.txt"
    }
}

task picard_indexbam_task {
    File bam
    command {
        picard BuildBamIndex \
        INPUT=${bam} \
    }

    runtime {
        docker: "biocontainers/picard@sha256:1dc72c0ffb8885428860fa97e00f1dd868e8b280f6b7af820a0418692c14ae00"
    }

    output {
        File out = "aln2.bai"
    }
}

task mutect2_task {
    File bam
    File bai
    File reference
    File referencefai
    File referencedict
    command {
        java -jar /usr/GenomeAnalysisTK.jar \
        -T MuTect2 \
        -R ${reference} \
        -I:tumor ${bam} \
        -nct 7 \
        --artifact_detection_mode \
        -o variants.vcf
    }

    runtime {
        docker: "broadinstitute/gatk3:3.8-0@sha256:523f2c94c692c396157e50a2600ba5dfc392c8281f760445412d3daf031e846a"
    }

    output {
        File out = "variants.vcf"
    }
}

task report {
    String sampleName
    File file
    command {
      /opt/FastQC/fastqc ${file} -o .
    }

    runtime {
        docker: "quay.io/ucsc_cgl/fastqc@sha256:86d82e95a8e1bff48d95daf94ad1190d9c38283c8c5ad848b4a498f19ca94bfa"
    }
    output {
        File out = sampleName+"_fastqc.zip"
    }
}

task copy {
    Array[File] files
    String destination
    command {
        mkdir -p ${destination}
        cp -L -R -u ${sep=' ' files} ${destination}
    }
    output {
        Array[File] out = files
    }
}

task vep_annotation {
    File snp_result
    String result_name
    Int num_forks

    command {
        vep \
        -i ${snp_result} --cache --dir_cache /home/vep/.vep --flag_pick_allele --sift b --polyphen b --gene_phenotype --uniprot --symbol --protein --pubmed --biotype --ccds --check_existing --canonical --plugin Condel,/home/vep/.vep/Plugins/config/Condel/config,b --tab --output_file ${result_name}.gz --compress_output gzip --fork ${num_forks}     
    }
    
    runtime {
        docker: "vlr37/vepcon38@sha256:aa72ec1030cc35bb83187aa06d8abb70b463d7755ec56d093d76b00e9c3b63af"
    }

    output {
        File out = "${result_name}.gz"
        File summary = "${result_name}.gz" + "_summary.html"
    }
}

task vep_filter_important {
    File full_annotation
    String filter_name
  
    command {
        filter_vep -i ${full_annotation} --gz -output_file ${filter_name} --filter "SIFT < 0.05 or CLIN_SIG != benign or PolyPhen > 0.446 and PHENO and PICK = 1"
    }
 
    runtime {
        docker: "vlr37/vepcon38@sha256:aa72ec1030cc35bb83187aa06d8abb70b463d7755ec56d093d76b00e9c3b63af"
    }

    output {
        File out = "${filter_name}"
    }
}

task find_phenotypes {
    File annotated_file
    String name

    command {
        python /tmp/phenotypes38.py ${annotated_file} ${name}.tsv
    }

    runtime {
        docker: "vlr37/phenofinder:latest@sha256:83ea852f0fb3e82dc9c2bd7cc327fe2009b934806b5f5c4c2b1c017eb88ea01d"
    }

    output {
        File out = "${name}.tsv"
    }
}

task find_OR {
    File phenotypes
    String name

    command {
        python /tmp/gwas_OR.py ${phenotypes} ${name}.tsv
    }

    runtime {
        docker: "vlr37/phenofinder:latest@sha256:83ea852f0fb3e82dc9c2bd7cc327fe2009b934806b5f5c4c2b1c017eb88ea01d"
    }

    output {
        File out = "${name}"
    }
}

task copy_annotated_files {
    Array[File] files
    String destination

    command {
        mkdir -p ${destination}
        cp -L -R -u ${sep=' ' files} ${destination}
    }
  
    output {
        Array[File] out = files
    }
}

