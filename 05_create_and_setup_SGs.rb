# 05_create_and_setup_SGs
# called from main.rb
# a part of ruby-aws-microservice
#
# Author: Cody Tubbs (codytubbs@gmail.com) 2017-05-07
#         https://github.com/codytubbs
#
# rubocop:disable LineLength # Comment to rid length warnings from `rubocop'

def create_and_setup_SGs(client, vpc_id)
  # Create security group for private subnet ingress TCP port 80 (for httpd (nginx)).
  puts 'Creating security group for ingress TCP port 80 on private subnet...'
  response = client.create_security_group(group_name: 'sg_in_tcp_80_priv',
                                          description: 'Ingress TCP HTTP:80 priv subnet',
                                          vpc_id: vpc_id)
  sg_tcp_80_priv = response.group_id
  puts "Security group created; Security group id = [#{sg_tcp_80_priv}]"

  # Create security group for public LBs ingress TCP port 80.
  puts 'Creating security group for ingress TCP port 80 for LBs...'
  response = client.create_security_group(group_name: 'sg_in_tcp_80_lb',
                                          description: 'Ingress TCP HTTP:80 LBs',
                                          vpc_id: vpc_id)
  sg_tcp_80_lb = response.group_id
  puts "Security group created; Security group id = [#{sg_tcp_80_lb}]"


  # Create security group for private subnet ingress TCP port 22 (for sshd).
  puts 'Creating security group for ingress TCP port 22 for private subnet...'
  response = client.create_security_group(group_name: 'sg_in_tcp_22_priv',
                                          description: 'Ingress TCP SSH:22 priv subnet',
                                          vpc_id: vpc_id)
  sg_tcp_22_priv = response.group_id
  puts "Security group created; Security group id = [#{sg_tcp_22_priv}]"

  # Create security group for ingress TCP port 22 (for sshd) for public nat instances.
  puts 'Creating security group for ingress TCP port 22 for public nat instances...'
  response = client.create_security_group(group_name: 'sg_in_tcp_22_pub',
                                          description: 'Ingress TCP SSH:22 NAT instances',
                                          vpc_id: vpc_id)
  sg_tcp_22_pub = response.group_id
  puts "Security group created; Security group id = [#{sg_tcp_22_pub}]"

  # Create security group for ingress TCP port 80 (for nginx instance updates) through nat instances.
  puts 'Creating security group for ingress TCP port 80 for NAT instance...'
  response = client.create_security_group(group_name: 'sg_in_tcp_80_nat',
                                          description: 'Ingress TCP HTTP:80 to/through NAT instances',
                                          vpc_id: vpc_id)
  sg_tcp_80_nat = response.group_id
  puts "Security group created; Security group id = [#{sg_tcp_80_nat}]"

  # Add an ingress rule of *any* (0.0.0.0/0) to the TCP port 80 private subnet security group.
  puts 'Adding ingress rule of *any* to the TCP port 80 private subnet security group...'
  client.authorize_security_group_ingress(group_id: sg_tcp_80_priv,
                                          ip_protocol: 'tcp',
                                          from_port: 80, # This is the start of the port range
                                          to_port: 80,   # This is the end of the port range
                                          cidr_ip: '0.0.0.0/0') # TODO: limit to aws LB address space
  puts 'Rule added.'

  # Add an ingress rule of *any* (0.0.0.0/0) to the TCP port 80 LB security group.
  puts 'Adding ingress rule of *any* to the TCP port 80 LB security group...'
  client.authorize_security_group_ingress(group_id: sg_tcp_80_lb,
                                          ip_protocol: 'tcp',
                                          from_port: 80, # This is the start of the port range
                                          to_port: 80,   # This is the end of the port range
                                          cidr_ip: '0.0.0.0/0')
  puts 'Rule added.'

  # Add an ingress rule of (10.0.0.0/16) to the TCP port 80 for the nat instances.
  puts 'Adding ingress rule of (10.0.0.0/16) to the TCP port 80 for the private nat instance side...'
  client.authorize_security_group_ingress(group_id: sg_tcp_80_nat,
                                          ip_protocol: 'tcp',
                                          from_port: 80, # This is the start of the port range
                                          to_port: 80,   # This is the end of the port range
                                          cidr_ip: '10.0.0.0/16')
  puts 'Rule added.'

  # Add an ingress rule of 10.0.100.0/24 to the TCP port 22 private subnet security group.
  puts 'Adding ingress rule of 10.0.100.0/24 to the TCP port 22 private subnet security group...'
  client.authorize_security_group_ingress(group_id: sg_tcp_22_priv,
                                          ip_protocol: 'tcp',
                                          from_port: 22, # This is the start of the port range
                                          to_port: 22,   # This is the end of the port range
                                          cidr_ip: '10.0.100.0/24') # eg. for ssh access from nat instance
  puts 'Rule added.'

  # Add an ingress rule of 10.0.200.0/24 to the TCP port 22 private subnet security group.
  puts 'Adding ingress rule of 10.0.200.0/24 to the TCP port 22 private subnet security group...'
  client.authorize_security_group_ingress(group_id: sg_tcp_22_priv,
                                          ip_protocol: 'tcp',
                                          from_port: 22, # This is the start of the port range
                                          to_port: 22,   # This is the end of the port range
                                          cidr_ip: '10.0.200.0/24') # eg. for ssh access from nat instance
  puts 'Rule added.'

  # Add an ingress rule of your choice here to the TCP port 22 public subnet security group.
  # puts 'Adding ingress rule of x.x.x.x/32 to the TCP port 22 public subnet security group...'
  # client.authorize_security_group_ingress(group_id: sg_tcp_22_pub,
  #                                        ip_protocol: 'tcp',
  #                                        from_port: 22, # This is the start of the port range
  #                                        to_port: 22,   # This is the end of the port range
  #                                        cidr_ip: 'x.x.x.x/32') # Replace this with your src IP.
  # puts 'Rule added.'
  return sg_tcp_80_priv, sg_tcp_22_priv, sg_tcp_22_pub, sg_tcp_80_nat, sg_tcp_80_lb
end
