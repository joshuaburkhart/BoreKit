#!/usr/bin/ruby

require 'time'
require 'optparse'

INVALID_COMMANDS = ""

options = {}
optparse = OptionParser.new { |opts|
    opts.banner = <<-EOS
Usage: ruby qvelvet.rb -p </path/to/shortpaired/file/1.fastq>,</path/to/shortpaired/file/2.fastq> -s </path/to/short/unpaired/file/1.fastq>,</path/to/short/unpaired/file/n.fastq> -k <kmer hash length> -e <expected coverage> -m <min contig length> -i <insertion seq size estimate> -c <minimum coverage cutoff threshold> -x <maximum coverage cutoff threshold> -o </path/to/output/dir>

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
    options[:interleaved] = nil
    opts.on('-l','--leaved','Paired ends are interleaved') {
        options[:interleaved] = true
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
    options[:min_contig_length] = 500
    opts.on('-m','--min_ctg LENGTH','Minimum contig length to produce') {|min_contig_length|
        options[:min_contig_length] = min_contig_length
    }
    options[:ins_length] = 500
    opts.on('-i','--ins LENGTH','Instertion sequence length estimate') {|ins_length|
        options[:ins_length] = ins_length
    }
    options[:cov_cutoff] = 2
    opts.on('-c','--cov_cut THRESHOLD','Minimum coverage cutoff threshold') {|cov_cutoff|
        options[:cov_cutoff] = cov_cutoff
    }
    options[:max_coverage] = 1000
    opts.on('-x','--max THRESHOLD','Maximum coverage cutoff threshold') {|max_coverage|
        options[:max_coverage] = max_coverage
    }
    options[:queue] = "longfat"
    opts.on('-q','--queue QUEUE','ACISS queue for submission') {|queue|
        options[:queue] = queue
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
    filename.match(/^.*\/([\w\._-]+)$/)
    return $1
end

out_subdir = "velvet_out/velvet"
if(options[:pe_files].nil? && options[:se_files].nil?)
    puts "Read file(s) must be specified with '-p' or '-s'"
    puts "Aborting..."
    exit
elsif(options[:pe_files].nil?)
    tmp = options[:se_files]
elsif(options[:se_files].nil?)
    tmp = options[:pe_files]
else
    tmp = options[:pe_files] + options[:se_files]
end
tmp.each {|f|
    out_subdir = "#{out_subdir}-#{extractName(f)}"
}
out_subdir = "#{out_subdir}_k=#{options[:kmer_hash_length]}_e=#{options[:expected_cov]}"
%x(mkdir -p #{options[:out_dir]}/#{out_subdir})
puts "Using local output directory #{options[:out_dir]}/#{out_subdir}"

local_pe_files = ""
remote_pe_files = ""
if(!options[:pe_files].nil?)
    options[:pe_files].each {|f|
        local_pe_files = "#{local_pe_files} #{f}"
        remote_pe_files = "#{remote_pe_files} /scratch/$USER/\\$PBS_JOBID/#{extractName(f)}"
    }
    pe_arg = "-shortPaired -separate #{remote_pe_files}"
    if(options[:interleaved])
        pe_arg = "-shortPaired #{remote_pe_files}"
    end
end
local_se_files = ""
remote_se_files = ""
if(!options[:se_files].nil?)
    options[:se_files].each {|f|
        local_se_files = "#{local_se_files} #{f}"
        remote_se_files = "#{remote_se_files} /scratch/$USER/\\$PBS_JOBID/#{extractName(f)}"
    }
end

velvet_command = <<-EOF1
mkdir -p /scratch/$USER/\\$PBS_JOBID && \
cp #{local_pe_files} #{local_se_files} /scratch/$USER/\\$PBS_JOBID/ && \
mkdir -p /scratch/$USER/\\$PBS_JOBID/#{out_subdir} && \
velveth /scratch/$USER/\\$PBS_JOBID/#{out_subdir} #{options[:kmer_hash_length]} -short -fastq #{remote_se_files} #{pe_arg} -create_binary && \
velvetg /scratch/$USER/\\$PBS_JOBID/#{out_subdir} -min_contig_lgth #{options[:min_contig_length]} -ins_length #{options[:ins_length]} -exp_cov #{options[:expected_cov]} -cov_cutoff #{options[:cov_cutoff]} -max_coverage #{options[:max_coverage]} ; \
rm -f #{remote_se_files} #{remote_pe_files}
EOF1

print "Locating capable node..."
avail_nodes = []
num_minutes = 0
selected_node = 0
while(avail_nodes.length == 0)
    avail_nodes = %x((echo ! && qnodes) | tr '\n' '!' | grep -Po '(?<=!)\s*fn[2-8]+(?=\s*!\s*state = [^!]*free[^!]*!)').split(/\n/)
    if(avail_nodes.length == 0)
        print "."
        STDOUT.flush
        sleep(60)
        num_minutes += 1
    else
        selected_node = srand() % avail_nodes.length
        print "Assigned node #{avail_nodes[selected_node]} after #{num_minutes} minute wait."
        STDOUT.flush
    end
end
puts

submit_args = <<-EOF
-m velvet -j velvet_k=#{options[:kmer_hash_length]}_e=#{options[:expected_cov]} -q #{options[:queue]} -n #{avail_nodes[selected_node]} -p 32 "#{velvet_command}"
EOF

stdout = %x(qsubmit.rb #{submit_args})

puts "#{stdout}"
