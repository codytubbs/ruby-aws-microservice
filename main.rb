#!/usr/bin/env ruby
#
# ruby-aws-microservice
#
# ./main.rb -h (for usage)
#
# Author: Cody Tubbs (codytubbs@gmail.com) 2017-05-07
#         https://github.com/codytubbs
#
############################################################################
# Ruby Syntax attempts to follows strict Ruby Style Guidelines
# rubocop:disable LineLength # Comment to rid length warnings from `rubocop'
# rubocop:disable Metrics/ParameterLists

require 'aws-sdk'
require 'aws-sdk-core'
require 'aws-sdk-resources'
require 'optparse'
require 'base64'

require_relative '00_print_options'
require_relative '01_create_vpc'
require_relative '02_create_subnets'
require_relative '03_create_igw'
require_relative '04_create_rtbl_and_routes'
require_relative '05_create_and_setup_SGs'
require_relative '06_launch_nat_instances'
require_relative '07_create_CLB_and_ALB'
require_relative '08_launchconfig_and_asg'
require_relative '99_vpc_complete_cleanup'

credentials_file = "#{ENV['HOME']}/.aws/credentials"

# Updated as of May 2017
ubuntu_ami_map = Hash['ap-northeast-1' => 'ami-afb09dc8',
                      'ap-northeast-2' => 'ami-66e33108',
                      'ap-south-1' => 'ami-c2ee9dad',
                      'ap-southeast-1' => 'ami-8fcc75ec',
                      'ap-southeast-2' => 'ami-96666ff5',
                      'ca-central-1' => 'ami-b3d965d7',
                      'eu-central-1' => 'ami-060cde69',
                      'eu-west-1' => 'ami-a8d2d7ce',
                      'eu-west-2' => 'ami-f1d7c395',
                      'sa-east-1' => 'ami-4090f22c',
                      'us-east-1' => 'ami-80861296',
                      'us-east-2' => 'ami-618fab04',
                      'us-west-1' => 'ami-2afbde4a',
                      'us-west-2' => 'ami-efd0428f']

# Updated as of April 2017
region_az_map = Hash['us-east-1' => %w[a b c d e],
                     'us-east-2' => %w[a b c],
                     'us-west-1' => %w[b c],
                     'us-west-2' => %w[a b c],
                     'ca-central-1' => %w[a b],
                     'eu-west-1' => %w[a b c],
                     'eu-central-1' => %w[a b],
                     'eu-west-2' => %w[a b],
                     'ap-southeast-1' => %w[a b],
                     'ap-southeast-2' => %w[a b c],
                     'ap-northeast-2' => %w[a c],
                     'ap-northeast-1' => %w[a c],
                     'ap-south-1' => %w[a b],
                     'sa-east-1' => %w[a b c]]


response, exec_type = get_opts(credentials_file, ubuntu_ami_map)
creds_profile  = response[:creds_profile]
vpc_id         = response[:vpc_id]
region         = response[:region]
# lb_type      = response[:lb_type]
# nat_type     = response[:nat_type]
# bastion_host = response[:bastion_host]
# ssh_access   = response[:ssh_access]

ami = ubuntu_ami_map[region]
instance_type = 't2.micro' # Free tier suffices for this exercise

availability_zones = [region_az_map[region][0], region_az_map[region][1]]
az1 = region + region_az_map[region][0]
az2 = region + region_az_map[region][1]

creds = Aws::SharedCredentials.new(profile_name: creds_profile)
ec2 = Aws::EC2::Client.new(credentials: creds, region: region)
asg = Aws::AutoScaling::Client.new(credentials: creds, region: region)
elbv1 = Aws::ElasticLoadBalancing::Client.new(credentials: creds, region: region)
elbv2 = Aws::ElasticLoadBalancingV2::Client.new(credentials: creds, region: region)

if exec_type == 'launch'
  # Create new, empty VPC
  vpc = create_vpc(ec2)

  # Create private and public subnets and receive the IDs
  pub_net1, pub_net2, priv_net1, priv_net2 = create_subnets(ec2, region, availability_zones, vpc)

  # Create the Internet Gateway and receive the ID
  igw_id = create_igw(ec2, vpc)

  # Create the private and public route tables, create proper routes and receive the private tbl ID
  priv_rtbl_id = create_rtbl_and_routes(ec2, vpc, igw_id, pub_net1, pub_net2, priv_net1, priv_net2)

  # Create and receive security groups for webservers, nat instances and load balancers
  sg80_priv, sg22_priv, sg22_pub, sg80_nat, sg80_lb = create_and_setup_SGs(ec2, vpc)

  # Launch nat instances in both AZs for private subnet webservers to use for bootstrapping/updates
  launch_nat_instances(ec2, pub_net1, pub_net2, sg22_pub, sg80_nat, priv_rtbl_id, instance_type, ami)

  # Create Classic Load Balancer and define listener and receive the dns name
  clb_dns_name = createCLB(elbv1, sg80_lb, pub_net1, pub_net2)

  # Create Application Load Balancer, listener, and target groups
  # Receive dns name.  Also receive the target group arn for building the ASG
  alb_dns_name, alb_target_group_arn = createALB(elbv2, vpc, sg80_lb, pub_net1, pub_net2)

  # Create launch configuration for nginx service
  launch_configuration(asg, sg80_priv, sg22_priv, instance_type, ami)

  # Create auto scaling group for nginx service
  autoscalinggroup(asg, az1, az2, priv_net1, priv_net2, alb_target_group_arn)

  puts "VPC: #{vpc}"
  puts "\n\n\nPlease wait ~3 minutes for the nginx service to become active.\n"
  puts "Application LoadBalancer DNS: #{alb_dns_name}"
  puts "    Classic LoadBalancer DNS: #{clb_dns_name}"
  puts
end

if exec_type == 'cleanup'
  cleanup(vpc_id, ec2, asg, elbv1, elbv2, region)
end

exit 0
