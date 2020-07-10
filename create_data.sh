#!/bin/bash
# Name: create_data.sh
# TPCDS dataset generation script.
# Usage example:
#
# create_data.sh scale_factor bucket_name
#
# create_data.sh 1 we-engg-test-bucket
#

this=$(basename $0)

usage ()


{
        echo
        echo "Usage is: $this scale_factor bucket_name"
        echo "e.g: $this 1 we-engg-test-bucket"
        echo
        echo
}

 
if [ $# -eq 0 ]; then
        usage;
        exit 1
fi

 

echo "Make sure your workstation is having sufficient storage"
read -p "Do you want to continue [n]: " cont

# Clone this project and navigate into it

git clone https://github.com/matwerber1/tpc-ds-datagen-to-aws-s3

cd tpc-ds-datagen-to-aws-s3

# Compile the TPC-DS generator for your environment
# cd tpc-ds/v2.11.0rc2/tools && make

cd tpc-ds/v2.11.0rc2/tools && make && cd ../../..

# The total uncompressed size in GB of the TPC-DS dataset you want to generate:

SCALE=$1

# Amazon S3 output bucket to store results (do not include trailing slash):

S3_BUCKET=s3://$2

# Set this to your bucket region (must be in same region as your cluster)

#BUCKET_REGION=$3
# Amazon S3 prefix to store results. This will be added to the bucket path
# above when determining where to upload your generated data. For example, if
# your bucket is s3://my-bucket and your prefix (below) is my-tpc-data, your
# final output will be in s3://my-bucket/my-tpc-data/*.
# Below, do not include a trailing slash

S3_USER_PREFIX=bigdata/tpc-ds

# The full ARN of the IAM role that grants your Redshift cluster
# permission to read data from the S3 bucket/path you specified above:
 
#IAM_ROLE=arn:aws:iam::111111111111:role/DevRole



####################################################################

# DO NOT EDIT BELOW THIS LINE (UNLESS YOU WANT TO FURTHER CUSTOMIZE

####################################################################

S3_FULL_PATH=$S3_BUCKET/$S3_USER_PREFIX/${SCALE}gb

 

# Get current directory (dsdgen needs full, not relative DIRs for the way we will use it):

CURR_DIR=$(pwd)

 

 

# Relative path to the data generation tool:

TOOL_DIR=$CURR_DIR/tpc-ds/v2.11.0rc2/tools

 

# Relative path to sample query templates:

QUERY_TEMPLATE_DIR=$CURR_DIR/tpc-ds/v2.11.0rc2/query_templates

 

# Path where generated data will be stored:

RAW_OUTPUT_DIR=$CURR_DIR/dataset/raw

 

# Make our output directory if it doesn't already exist:

mkdir -p $RAW_OUTPUT_DIR

 

# Run command to generate our data set:

$TOOL_DIR/dsdgen \

  -DISTRIBUTIONS $TOOL_DIR/tpcds.idx \

  -dir $RAW_OUTPUT_DIR \

  -scale $SCALE \

  -verbose Y \

  -force

 

# Number of megabytes per file when splitting the raw TPC-DS source files into smaller chunks.

# I chose 20M because, when compressed, this should typically give files > 1 MB (which is best practice),

# while still generating lots of files (on larger data sets) so we can parallelize the load into Redshift

MEGABYTES_PER_RAW_FILE="20M"

 

GZIP_OUTPUT_PREFIX=dataset/s3

 

echo "" > load_tables.sql

 

# Split each raw file into multiple GZIP'd files and upload to Amazon S3

for RAW_FILE_PATH in $RAW_OUTPUT_DIR/*

do

  # Get filename only (strip path):

  FILENAME_EXT=$(basename "$RAW_FILE_PATH")

 

  # Get filename without extension (we will use this as part of our folder name prefix in S3):

  FILENAME=$(echo "$FILENAME_EXT" | cut -f 1 -d '.')

  echo "Processing $FILENAME..."

 

  # Directory to store our GZIP'd results:

  GZIP_OUTPUT_DIR=$GZIP_OUTPUT_PREFIX/$FILENAME/

 

  # Make the directory if it doesn't already exist:

  mkdir -p $GZIP_OUTPUT_DIR

 

  # Split our file into chunks, and process each chunk with GZIP

  split -C $MEGABYTES_PER_RAW_FILE --filter='gzip > $FILE.gz' $RAW_FILE_PATH $GZIP_OUTPUT_DIR

 

  # Copy GZIP'd files to S3 path, which each table's files in its own prefix matching the table/filename:

 

        #  aws s3 sync $GZIP_OUTPUT_DIR $S3_FULL_PATH/$FILENAME/

        # In case of S3 bucket policy to enforce server side encryption using AES256, client writing to the bucket must specify --sse flag

 

        aws s3 sync $GZIP_OUTPUT_DIR $S3_FULL_PATH/$FILENAME/ --sse AES256

 

  # Our table name should match our filename; the variable below just makes this script more readable:

  TABLE=$FILENAME

 

  # Generate the SQL to load our data from S3 to Redshift.

  SQL="copy $TABLE from '$S3_FULL_PATH/$FILENAME/' iam_role '$IAM_ROLE' gzip delimiter '|' COMPUPDATE ON ACCEPTINVCHARS region '$BUCKET_REGION';"

 

  # Write SQL to our sql script:

  echo $SQL >> load_tables.sql

 

done

 

QUERY_OUTPUT_DIR=$CURR_DIR/queries

mkdir -p $QUERY_OUTPUT_DIR

 

# Now, generate the test queries that we can later run in our Redshift cluster (after we've loaded the data):

(cd $TOOL_DIR && ./dsqgen \

-DIRECTORY ../query_templates \

-INPUT ../query_templates/templates.lst \

-VERBOSE Y \

-QUALIFY Y \

-SCALE 1 \

-DIALECT netezza \

-OUTPUT_DIR $QUERY_OUTPUT_DIR

)

 

echo ""

echo "All done!"

echo ""

echo "Your data has been uploaded to S3."

echo "Create your table schema with create-table-ddl.sql,"

echo "import your data with load-tables.sql, and then"

echo "use the test queries in the ./queries directory."