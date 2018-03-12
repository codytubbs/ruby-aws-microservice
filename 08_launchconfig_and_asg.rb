# 08_launchconfig_and_asg
# called from main.rb
# a part of ruby-aws-microservice
#
# Author: Cody Tubbs (codytubbs@gmail.com) 2017-05-07
#         https://github.com/codytubbs
#
# rubocop:disable LineLength # Comment to rid length warnings from `rubocop'

def launch_configuration(asg, sg_tcp_80_priv, sg_tcp_22_priv, instance_type, ami)
  asg.create_launch_configuration(launch_configuration_name: 'lc-nginx_auto',
                                  associate_public_ip_address: false,
                                  # key_name: 'UbuntuKeyPair', # TODO: Change/Remove
                                  image_id: ami, # Ubuntu base AMI from ubuntu.com
                                  instance_type: instance_type,
                                  security_groups: [sg_tcp_80_priv], # sg_tcp_22_priv
                                  instance_monitoring: { enabled: true }, # true=CloudWatch monitoring (60sec)
                                  user_data: Base64.encode64("#!/bin/bash -ex\n"\
                                                             "export DEBIAN_FRONTEND=noninteractive\n"\
                                                             "apt-get -q=2 update && apt-get -q=2 upgrade\n"\
                                                             "apt-get -q=2 install nginx\n"\
                                                             "URL=http://169.254.169.254/latest/meta-data\n"\
                                                             "cat >> /var/www/html/index.html <<EOF\n"\
                                                             "<meta http-equiv=refresh content=2 /><br>\n"\
                                                             "FROM: Launch Configuration / ASG<br>\n"\
                                                             "INSTANCE ID: $(curl $URL/instance-id)<br>\n"\
                                                             "PUBLIC IP: [NONE], using NAT instances<br>\n"\
                                                             "INTERNAL IP: $(curl $URL/local-ipv4)<br>\n"\
                                                             'EOF'))
  sleep 5
end

def autoscalinggroup(asg, az1, az2, priv_net1_id, priv_net2_id, alb_target_group_arn)
  asg.create_auto_scaling_group(auto_scaling_group_name: 'asg-nginx_auto',
                                launch_configuration_name: 'lc-nginx_auto',
                                availability_zones: [az1, az2],
                                vpc_zone_identifier: "#{priv_net1_id}, #{priv_net2_id}",
                                load_balancer_names: %w[AutoCLB], # For CLB names only. Use ARN for ALBs.
                                target_group_arns: [alb_target_group_arn],
                                health_check_type: 'ELB', # EC2 or ELB
                                health_check_grace_period: 300, # 300, adjust as needed
                                desired_capacity: 4,
                                min_size: 4,
                                max_size: 8,
                                termination_policies: %w[ClosestToNextInstanceHour OldestInstance OldestLaunchConfiguration],
                                tags: [{key: 'Name', value: 'autoASG nginx server'}])
end
