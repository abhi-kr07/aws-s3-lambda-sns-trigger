#!/bin/bash

# to help in debugging
set -x

# fetch your account id detail from aws
aws_account=$(aws sts get-caller-identity --query "Account" --output text)
echo "my aws account id is $aws_account"

# set the required value for this project
aws_region="eu-north-1"
bucket_name="abhishek-s3-lambda-sns6"
lambda_func_name="s3-sns-lambda"
role_name="s3-lambda-sns"
email_address="abhishekkr98dhn@gmail.com"


#create the role
role_create=$(aws iam create-role --role-name $role_name --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": "sts:AssumeRole",
    "Effect": "Allow",
    "Principal": {
      "Service": [
         "lambda.amazonaws.com",
         "s3.amazonaws.com",
         "sns.amazonaws.com"
      ]
    }
  }]
}')


# filter the role arn from the role which we created above
role_arn=$(echo $role_create | jq -r '.Role.Arn')
echo $role_arn

# Attach policy to the role

aws iam attach-role-policy --role-name $role_name --policy-arn arn:aws:iam::aws:policy/AWSLambda_FullAccess
aws iam attach-role-policy --role-name $role_name --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess

# create a s3 bucket
bucket_output=$(aws s3api create-bucket --bucket "$bucket_name" --create-bucket-configuration LocationConstraint="$aws_region")
echo "Bucket is create and the name is : $bucket_output"

# push an simpple text file to s3 for check
aws s3 cp ./example.txt s3://"$bucket_name"/example.txt

#install zip
sudo apt install zip -y

# Create a Zip file to upload Lambda Function
sudo zip -r s3-lambda-function.zip ./s3-lambda-function

# craete lambda function
aws lambda create-function \
    --function-name $lambda_func_name \
    --region "$aws_region" \
    --runtime "python3.8" \
    --zip-file fileb://./s3-lambda-function.zip \
    --handler s3-lambda-function/s3-lambda-function.lambda_handler \
    --role arn:aws:iam::$aws_account:role/$role_name \
    --memory-size 128 \
    --timeout 30


# add permission to s3 bucket for invoke lambda function
aws lambda add-permission \
    --function-name $lambda_func_name \
    --action lambda:InvokeFunction \
    --statement-id sns \
    --principal s3.amazonaws.com \
    --source-arn "arn:aws:s3:::$bucket_name"

# create s3 event trigger for the lambda function
LambdaFunctionArn="arn:aws:lambda:eu-north-1:$aws_account:function:s3-sns-lambda"
aws s3api put-bucket-notification-configuration \
  --region "$aws_region" \
  --bucket "$bucket_name" \
  --notification-configuration '{
    "LambdaFunctionConfigurations": [{
        "LambdaFunctionArn": "'"$LambdaFunctionArn"'",
        "Events": ["s3:ObjectCreated:*"]
    }]
}'


topic_arn=$(aws sns create-topic --name s3-lambda-sns --output json | jq -r '.TopicArn')
echo " this is your sns topic : $topic_arn"

# Trigger SNS Topic using Lambda Function



# Add SNS publish permission to the Lambda Function
aws sns subscribe \
  --topic-arn "$topic_arn" \
  --protocol email \
  --notification-endpoint "$email_address"

# Publish SNS
aws sns publish \
  --topic-arn "$topic_arn" \
  --subject "A new object created in s3 bucket" \
  --message "Hello this is abhishek , welcome this is project"
