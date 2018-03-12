#### Launches a load-balanced, auto-scaled, and auto-healing (NGINX) microservice in AWS.
###### 2017-05-07

 - Mainly for demo purposes only

This code will create and build an AWS VPC from scratch. This also includes the
required subnets, internet gateway, routing table, and routes, basically to
demonstrate what goes on under the hood.

This will also create NAT instances (rather than using NAT gateways, because they are
free for testing with t2.micro instances).  This also allows the NGINX servers to be on
private subnets only, without needing a public interface.

As examples, both a Classic LB (CLB) and an Application LB (ALB) are created, that
both point to the backend NGINX servers.

An AWS launch configuration and auto scaling group are created and used.

The service can withstand the termination of a node and auto-heal.

If/when the code is requested to, it will completely nuke the created VPC and all that
is associated with it. (-not- the default VPC).

Remaining action items:
1) Run through the source and replace all occurrences of the `TODO' tag with proper code.
2) Create classes out of the re-usable portions of code.
3) Convert NAT instances back to NAT Gateways. NAT instances were free while testing.
4) Finally, port this to Terraform, where it belongs. :)

aws-sdk gems may need to be installed:

```
$ gem install aws-sdk-resources aws-sdk-core aws-sdk
```

My versions:  
```
$ gem list|grep aws
aws-sdk (2.9.15)
aws-sdk-core (2.9.15)
aws-sdk-resources (2.9.15)
```

Tested in us-west-2, and used creds from ~/.aws/credentials  
Tested with 'default' and non-default profile names in the credentials file.  

For usage, simply execute main.rb:  
`$ ruby main.rb`

##

Author :: Cody Tubbs :: (codytubbs+ram@gmail.com)  
[https://github.com/codytubbs/ruby-aws-micoservice][98]  
[https://github.com/codytubbs][99]

[98]: https://github.com/codytubbs/ruby-aws-micoservice
[99]: https://github.com/codytubbs