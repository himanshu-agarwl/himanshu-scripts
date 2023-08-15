import boto3
MAXPENDINGDELETIONS=1000
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('smart-ehr-summarize-tasks')
print("scanning table")
scan_response = table.scan(
    FilterExpression="attribute_not_exists(expire_at)"
)
print(scan_response)
items_to_delete = []
items_to_delete.extend(scan_response['Items'])
print(len(items_to_delete))
while 'LastEvaluatedKey' in scan_response:
    scan_response = table.scan(
        FilterExpression="attribute_not_exists(expire_at)",
        ExclusiveStartKey=scan_response['LastEvaluatedKey']
    )
    items_to_delete.extend(scan_response['Items'])
    if(len(items_to_delete) >= MAXPENDINGDELETIONS): # Delete last 1000 entries manually
        with table.batch_writer() as batch:
            for item in items_to_delete:
                if "completed_at" in item:
                    if(item['completed_at']>=1691911868):
                        print("Trying to delete a newer value : " + item['pkey'])
                    else:
                        print("Deleteing: "+ item['pkey']+ " "+str(item['completed_at']))
                        batch.delete_item(Key={'pkey':item['pkey'], 'skey':item['skey']})
                elif "failed_at" in item:
                    if(item['failed_at']>=1691911868):
                        print("Trying to delete a newer failed value : " + item['pkey'])
                    else:
                        print("Deleteing: "+ item['pkey']+ " failed at "+str(item['failed_at']))
                        batch.delete_item(Key={'pkey':item['pkey'], 'skey':item['skey']})
        items_to_delete = []
