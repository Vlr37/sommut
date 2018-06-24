workflow annotation_vep {
    File snp_result
    String name
    String results_folder
    String important_name
    Int num_forks
    
    call vep_annotation {
        input:
            snp_result = snp_result,
            result_name = name,
            num_forks = num_forks
    }
            
   
    call vep_filter_important {
        input:
            full_annotation = vep_annotation.out,
            filter_name = important_name
    }

    call copy {
        input:
            files = [vep_annotation.out, vep_annotation.summary, vep_filter_important.out_2],
            destination = results_folder 
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
        File out_2 = "${filter_name}"
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
        



       
