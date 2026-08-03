import os
import httpx


class StravaClient:
    def __init__(self) -> None:
        self.client_id = os.getenv("STRAVA_CLIENT_ID", "")
        self.client_secret = os.getenv("STRAVA_CLIENT_SECRET", "")
        self.base_url = "https://www.strava.com/api/v3"

    def list_recent_activities(self, access_token: str, per_page: int = 50):
        headers = {"Authorization": f"Bearer {access_token}"}
        with httpx.Client(timeout=20) as client:
            resp = client.get(
                f"{self.base_url}/athlete/activities",
                params={"per_page": per_page, "page": 1},
                headers=headers,
            )
            resp.raise_for_status()
            return resp.json()
