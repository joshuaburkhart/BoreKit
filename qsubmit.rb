#!/usr/bin/ruby

require 'time'
require 'optparse'

TEST = %x(qsub --version 2>&1)
if(TEST.include?("command not found"))
    puts "The qsub command must be installed for this program to run."
    puts "Aborting..."
    exit
end

VALID_QUEUES = ["generic","gpu","fatnodes","student","longgen","longgpu","longfat","xlonggen","xlonggpu","xlongfat"]

VALID_NODES = %x((echo ! && qnodes) | tr '\n' '!' | grep -Po '(?<=!)\s*[a-z]+[0-9]+(?=\s*!\s*state = [^!]*free[^!]*!)').split(/\n/)

INVALID_COMMANDS = ""

options = {}
optparse = OptionParser.new { |opts|
    opts.banner = <<-EOS
Usage: ruby qsubmit.rb -p <cores> -q <queue name> -j <job name> -n <node name> -m <modules to load> -o <output directory> [command <command options>]

Example:
    EOS
    opts.on('-h','--help','Display this screen'){
        puts opts
        exit
    }
    options[:cores] = 1
    opts.on('-p','--procs CORES','Number of Processor Cores CORES') { |cores|
        if(Integer(cores) >= 1 && Integer(cores) <= 32)
            options[:cores] = cores
        else
            puts "INVALID CORES '#{cores}' MUST BE >= 1 AND <=32"
            exit
        end
    }
    options[:qname] = nil
    opts.on('-q','--queue QNAME','Name of submission queue QNAME') { |qname|
        if(VALID_QUEUES.include?(qname))
            options[:qname] = qname
        else
            puts "INVALID QNAME '#{qname}' NOT FOUND IN #{VALID_QUEUES.inspect}"
            exit
        end
    }
    options[:jname] = "qsubmit_job"
    opts.on('-j','--job JNAME','Name of submission job JNAME') { |jname|
        options[:jname] = jname
    }
    options[:nname] = nil
    opts.on('-n','--node NNAME','Name of submission node NNAME') { |nname|
        if(VALID_NODES.include?(nname))
            options[:nname] = nname
        else
            puts "INVALID NNAME '#{nname}' NOT FOUND IN #{VALID_NODES.inspect}"
            exit
        end
    }
    options[:modules] = nil
    opts.on('-m','--mods MODULE1,MODULE2,MODULEN',Array,'Modules to load - List CSVs') { |modules|
        options[:modules] = modules
    }
    options[:out_dir] = "/home11/mmiller/Wyeomyia/output/queue_out/"
    opts.on('-o','--out OUT_DIR','Output Directory OUT_DIR') { |out_dir|
        if(File.exists? out_dir)
            if(!File.directory? out_dir)
                out_dir = "#{out_dir}_dir"
            end
        else
            %x(mkdir -p #{out_dir})
        end
        options[:out_dir] = out_dir
    }
    options[:nas_dir] = "/home11/mmiller/Wyeomyia/output/"
    opts.on('-s','--nas NAS_DIR','NAS Storage Directory NAS_DIR') { |nas_dir|
        if(File.exists? nas_dir)
            if(!File.directory? nas_dir)
                nas_dir = "#{nas_dir}_dir"
            end
        else
            %x(mkdir -p #{nas_dir})
        end
        options[:nas_dir] = nas_dir
    }
}

optparse.parse!

command = ARGV.join(' ')
if(INVALID_COMMANDS.include?(command))
    puts "INVALID COMMAND '#{command}'"
    exit
end
if(options[:qname].nil?)
    if(!options[:nname].nil?)
        puts "MUST SPECIFY QUEUE FOR NODE '#{options[:nname]}'"
        exit
    end
    options[:qname] = Integer(options[:cores]) <= 12 ? "generic" : "fatnodes"
end
node_spec = options[:nname].nil? ? "1" : options[:nname]
module_spec = options[:modules].nil? ? "" : options[:modules].join(' ')

pbs_script = <<-EOF
#!/bin/bash -l
#PBS -N #{options[:jname]}
#PBS -o #{options[:out_dir]}
#PBS -e #{options[:out_dir]}
#PBS -d #{options[:out_dir]}
#PBS -l nodes=#{node_spec}:ppn=#{options[:cores]}
#PBS -q #{options[:qname]}
#PBS -p 1023
mkdir -p /tmp/$USER/\$PBS_JOBID
mkdir -p /scratch/$USER/\$PBS_JOBID
module load #{module_spec}
#{command}
/bin/cp -a /tmp/$USER/\$PBS_JOBID/* #{options[:nas_dir]}
/bin/cp -a /scratch/$USER/\$PBS_JOBID/* #{options[:nas_dir]}
/bin/rm -rf /tmp/$USER/\$PBS_JOBID
/bin/rm -rf /scratch/$USER/\$PBS_JOBID
EOF

pbs_file_name = "#{Integer(Time.now)}.sh"
pbs_file_handle = File.open(pbs_file_name,'w')
pbs_file_handle.print(pbs_script)
pbs_file_handle.close

%x(qsub #{pbs_file_name})
%x(rm #{pbs_file_name})

#printing job details
puts
puts "Command: #{command}"
puts "Cores: #{options[:cores]}"
puts "Queue: #{options[:qname]}"
puts "Job Name: #{options[:jname]}"
if(!options[:nname].nil?)
    puts "Node: #{options[:nname]}"
end
if(!options[:modules].nil?)
    puts "Modules: #{options[:modules].join(', ')}"
end
puts "Output Directory: #{options[:out_dir]}"
puts "NAS Storage Directory: #{options[:nas_dir]}"
puts "Job Submission Completed at #{Time.now}."
