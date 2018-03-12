# 99_vpc_complete_cleanup
# called from main.rb
# a part of ruby-aws-microservice
#
# Author: Cody Tubbs (codytubbs@gmail.com) 2017-05-07
#         https://github.com/codytubbs
#
# This will attempt to revert all changes to an AWS account made by the
# previous launch code.  The CLI/SDKs are far less kind when trying to nuke
# a VPC that still has dependencies... the web console cheats... :)
#
# TODO: Spend quality time on better exception handling and adding proper waits
#
#  1) Delete auto scaling groups
#  2) Gather all of the instance-ids by name tag filters
# 2a) If the instances are in any state other than 'terminated', terminate them
#  3) Delete listeners
#  4) Delete target groups
#  5) Delete application and classic load balancers
#  6) Filter subnets by vpc-id and delete them
#  7) Filter security groups by vpc-id
# 7a) Skip group with 'default' (reserved) name and delete the rest
#  8) Filter Internet gateway by vpc-id and disassociate it from the vpc
# 8a) Then delete the igw
#  9) Filter route tables by vpc-id
# 9a) Skip the main table that will throw a dependency issue and delete others
# 10) Delete the VPC by id
################################################################################
# rubocop:disable LineLength # Comment to rid length warnings from `rubocop'
# rubocop:disable Metrics/MethodLength

def cleanup(vpc_id, client, asg, elbv1, elbv2, region)
  begin
  response = client.describe_vpcs(vpc_ids: [vpc_id])
  rescue Aws::EC2::Errors::InvalidVpcIDNotFound => e
    puts "Error: vpc_id [#{vpc_id}] does not exist... exiting."
    puts "Make sure you passed the correct region on the command-line if it's not in the default us-west-2"
    exit 0
  end

  # 1) Delete Auto Scaling group
  begin
    asg.delete_auto_scaling_group(auto_scaling_group_name: 'asg-nginx_auto', force_delete: true)
  rescue StandardError => e
    puts "Exception caught: #{e}, attempting to complete."
  end

  sleep 2
  # TODO: properly wait here until ASG is fully deleted before proceeding...
  begin
    asg.delete_launch_configuration(launch_configuration_name: 'lc-nginx_auto')
  rescue StandardError => e
    puts "Exception caught: #{e}, attempting to complete."
  end
  sleep 2

  # 2) instance handling
  term_error = 0
  instances_to_term = []
  terminate_states = %w[pending running shutting-down stopping stopped]
  puts 'Checking for nginx and nat instances, of all states...'
  begin
  response = client.describe_instances(filters: [{name: 'tag:Name', values: ['autoASG nginx server',
                                                                             'nat instance']}])
  rescue StandardError => e
    puts "Exception caught: #{e}, attempting to complete."
  end
  response.reservations.each do |reservation|
    reservation.instances.each do |instance|
      puts "Check #1: instance-id=[#{instance.instance_id}] AMI=[#{instance.image_id}] state=[#{instance.state.name}]"
      instances_to_term.push(instance.instance_id) if terminate_states.include? instance.state.name
    end
  end

  if instances_to_term.any? # If array has content, proceed.
    term_error = 0
    instance_cnt = instances_to_term.length # TODO: Check before/after termination attempts and ensure = 0
    before_terminate = Time.now
    begin
      client.wait_until(:instance_terminated,instance_ids: instances_to_term) do |wait|
        wait.interval = 8      # Seconds between polling attempts. Same as wait.delay
        wait.max_attempts = 15 # Polling attempts before giving up. Wait time is 15*8=120 seconds.
        puts "Attempting to terminate [#{instance_cnt}] instance(s), please wait up to 120 seconds..."
        begin
          client.terminate_instances(instance_ids: instances_to_term)
        rescue StandardError => e
          puts "Exception caught: #{e}, attempting to complete."
        end
      end
    rescue Aws::Waiters::Errors::WaiterFailed => error
      term_error = 1 # TODO: Do something more reliable if this ever occurs.
      puts "Exception: failed waiting for instance running: #{error.message}"
    end
    puts "#{Time.now - before_terminate.to_time} seconds elapsed while terminating." if term_error.zero?
  end

  if term_error.zero?
    # Debug with final instance check... this shouldn't print anything aside from terminated instances.
    begin
      response = client.describe_instances(filters: [{name: 'tag:Name', values: ['autoASG nginx server',
                                                                                 'nat instance']}])
    rescue StandardError => e
      puts "Exception caught: #{e}, attempting to complete."
    end
    response.reservations.each do |reservation|
      reservation.instances.each do |instance|
        puts "Check #2: instance-id=[#{instance.instance_id}] AMI=[#{instance.image_id}] state=[#{instance.state.name}]"
      end
    end
  end

  puts 'Sleeping for 5 seconds...'
  sleep 5

  # 3) Delete listeners
  printf 'Deleting ALB listeners... '
  begin
    response = elbv2.describe_load_balancers(names: ['AutoALB'])
    alb_arn = response.load_balancers[0].load_balancer_arn
  rescue StandardError => e
    puts "Exception caught: #{e}, attempting to complete."
  end
  sleep 2
  begin
    response = elbv2.describe_listeners(load_balancer_arn: alb_arn)
    listener_arn = response.listeners[0].listener_arn
  rescue StandardError => e
    puts "Exception caught: #{e}, attempting to complete."
  end
  begin
    elbv2.delete_listener(listener_arn: listener_arn)
  rescue StandardError => e
    puts "Exception caught: #{e}, attempting to complete."
  end
  sleep 2
  puts 'done.'

  # 4) Delete target groups
  printf 'Deleting ALB target groups... '
  begin
    response = elbv2.describe_target_groups(names: ['AutoALBTargetGroup'])
    target_group_arn = response.target_groups[0].target_group_arn
  rescue StandardError => e
    puts "Exception caught: #{e}, attempting to complete."
  end
  begin
    elbv2.delete_target_group(target_group_arn: target_group_arn)
  rescue StandardError => e
    puts "Exception caught: #{e}, attempting to complete."
  end
  sleep 5
  puts 'done.'

  # 5) Delete load balancers
  printf 'Deleting application and classic load balancers... '
  begin
    elbv1.delete_load_balancer(load_balancer_name: 'AutoCLB')
  rescue StandardError => e
    puts "Exception caught: #{e}, attempting to complete."
  end
  begin
    elbv2.delete_load_balancer(load_balancer_arn: alb_arn)
  rescue StandardError => e
    puts "Exception caught: #{e}, attempting to complete."
  end
  puts 'done.'

  puts 'Sleeping for 120 seconds, enough time for the ASG to fully disappear before deleting subnets.'
  sleep 120

  # 6) subnets
  begin
    response = client.describe_subnets(filters: [{name: 'vpc-id', values: [vpc_id]}])
    response.subnets.each do |sn|
      printf "Removing subnet: #{sn.subnet_id}, #{sn.vpc_id}, #{sn.cidr_block}, #{sn.availability_zone}; "
      client.delete_subnet(subnet_id: sn.subnet_id)
      puts 'Done.'
  end
  rescue StandardError => e
    puts "Exception caught: #{e}, attempting to complete."
  end

  # 7) security groups
  begin
    response = client.describe_security_groups(filters: [{name: 'vpc-id', values: [vpc_id]}])
    response.security_groups.each do |sg|
      next if sg.group_name == 'default' # This name is reserved by aws and cannot be removed.
      printf "Removing security group: #{sg.group_id}, #{sg.vpc_id}, #{sg.group_name}, Desc='#{sg.description}'; "
      client.delete_security_group(group_id: sg.group_id)
      puts 'Done.'
    end
  rescue StandardError => e
    puts "Exception caught: #{e}, attempting to complete."
  end

  # 8) Internet gateway
  begin
    response = client.describe_internet_gateways(filters: [{name: 'attachment.vpc-id', values: [vpc_id]}])
    response.internet_gateways.each do |igw|
      printf "Detaching Internet gateway: #{igw.internet_gateway_id} <-> #{igw.attachments[0].vpc_id}; "
      client.detach_internet_gateway(internet_gateway_id: igw.internet_gateway_id, vpc_id: igw.attachments[0].vpc_id)
      printf "Removing Internet gateway: #{igw.internet_gateway_id} <-> #{igw.attachments[0].vpc_id}; "
      client.delete_internet_gateway(internet_gateway_id: igw.internet_gateway_id)
      puts 'Done.'
    end
  rescue StandardError => e
    puts "Exception caught: #{e}, attempting to complete."
  end

  # 9) Route tables
  begin
    response = client.describe_route_tables(filters: [{name: 'vpc-id', values: [vpc_id]}])
    response.route_tables.each do |rtl|
      if rtl.associations[0] != nil
        if rtl.associations[0].route_table_association_id != nil
          puts "Skipping #{rtl.associations[0].route_table_association_id}, causes exception."
        end
        next
      end
      printf "Removing route table: #{rtl.route_table_id}, #{rtl.vpc_id}; "
      client.delete_route_table(route_table_id: rtl.route_table_id)
      puts 'Done.'
    end
  rescue StandardError => e
    puts "Exception caught: #{e}, attempting to complete."
  end

  # 10) Delete VPC
  begin
    puts "Attempting to delete VPC [#{vpc_id}]"
    client.delete_vpc(vpc_id: vpc_id)
  rescue StandardError => e
    puts "Exception caught: #{e}, attempting to complete."
  end

  begin
    response = client.describe_vpcs(vpc_ids: [vpc_id])
  rescue Aws::EC2::Errors::InvalidVpcIDNotFound => e
    puts "Deletion of vpc_id=[#{vpc_id}] was a success."
    exit 0
  end

  # Shouldn't get here, but sometimes does due to the ASG taking too long to
  # release subnet dependencies, or if running a cleanup before a launch has
  # fully completed, etc.
  puts 'Oops. Termination sometimes fails for various reasons.'
  puts 'Note: running this twice usually clears up any lingering dependencies.'
  puts '      With that said, there is still work to be done.  Execute again.'
  exit 0
end
