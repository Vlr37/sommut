workflow artIllumina {

    File reference_1
    Int length
    Int coverage
    Int size
    Int deviation
    String name
    String type
    String reads_folder
    Int threads

    call art_illumina { 
        input:
            reference_1 = reference_1, 
	    length = length,
	    coverage = coverage,
	    dna_size = size,
	    deviation = deviation,
	    name = name,
            sequenceSystem = type
	
    } 

    call convert {
        input:
            sam = art_illumina.readsSAM,
            name = name,
            threads = threads,
            reference_1 = reference_1
    }  

    call copy as copy_simulated_reads {
        input:
            files = [art_illumina.reads_1, art_illumina.reads_2, art_illumina.readsSAM, convert.convertedInBAM],
            destination = reads_folder 
    }      
}

task art_illumina {
    
    File reference_1
    Int length
    Int coverage
    Int dna_size
    Int deviation
    String name
    String sequenceSystem
		
    command {
        art_illumina -ss ${sequenceSystem} -sam --in ${reference_1} --paired --len ${length} --fcov ${coverage} --mflen ${dna_size} --sdev ${deviation} --out ${name} -na
   }

    runtime {
        docker: "vlr37/art_illumina@sha256:0f29e10f66207e7a8c54bae6d276f41d1aad6877e9fb56e2e78c6daf98eab8c0"
    }

    output {
        File reads_1 = name + "1.fq"
        File reads_2 = name + "2.fq"
        File readsSAM = name + ".sam"
    }
}

task convert {
    File sam
    File reference_1
    String name
    Int threads

    command {
        samtools view -bT ${reference_1} ${sam} | samtools sort - -@ ${threads} -o ${name}.bam
    }

    runtime {
        docker: "quay.io/comp-bio-aging/samtools@sha256:7471dad2bf73d5a5129ab38f61edc55fa964b5f241cab94780b5788ecee1fd42"
    }

    output {
        File convertedInBAM = "${name}.bam"
    }
}

task copy {
    Array[File] files
    String destination

    command {
        mkdir - ${destination}
        cp -L -R -u ${sep=' ' files} ${destination}
    }

    output {
        Array[File] out = files
    }
}   

