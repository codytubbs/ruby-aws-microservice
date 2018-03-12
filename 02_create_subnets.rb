# 02_create_subnets
# called from main.rb
# a part of ruby-aws-microservice
#
# Author: Cody Tubbs (codytubbs@gmail.com) 2017-05-07
#         https://github.com/codytubbs
#
# rubocop:disable LineLength # Comment to rid length warnings from `rubocop'

def create_subnets(client, our_region, availability_zones, vpc_id)
  # Create private subnet #1.
  puts 'Creating private subnet #1 (10.0.1.0/24) in first AZ...'
  response = client.create_subnet(cidr_block: '10.0.1.0/24',
                                  vpc_id: vpc_id,
                                  availability_zone: our_region + availability_zones[0])
  priv_net1_id = response.subnet['subnet_id']
  priv_net1_az = response.subnet['availability_zone']
  puts "Subnet created; priv_subnet1_id (10.0.1.0/24) = [#{priv_net1_id}]; AZ = [#{priv_net1_az}]"

  # Create private subnet #2.
  puts 'Creating private subnet #2 (10.0.2.0/24) in second AZ...'
  response = client.create_subnet(cidr_block: '10.0.2.0/24',
                                  vpc_id: vpc_id,
                                  availability_zone: our_region + availability_zones[1])
  priv_net2_id = response.subnet['subnet_id']
  priv_net2_az = response.subnet['availability_zone']
  puts "Subnet created; priv_subnet2_id (10.0.2.0/24) = [#{priv_net2_id}]; AZ = [#{priv_net2_az}]"

  # Create PUBLIC subnet #1 (For nat instance) in first AZ.
  puts 'Creating public subnet #1 (10.0.100.0/24) in first AZ...'
  response = client.create_subnet(cidr_block: '10.0.100.0/24',
                                  vpc_id: vpc_id,
                                  availability_zone: our_region + availability_zones[0])
  pub_net1_id = response.subnet['subnet_id']
  pub_net1_az = response.subnet['availability_zone']
  puts "Subnet created; pub_subnet1_id (10.0.100.0/24) = [#{pub_net1_id}]; AZ = [#{pub_net1_az}]"

  # Create PUBLIC subnet #2 (For nat instance) in second AZ.
  puts 'Creating public subnet #2 (10.0.200.0/24) in second AZ...'
  response = client.create_subnet(cidr_block: '10.0.200.0/24',
                                  vpc_id: vpc_id,
                                  availability_zone: our_region + availability_zones[1])
  pub_net2_id = response.subnet['subnet_id']
  pub_net2_az = response.subnet['availability_zone']
  puts "Subnet created; pub_subnet1_id (10.0.200.0/24) = [#{pub_net2_id}]; AZ = [#{pub_net2_az}]"

  # Map a public IPv4 address to all instances launched into public subnet (10.0.100.0/24).
  client.modify_subnet_attribute(map_public_ip_on_launch: { value: true }, subnet_id: pub_net1_id)
  # Map a public IPv4 address to all instances launched into public subnet (10.0.200.0/24).
  client.modify_subnet_attribute(map_public_ip_on_launch: { value: true }, subnet_id: pub_net2_id)

  return pub_net1_id, pub_net2_id, priv_net1_id, priv_net2_id
end
