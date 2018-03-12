# 07_create_CLB_and_ALB
# called from main.rb
# a part of ruby-aws-microservice
#
# Author: Cody Tubbs (codytubbs@gmail.com) 2017-05-07
#         https://github.com/codytubbs
#
# rubocop:disable LineLength # Comment to rid length warnings from `rubocop'

def createCLB(elbv1, sg_tcp_80_lb, pub_net1_id, pub_net2_id)
  # TODO: Remove CLB by name if create fails to fully create

  # Create CLB
  response = elbv1.create_load_balancer(load_balancer_name: 'AutoCLB',
                                        subnets: [pub_net1_id, pub_net2_id],
                                        security_groups: [sg_tcp_80_lb],
                                        listeners: [{ protocol: 'HTTP',
                                                      load_balancer_port: 80,
                                                      instance_protocol: 'HTTP',
                                                      instance_port: 80 }])
  clb_dns_name = response.dns_name
  puts "clb_dns_name = #{clb_dns_name}"
  clb_dns_name # return
end

def createALB(elbv2, vpc_id, sg_tcp_80_lb, pub_net1_id, pub_net2_id)
  # TODO: Remove ALB by name if create fails to fully create
  # Create ALB
  response = elbv2.create_load_balancer(name: 'AutoALB',
                                        subnets: [pub_net1_id, pub_net2_id],
                                        security_groups: [sg_tcp_80_lb],
                                        scheme: 'internet-facing',
                                        tags: [{ key: 'Name', value: 'AutoALB for nginx servers' }],
                                        ip_address_type: 'ipv4')
  alb_arn = response.load_balancers[0].load_balancer_arn
  alb_dns_name = response.load_balancers[0].dns_name
  # Get ARN from response for later sending to CreateASG
  puts "alb_dns_name = #{alb_dns_name}"

  # Create Target Group for ALB
  response = elbv2.create_target_group(name: 'AutoALBTargetGroup',
                                       protocol: 'HTTP',
                                       port: 80,
                                       vpc_id: vpc_id, # required get from CreateVPC return
                                       health_check_protocol: 'HTTP',
                                       health_check_port: '80',
                                       health_check_path: '/',
                                       health_check_interval_seconds: 30, # Default (Seconds between each target health check)
                                       health_check_timeout_seconds: 10, # Default:5 (Time before no response is considered failure)
                                       healthy_threshold_count: 2, # Default:5 (# of unhealthy successes before turning back healthy)
                                       unhealthy_threshold_count: 2, # Default (# of consecutive failures before turning unhealthy)
                                       matcher: { http_code: '200' }) # Ranges with '-' or multiples with ','
  alb_target_group_arn = response.target_groups[0].target_group_arn
  puts "target_group_arn = [#{alb_target_group_arn}]"

  # Create Listener for ALB and record alb_listener_arn
  elbv2.create_listener(load_balancer_arn: alb_arn.to_s, # required
                        protocol: 'HTTP',
                        port: 80,
                        default_actions: [{ type: 'forward', # required, accepts forward
                                            target_group_arn: alb_target_group_arn.to_s }])
  return alb_dns_name, alb_target_group_arn
end
