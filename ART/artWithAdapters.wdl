workflow artModified {

    File reference_1
    Int length
    Int coverage
    Int size
    Int deviation
    String name
    String reads_folder

    call art_illumina { 
        input:
            reference_1 = reference_1, 
	    length = length,
	    coverage = coverage,
	    dna_size = size,
	    deviation = deviation,
	    name = name
	
    }

    call copy as copy_simulated_reads {
        input:
            files = [art_illumina.reads_1, art_illumina.reads_2, art_illumina.readsSAM],
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
		
    command {
        art_illumina --in ${reference_1} --paired --len ${length} --fcov ${coverage} --mflen ${dna_size} --sdev ${deviation} --out ${name} -sam -na
   }

    runtime {
        docker: "vlr37/art_modified@sha256:50adcf35e76549ec63d05721b1550c638cb21cc97605647a40192113ceb9903c"
    }

    output {
        File reads_1 = name + "1.fq"
        File reads_2 = name + "2.fq"
        File readsSAM = name + ".sam"
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

		
