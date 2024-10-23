import os
import http.client
from urllib.parse import urlparse

# Upload a file using the presigned URL via http.client
def upload_file_via_http_client(presigned_url, file_path):
    try:
        # Parse the presigned URL
        url = urlparse(presigned_url)
        conn = http.client.HTTPSConnection(url.hostname)
        # Get file size and read the file
        file_size = os.path.getsize(file_path)
        with open(file_path, 'rb') as file:
            # Set up the PUT request with Content-Length to avoid chunked transfer encoding
            conn.request("PUT", url.path + '?' + url.query, body=file, headers={
                'Content-Length': str(file_size),
                'Content-Type': 'application/octet-stream'
            })
            # Get the response
            response = conn.getresponse()

            # Check if upload was successful
            if response.status == 200:
                print("File uploaded successfully.")
            else:
                print(f"Failed to upload file. HTTP status: {response.status}, reason: {response.reason}")
    except Exception as e:
        print(f"Error uploading file: {e}")
    return response

# Example usage
file_path = 'himanshu.txt'  # Local file path
presigned_url = '<url>'  # Presigned URL
response = upload_file_via_http_client(presigned_url, file_path)
