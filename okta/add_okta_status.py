#!/usr/bin/env python3
"""
Script to add Okta status column to Looker users CSV file.
Looks up each user by email in Okta and adds their account status.
"""

import os
import csv
import requests
from urllib.parse import quote

# ===== CONFIG =====
# Set these as environment variables or replace with your values
OKTA_DOMAIN = os.environ.get("OKTA_DOMAIN", "YOUR_ORG.okta.com")  # e.g., carbonhealth.okta.com
OKTA_API_TOKEN = os.environ.get("OKTA_API_TOKEN", "YOUR_OKTA_API_TOKEN")

INPUT_CSV = "<>"
OUTPUT_CSV = "<>"
# ==================


def validate_okta_token() -> bool:
    """Test if the Okta API token is valid by making a simple API call."""
    url = f"https://{OKTA_DOMAIN}/api/v1/users?limit=1"
    headers = {
        "Authorization": f"SSWS {OKTA_API_TOKEN}",
        "Accept": "application/json"
    }

    try:
        response = requests.get(url, headers=headers, timeout=10)
        if response.status_code == 200:
            return True
        elif response.status_code == 401:
            print("ERROR: 401 Unauthorized - Your Okta API token is invalid or expired.")
            return False
        else:
            print(f"ERROR: Unexpected status {response.status_code} when validating token")
            print(f"Response: {response.text}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"ERROR: Could not connect to Okta: {e}")
        return False


def get_okta_user_status(email: str) -> str:
    """
    Look up a user in Okta by email and return their status.

    Possible statuses: STAGED, PROVISIONED, ACTIVE, RECOVERY,
    LOCKED_OUT, PASSWORD_EXPIRED, SUSPENDED, DEPROVISIONED

    Returns 'NOT_FOUND' if user doesn't exist in Okta.
    Returns 'ERROR' if API call fails.
    Returns 'NO_EMAIL' if email is empty.
    """
    if not email or not email.strip():
        return "NO_EMAIL"

    # URL encode the email for the API call
    encoded_email = quote(email.strip(), safe='')
    url = f"https://{OKTA_DOMAIN}/api/v1/users/{encoded_email}"

    headers = {
        "Authorization": f"SSWS {OKTA_API_TOKEN}",
        "Accept": "application/json",
        "Content-Type": "application/json"
    }

    try:
        response = requests.get(url, headers=headers, timeout=10)

        if response.status_code == 200:
            user_data = response.json()
            return user_data.get("status", "UNKNOWN")
        elif response.status_code == 404:
            return "NOT_FOUND"
        else:
            print(f"  Warning: Got status {response.status_code} for {email}")
            return f"ERROR_{response.status_code}"
    except requests.exceptions.RequestException as e:
        print(f"  Error looking up {email}: {e}")
        return "ERROR"


def process_csv(input_file: str, output_file: str):
    """
    Read the input CSV, add Okta status column, and write to output CSV.
    """
    with open(input_file, 'r', newline='', encoding='utf-8') as infile:
        reader = csv.DictReader(infile)
        fieldnames = reader.fieldnames + ['Okta Status']

        rows = list(reader)
        total = len(rows)

        print(f"Processing {total} users...")

        with open(output_file, 'w', newline='', encoding='utf-8') as outfile:
            writer = csv.DictWriter(outfile, fieldnames=fieldnames)
            writer.writeheader()

            for i, row in enumerate(rows, 1):
                email = row.get('Email', '')
                name = row.get('Name', 'Unknown')

                print(f"[{i}/{total}] Looking up {name} ({email})...")
                okta_status = get_okta_user_status(email)

                row['Okta Status'] = okta_status
                writer.writerow(row)

                if i % 10 == 0:
                    print(f"  Progress: {i}/{total} users processed")

    print(f"\nDone! Output written to: {output_file}")


def print_summary(output_file: str):
    """Print a summary of Okta statuses found."""
    status_counts = {}

    with open(output_file, 'r', newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            status = row.get('Okta Status', 'UNKNOWN')
            status_counts[status] = status_counts.get(status, 0) + 1

    print("\n=== Okta Status Summary ===")
    for status, count in sorted(status_counts.items(), key=lambda x: -x[1]):
        print(f"  {status}: {count}")


if __name__ == "__main__":
    # Validate configuration
    if OKTA_API_TOKEN == "YOUR_OKTA_API_TOKEN" or OKTA_DOMAIN == "YOUR_ORG.okta.com":
        print("ERROR: Please configure OKTA_DOMAIN and OKTA_API_TOKEN")
        print("\nYou can set them as environment variables:")
        print("  export OKTA_DOMAIN='yourorg.okta.com'")
        print("  export OKTA_API_TOKEN='your-api-token'")
        print("\nOr edit the CONFIG section at the top of this script.")
        exit(1)

    # Check if input file exists
    if not os.path.exists(INPUT_CSV):
        print(f"ERROR: Input file not found: {INPUT_CSV}")
        exit(1)

    # Validate the Okta token before processing
    print("Validating Okta API token...")
    if not validate_okta_token():
        exit(1)
    print("Token is valid!\n")

    process_csv(INPUT_CSV, OUTPUT_CSV)
    print_summary(OUTPUT_CSV)
