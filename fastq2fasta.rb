#!/usr/bin/ruby

require 'optparse'

options ={}
optparse = OptionParser.new { |opts|
    opts.banner = <<-EOS
Usage: fastq2fasta.rb <path/to/fastq/filename> <sequence identifier>

Example: fastq2fasta.rb /home11/mmiller/Wyeomyia/reads/combined/wy_prefiltered_reads.fastq @HWI-72047
    EOS
    opts.on('-h','--help','Display this screen'){
        puts opts
        exit
    }
    options[:seq_id] = nil
    opts.on('-i','--id SEQ_ID','The identifier for the sequences in this fastq file SEQ_ID') { |seq_id|
        options[:seq_id] = seq_id
    }
    options[:fastq] = nil
    opts.on('-q','--fastq IN_FILE','The fastq file to be converted IN_FILE') { |in_file|
        options[:fastq] = in_file
    }
    options[:fasta] = nil
    opts.on('-o','--out OUT_FILE','The file name for fasta output OUT_FILE') { |out_file|
        options[:fasta] = out_file
    }
    options[:allow_Ns] = true
    opts.on('-u','--uncalled','Check for uncalled bases (Ns)') {
        options[:allow_Ns] = false
    }
}

optparse.parse!
if(options[:fastq].nil?)
    raise OptionParser::MissingArgument, "fastq file = \'#{options[:fastq]}\'"
end

fasta_filename = nil
if(options[:fasta].nil?)
    options[:fastq].match(/^(.*?\w+?)\.\w+$/)
    fasta_filename = "#{$1}-fastq2.fasta"
else
    fasta_filename = options[:fasta]
end
fasta_filehandl = File.open(fasta_filename,"w")

line_num = 0
valid = true

def printError(line_num,exp_format,line)
    puts "LINE #{line_num} INCORRECTLY FORMATTED:"
    puts "Expected: #{exp_format}"
    puts "Actual: '#{line}'"
    return false
end

File.open(options[:fastq],"r") do |fastq_file|
    while fastq_file_line = fastq_file.gets

        line_num += 1
        sequence_id = fastq_file_line
        if(options[:seq_id].nil?)
            print "SEQUENCE ID NOT SPECIFIED..."
            if(sequence_id.match(/^(@.+?):.*$/))
                puts "USING #{$1}"
                options[:seq_id] = $1
            else
                puts "UNABLE TO FIND VALID SEQUENCE ID"
                raise OptionParser::MissingArgument, "sequence id = \'#{options[:seq_id]}\'"
            end
        end
        valid = sequence_id.match(/^#{options[:seq_id]}.*$/) ? (valid && true) : printError(line_num,"^#{options[:seq_id]}.*$",fastq_file_line)

        #TODO
        #take two pe files and discard both reads on appearance of an N in either of them
        line_num += 1
        bases = fastq_file_line = fastq_file.gets
        if(options[:allow_Ns])
            valid = bases.match(/^[ATCGN]+$/) ? (valid && true) : printError(line_num,"^[ATCGN]+$",fastq_file_line)
        else
            valid = bases.match(/^[ATCG]$/) ? (valid && true) : printError(line_num,"^[ATCG]+$",fastq_file_line)
        end

        line_num += 1
        plus = fastq_file_line = fastq_file.gets
        valid = plus.match(/^\+.*$/) ? (valid && true) : printError(line_num,"^\+.*$",fastq_file_line)

        line_num += 1
        quality_score = fastq_file_line = fastq_file.gets

        if(valid)
            fasta_filehandl.print ">#{sequence_id}"
            fasta_filehandl.print bases
        else 
            puts "Aborting..."
            fasta_filehandl.close
            %x(rm -f #{fasta_filename})
            exit
        end
    end
    fasta_filehandl.puts
    fasta_filehandl.close
end

