import boto3
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('smart-ehr-summarize-tasks')
print("scanning table")
scan_response = table.scan(
    FilterExpression="attribute_exists(expire_at)"
)
items_selected = []
items_selected.extend(scan_response['Items'])
while 'LastEvaluatedKey' in scan_response:
    scan_response = table.scan(
        FilterExpression="attribute_exists(expire_at)",
        ExclusiveStartKey=scan_response['LastEvaluatedKey']
    )
    items_selected.extend(scan_response['Items'])
    print(len(items_selected))

for item in items_selected:
    if "completed_at" in item:
        if(item['completed_at']>=1691911868):
            print("Older value still exists : " + item['pkey'] + "completed at :"+str(item['completed_at']))
    elif "failed_at" in item:
        if(item['failed_at']<1691911868):
            print("Older value still exists : " + item['pkey'] + " failed at :"+str(item['failed_at']))
