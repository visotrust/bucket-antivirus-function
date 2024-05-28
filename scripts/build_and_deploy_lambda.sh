#!/bin/bash

set -e

echo "deploying lambda function to branch: ${GITHUB_REF}"

echo "deploying to aws account infra"

make archive

unset  AWS_SESSION_TOKEN

temp_role=$(aws sts assume-role \
                    --role-arn "${GITHUB_ACTION_ROLE_ARN}" \
                    --role-session-name 'github-action-deploy-session')

export AWS_ACCESS_KEY_ID=$(echo $temp_role | jq -r .Credentials.AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq -r .Credentials.SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo $temp_role | jq -r .Credentials.SessionToken)

# aws lambda update-function-code --function-name bucket-antivirus-update --zip-file fileb://build/lambda.zip
aws lambda update-function-code --function-name dev-bucket-antivirus-scan --zip-file fileb://build/lambda.zip
# aws lambda update-function-code --function-name prod-bucket-antivirus-scan --zip-file fileb://build/lambda.zip
# aws lambda update-function-code --function-name demo-bucket-antivirus-scan --zip-file fileb://build/lambda.zip
