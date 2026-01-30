import requests
import pandas as pd

# ===== CONFIG =====
LOOKER_BASE_URL = "https://YOUR_LOOKER_HOST:19999"
CLIENT_ID = "YOUR_CLIENT_ID"
CLIENT_SECRET = "YOUR_CLIENT_SECRET"

# ==================

def get_access_token():
    url = f"{LOOKER_BASE_URL}/api/4.0/login"
    resp = requests.post(
        url,
        data={
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET
        }
    )
    resp.raise_for_status()
    return resp.json()["access_token"]

def get_all_users(token):
    url = f"{LOOKER_BASE_URL}/api/4.0/users/search"
    headers = {"Authorization": f"Bearer {token}"}

    params = {
        "fields": ",".join([
            "id",
            "display_name",
            "email",
            "is_disabled",
            "is_service_account",
            "last_login_at",
            "last_active_at"
        ]),
        "limit": 5000
    }

    resp = requests.get(url, headers=headers, params=params)
    resp.raise_for_status()
    return resp.json()

def main():
    token = get_access_token()
    users = get_all_users(token)

    df = pd.DataFrame(users)

    # Sort by last activity (most recent first)
    df = df.sort_values(by="last_active_at", ascending=False)

    print(df)

    # Optional: save to CSV for audit
    df.to_csv("looker_user_activity_audit.csv", index=False)
    print("\nSaved to looker_user_activity_audit.csv")

if __name__ == "__main__":
    main()
