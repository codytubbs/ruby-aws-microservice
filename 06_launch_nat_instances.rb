# 06_launch_nat_instances
# called from main.rb
# a part of ruby-aws-microservice
#
# Author: Cody Tubbs (codytubbs@gmail.com) 2017-05-07
#         https://github.com/codytubbs
#
# rubocop:disable LineLength # Comment to rid length warnings from `rubocop'
# rubocop:disable Metrics/ParameterLists

def launch_nat_instances(client,
                         pub_net1_id,
                         pub_net2_id,
                         sg_in_tcp_22_pub,
                         sg_in_tcp_80_nat,
                         priv_route_table_id,
                         instance_type,
                         ami)
  # launching public subnet nat instances #1 and #2 in 10.0.100.0/24 and 10.0.200.0/24, respectively.
  puts 'Launching public subnet nat instances #1 and #2 in 10.0.100.0/24 and 10.0.200.0/24, respectively...'
  [1, 2].each do |subnet_num|
    pub_subnet_id = case subnet_num
                    when 1 then pub_net1_id
                    when 2 then pub_net2_id
                    else puts 'debug: should not get here'
                    end
    response = client.run_instances(image_id: ami,
                                    # key_name: 'UbuntuKeyPair',
                                    min_count: 1,
                                    max_count: 1,
                                    security_group_ids: [sg_in_tcp_80_nat], # sg_in_tcp_22_pub
                                    instance_type: instance_type,
                                    placement: {},
                                    # block_device_mappings: [{ebs: {delete_on_termination: true, volume_type: 'gp2'}}],
                                    monitoring: { enabled: false },
                                    subnet_id: pub_subnet_id,
                                    disable_api_termination: false,
                                    instance_initiated_shutdown_behavior: 'terminate',
                                    ebs_optimized: false,
                                    tag_specifications: [resource_type: 'instance',
                                                         tags: [key: 'Name', value: 'nat instance']],
                                    user_data: Base64.encode64("#!/bin/bash -ex\n"\
                                                               "export DEBIAN_FRONTEND=noninteractive\n"\
                                                               "apt-get -q=2 update && apt-get -q=2 upgrade\n"\
                                                               "sysctl -w net.ipv4.ip_forward=1\n"\
                                                               "sysctl -w net.ipv4.conf.eth0.send_redirects=0\n"\
                                                               'iptables -t nat -A POSTROUTING -s 10.0.0.0/16 -o eth0 -j MASQUERADE'))
    nat_instance_id = response.instances[0].instance_id
    puts "nat_instance_id ##{subnet_num} = [#{nat_instance_id}];"

    before_wait = Time.now
    term_error = 0
    begin
      puts "Waiting for nat instance ##{subnet_num} [#{nat_instance_id}] to enter running state."
      client.wait_until(:instance_running,instance_ids: [nat_instance_id]) do |wait|
        wait.interval = 5      # Seconds between polling attempts. Same as wait.delay
        wait.max_attempts = 15 # Polling attempts before giving up. Wait time is 15*5=75 seconds.
      end
    rescue Aws::Waiters::Errors::WaiterFailed => error
      term_error = 1 # TODO: Do something more reliable if this ever occurs.
      puts "Exception: failed waiting for instance running: #{error.message}"
    end
    puts "#{Time.now - before_wait.to_time} seconds elapsed while waiting." if term_error.zero?

    # Create route for 0.0.0.0/0 -> nat instance (for private instances to bootstrap/update)
    if subnet_num == 1 # Only insert this route one time.  Will receive 'RouteAlreadyExists' otherwise."
      puts 'Creating route for 0.0.0.0/0 -> nat instances in private route table...'
      response = client.create_route(destination_cidr_block: '0.0.0.0/0',
                                     route_table_id: priv_route_table_id,
                                     instance_id: nat_instance_id)
      puts 'Route for 0.0.0.0/0 -> nat instances in private route table added.'
    end
    # Disable source/destination checking for network address translation to work.
    # The API doesn't allow setting this during the run_instances call... but does right afterward.
    printf "Disabling source/destination checking on nat instance ##{subnet_num}... "
    client.modify_instance_attribute(instance_id: nat_instance_id, source_dest_check: {value: false})
    puts 'done.'
  end
  puts 'public 10.0.100.0/24 and 10.0.200.0/24 nat instance #1 and #2 launch complete.'
end
