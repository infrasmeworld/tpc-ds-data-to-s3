Purpose:

Generate a TPC-DS dataset of arbitrary size and upload to Amazon S3.

This script splits your raw data into multiple files and then GZIPs each file before loadinf to Amazon S3. This speeds your upload to S3.

Prerequisites:

1. While you could generate your data set and upload to Amazon S3 from a local machine, you may be able to achieve faster results using an EC2 instance in AWS. If you want, deploy an EC2 instance with sufficient EBS to support the size of data set you plan to generate.

2. An Amazon S3 bucket where you will upload your generated data.


Instructions:

1. Clone the project and navigate into the tpc-ds folder. 

https://github.com/infrasmeworld/tpc-ds-data-to-s3
cd tpc-ds-data-to-s3

2. Run the create_data.sh script.

NOTE: This script is based on the assumption that, it is running from an EC2 Machine with access to S3 buckets for data retrieval using instance profiles



