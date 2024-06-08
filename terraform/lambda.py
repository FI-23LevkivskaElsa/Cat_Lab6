import json
import boto3

s3 = boto3.client('s3')


def lambda_handler(event, context):
    for record in event['Records']:
        source_bucket = record['s3']['bucket']['name']
        source_key = record['s3']['object']['key']

        destination_bucket = 's3-finish'
        copy_source = {'Bucket': source_bucket, 'Key': source_key}

        s3.copy_object(Bucket=destination_bucket, Key=source_key, CopySource=copy_source)

    return {
        'statusCode': 200,
        'body': json.dumps('File copied successfully!')
    }
