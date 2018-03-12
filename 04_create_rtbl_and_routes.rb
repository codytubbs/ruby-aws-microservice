# 04_create_rtbl_and_routes
# called from main.rb
# a part of ruby-aws-microservice
#
# Author: Cody Tubbs (codytubbs@gmail.com) 2017-05-07
#         https://github.com/codytubbs
#
# rubocop:disable LineLength # Comment to rid length warnings from `rubocop'
# rubocop:disable Metrics/ParameterLists

def create_rtbl_and_routes(client,
                           vpc_id,
                           internet_gateway_id,
                           pub_subnet1_id,
                           pub_subnet2_id,
                           priv_subnet1_id,
                           priv_subnet2_id)
  # Create Public Route Table #1 for public subnets
  puts 'Creating public subnet route table...'
  response = client.create_route_table(vpc_id: vpc_id)
  pub_route_table_id = response.route_table['route_table_id']
  puts "Route Table created; route_table = [#{pub_route_table_id}]"

  # Create pub route for 0.0.0.0/0 -> Internet gateway id (This is for the public subnet(s) to reach the Internet)
  puts 'Creating route for 0.0.0.0/0 -> Internet gateway id...'
  client.create_route(destination_cidr_block: '0.0.0.0/0',
                      gateway_id: internet_gateway_id,
                      route_table_id: pub_route_table_id)
  puts 'Route for 0.0.0.0/0 -> Internet gateway id added.'

  # Create Route Table #2 for private subnets
  puts 'Creating private subnet route table...'
  response = client.create_route_table(vpc_id: vpc_id)
  priv_route_table_id = response.route_table['route_table_id']
  puts "Route Table created; route_table = [#{priv_route_table_id}]"

  # Associate public route table w/ public subnet #1.
  puts "Associating public route table [#{pub_route_table_id} with public subnet [#{pub_subnet1_id}]"
  response = client.associate_route_table(route_table_id: pub_route_table_id, subnet_id: pub_subnet1_id)
  puts "Associated; association_id = [#{response.association_id}]"
  puts "Route table [#{pub_route_table_id}] <-> [#{pub_subnet1_id}] subnet association complete."

  # Associate public route table w/ public subnet #2.
  puts "Associating public route table [#{pub_route_table_id} with public subnet [#{pub_subnet2_id}]"
  response = client.associate_route_table(route_table_id: pub_route_table_id, subnet_id: pub_subnet2_id)
  puts "Associated; association_id = [#{response.association_id}]"
  puts "Route table [#{pub_route_table_id}] <-> [#{pub_subnet2_id}] subnet association complete."


  # Associate private route table w/ private subnet #1.
  puts "Associating route table [#{priv_route_table_id} with subnet [#{priv_subnet1_id}]"
  response = client.associate_route_table(route_table_id: priv_route_table_id, subnet_id: priv_subnet1_id)
  puts "Associated; association_id = [#{response.association_id}]"
  puts "Route table [#{priv_route_table_id}] <-> [#{priv_subnet1_id}] subnet association complete."

  # Associate private route table w/ private subnet #2.
  puts "Associating route table [#{priv_route_table_id} with subnet [#{priv_subnet2_id}]"
  response = client.associate_route_table(route_table_id: priv_route_table_id, subnet_id: priv_subnet2_id)
  puts "Associated; association_id = [#{response.association_id}]"
  puts "Route table [#{priv_route_table_id}] <-> [#{priv_subnet2_id}] subnet association complete."

  priv_route_table_id # Return
end
