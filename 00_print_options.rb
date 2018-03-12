# 00_print_options
# called from main.rb
# a part of ruby-aws-microservice
#
# Author: Cody Tubbs (codytubbs@gmail.com) 2017-05-07
#         https://github.com/codytubbs
#
# rubocop:disable LineLength # Comment to rid length warnings from `rubocop'

def example_usages(opt_parser)
  puts opt_parser
  puts "\nExamples:"
  puts '(Required parameters: <launch> or <cleanup>)'
  puts "Usage #1: #{$PROGRAM_NAME} launch"
  puts "Usage #3: #{$PROGRAM_NAME} --creds-profile=cody --region=us-east-1 launch\n\n"
end

def get_opts(credentials_file, ubuntu_ami_map)
  options = { creds_profile: 'default',
              #nat_type: 'instance',
              #bastion_host: false,
              #ssh_access: false,
              #lb_type: 'both',
              region: 'us-west-2',
              vpc_id: nil }

  opt_parser = OptionParser.new do |opts|
    opts.banner = "\nUsage: #{$PROGRAM_NAME} [options] <launch|cleanup>"

    opts.on('-c', '--creds-profile=name', "default: 'default'   "\
          "[options: valid profile in: #{credentials_file}]") do |cp|
      options[:creds_profile] = cp
    end

    opts.on('-r', '--region=name', "default: 'us-west-2' "\
          "[options: us-east-1, eu-west-2, ca-central-1, etc.]") do |region|
      if ubuntu_ami_map.key?(region)
        options[:region] = region
      else
        puts "Error: the chosen region [#{region}] doesn't seem to be valid."
        exit 0
      end

    end

    #opts.on('-l', '--lb-type=both', "default: 'both'      "\
    #      "[options: 'application', 'classic' or 'both']") do |lb|
    #  if lb.downcase !~ /\Aapplication\z|\Aclassic\z|\Aboth\z/
    #    puts "Error: Invalid load balancer type: '#{lb}', must be 'application', 'classic' or 'both'"
    #    exit 0
    #  end
    #  options[:lb_type] = lb
    #end

    opts.on('-v', '--vpc=ID', "default: NONE        "\
          "[REQUIRED if <cleanup> is called]") do |vpc|
      options[:vpc_id] = vpc
    end

    #opts.on('-n', '--nat-type=instance', "default: 'instance'  "\
    #      "[options: 'instance' or 'gateway']") do |nat|
    #  if nat.downcase !~ /\Ainstance\z|\Agateway\z/
    #    puts "Error: Invalid nat type: '#{nat}', must be 'instance' or 'gateway'"
    #    exit 0
    #  end
    #  options[:nat_type] = nat
    #end

    #opts.on('-s', '--ssh-access=false', "default: 'false'     "\
    #      "[options: 'true' or 'false']") do |ssh|
    #  if ssh.downcase !~ /\Atrue\z|\Afalse\z/
    #    puts "Error: Invalid ssh access setting: '#{ssh}', must be 'true' or 'false'"
    #    exit 0
    #  end
    #  options[:ssh_access] = ssh
    #end

    #opts.on('-b', '--bastion-host=false', "default: 'false'     "\
    #      "[options: 'true' or 'false']") do |bastion|
    #  if bastion.downcase !~ /\Atrue\z|\Afalse\z/
    #    puts "Error: Invalid bastion setting: '#{bastion}', must be 'true' or 'false'"
    #    exit 0
    #  else
    #    if options[:ssh_access] == false
    #      puts "the --ssh-access flag must be set to 'true' to use a bastion host, it is currently set to 'false'"
    #      exit 0
    #    end
    #  end

    #  options[:bastion_host] = bastion
    #end

    opts.on_tail('-h', '--help', 'Displays these command-line options and usage examples') do
      puts opts
      exit 0
    end
  end
  opt_parser.parse!

  if File.exist?(credentials_file.to_s)
    if options[:creds_profile] == 'default'
      # puts "The 'default' credentials in '#{credentials_file}' will be used unless specified otherwise."
    end
  else
    puts opt_parser
    puts
    puts "Error: Credentials file '#{credentials_file}' was not found, please create accordingly:"
    puts '[default]'
    puts 'aws_access_key_id = xxx'
    puts 'aws_secret_access_key = xxx'
    puts
    exit 0
  end

  if ARGV.empty?
    example_usages(opt_parser)
  else
    puts
    # TODO: Check if a default profile exists in the file... error otherwise
    puts "Using profile: [#{options[:creds_profile]}] from credentials file: '#{credentials_file}'"
    puts
    if ARGV[0] !~ /\Alaunch\z|\Acleanup\z/
      example_usages(opt_parser)
      exit 0
    end
  end

  if ARGV[0] =~ /\Acleanup\z/
    if options[:vpc_id].nil?
      example_usages(opt_parser)
      puts 'Error: you need to specify a VPC id if cleanup is requested.'
      exit 0
    end
    if options[:vpc_id] !~ /vpc-[a-z\d]{8,8}/
      example_usages(opt_parser)
      puts 'Error: the VPC id specified for cleanup has an incorrect format.'
      exit 0
    end
  end
  return options, ARGV[0]
end
