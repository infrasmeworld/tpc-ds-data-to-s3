Purpose:

Generate a TPC-DS dataset of arbitrary size and upload to Amazon S3.

This script splits your raw data into multiple files and then GZIPs each file before loadinf to Amazon S3. This speeds your upload to S3.

Prerequisites:

1. While you could generate your data set and upload to Amazon S3 from a local machine, you may be able to achieve faster results using an EC2 instance in AWS. If you want, deploy an EC2 instance with sufficient EBS to support the size of data set you plan to generate.

2. An Amazon S3 bucket where you will upload your generated data.


Instructions:

