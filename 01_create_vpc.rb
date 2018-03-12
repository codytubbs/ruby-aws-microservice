# 01_create_vpc
# called from main.rb
# a part of ruby-aws-microservice
#
# Author: Cody Tubbs (codytubbs@gmail.com) 2017-05-07
#         https://github.com/codytubbs

def create_vpc(client)
  # Create VPC with CIDR block 10.0.0.0/16.
  puts 'Creating VPC with CIDR block 10.0.0.0/16...'
  response = client.create_vpc(cidr_block: '10.0.0.0/16')
  vpc_id = response.vpc['vpc_id'] # String
  puts "VPC (10.0.0.0/16) created; vpc_id = [#{vpc_id}]"
  vpc_id # return
end
