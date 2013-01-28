#!/esr/bin/ruby

require 'time'
require 'optparse'




INVALID_COMMANDS = ""

options = {}
optparse = OptionParser.new { |opts|
    opts.banner = <<-EOS
                Usage: ruby qvelvet.rb -p </path/to/shortpaired/file/1.fastq>,</path/to/shortpaired/file/2.fastq> -s </path/to/short/unpaired/file/1.fastq>,</path/to/short/unpaired/file/n.fastq> -k <kmer hash length> -e <expected coverage> -o </path/to/output/dir>

                Example:
    EOS
    opts.on('-h','--help','Display this screen'){
        puts opts
        exit
    }
    options[:pe_files] = nil
    opts.on('-p','--paired PE_FILE1,PE_FILE2',Array,'Paired end files') { |pe_files|
        options[:pe_files] = pe_files
    }
    options[:se_files] = nil
    opts.on('-s','--single SE_FILE1,SE_FILEN',Array,'Single end files') { |se_files|
        options[:se_files] = se_files
    }
    options[:kmer_hash_length] = nil
    opts.on('-k','--kmer HASH_LENGTH','Kmer hash length') { |kmer_hash_length|
        options[:kmer_hash_length] = kmer_hash_length
    }
    options[:expected_cov] = nil
    opts.on('-e','--expected COVERAGE','Expected kmer coverage (Ck)') { |expected_cov|
        options[:expected_cov] = expected_cov
    }
    options[:out_dir] = "/home11/mmiller/Wyeomyia/output"
    opts.on('-o','--out OUT_DIR','Local output directory OUT_DIR') { |out_dir|
        if(File.exists? out_dir)
            if(!File.directory? out_dir)
                out_dir = "#{out_dir}_dir"
            end
        else
            %x(mkdir -p #{out_dir})
        end
        options[:out_dir] = out_dir
    }
}

optparse.parse!

def extractName(filename)
    filename.match(/^.*?([\w_-]+?)\.\w+$/)
    return $1
end

out_subdir = "velvet_out/velvet"
(options[:pe_files] + options[:se_files]).each {|f|
    out_subdir = "#{out_subdir}-#{extractName(f)}"
}
out_subdir = "#{out_subdir}_k=#{options[:kmer_hash_length]}_e=#{options[:expected_cov]}"
%x(mkdir -p #{out_subdir})
puts "Using local output directory #{options[:out_dir]}/#{out_subdir}"

local_pe_files = ""
remote_pe_files = ""
options[:pe_files].each {|f|
    local_pe_files = "#{local_pe_files} #{f}"
    remote_pe_files = "/scratch/$USER/\$PBS_JOBID/#{extractName(f)}"
}
local_se_files = ""
remote_se_files = ""
options[:se_files].each {|f|
    local_se_files = "#{local_se_files} #{f}"
    remote_se_files = "#{remote_se_files} #{extractName(f)}"
}

velvet_command = <<-EOF
mkdir -p /scratch/$USER/\$PBS_JOBID && \
cp #{local_pe_files} #{local_se_files} /scratch/$USER/\$PBS_JOBID/ && \
mkdir -p /scratch/$USER/\$PBS_JOBID/#{out_subdir} && \
velveth /scratch/$USER/\$PBS_JOBID/#{out_subdir} #{options[:kmer_hash_length]} -short -fastq #{remote_se_files} -shortPaired -separate #{remote_pe_files} -create_binary && \
velvetg /scratch/$USER/\$PBS_JOBID/#{out_subdir} -min_contig_lgth #{options[:min_contig_length]} -ins_length #{options[:ins_length]} -exp_cov #{options[:expected_cov]} -cov_cutoff #{options[:cov_cutoff]} -max_coverage #{options[:max_coverage]} ;
rm -f #{remote_se_files} #{remote_pe_files}
EOF

AVAIL_NODES = %x((echo ! && qnodes) | tr '\n' '!' | grep -Po '(?<=!)\s*fn[2-8]+(?=\s*!\s*state = [^!]*free[^!]*!)').split(/\n/)

submit_command = <<-EOF
-m velvet -j velvet_k=#{options[:kmer_hash_length]}_e=#{options[:expected_cov]}" -q longfat -n #{AVAIL_NODES[0]} -p 32 #{velvet_command}"
EOF

stdout = %x(qsubmit.rb #{submit_command})
