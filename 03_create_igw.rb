# 03_create_igw
# called from main.rb
# a part of ruby-aws-microservice
#
# Author: Cody Tubbs (codytubbs@gmail.com) 2017-05-07
#         https://github.com/codytubbs
#
# rubocop:disable LineLength # Comment to rid length warnings from `rubocop'

def create_igw(client, vpc_id)
  # Create Internet gateway.
  puts 'Creating Internet gateway...'
  response = client.create_internet_gateway
  internet_gateway_id = response.internet_gateway['internet_gateway_id']
  puts "Internet gateway created; internet_gateway_id = [#{internet_gateway_id}]"
  # internet_gateway_id # Return

  # Attach Internet Gateway.
  puts 'Attaching Internet gateway to VPC...'
  client.attach_internet_gateway(internet_gateway_id: internet_gateway_id, vpc_id: vpc_id)
  puts 'Internet gateway attached.'

  internet_gateway_id # Return
end
