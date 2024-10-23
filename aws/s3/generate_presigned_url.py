import boto3
from botocore.client import Config

# Create an S3 client in Account B
s3_client = boto3.client('s3', config=Config(signature_version='s3v4'))

# Generate a presigned URL for 'put_object' with bucket-owner-full-control ACL
def generate_presigned_url(bucket_name, object_key, expiration=3600):
    try:
        response = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': bucket_name,
                'Key': object_key,
                'ServerSideEncryption': 'AES256'  # The object will be encrypted on the server
            },
            ExpiresIn=expiration  # URL expiration time in seconds
        )
        return response
    except Exception as e:
        print(f"Error generating presigned URL: {e}")
        return None

# Example usage
bucket_name = 'himanshu-test-bucket'
object_key = 'himanshu.txt'

presigned_url = generate_presigned_url(bucket_name, object_key)
print(f"Generated presigned URL: {presigned_url}")
