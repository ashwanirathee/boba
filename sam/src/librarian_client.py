from dataclasses import dataclass
from typing import Any

import requests


@dataclass
class LibrarianClient:
    base_url: str
    token: str
    timeout: float = 2.0

    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

    def health(self) -> dict[str, Any]:
        response = requests.get(
            f"{self.base_url.rstrip('/')}/health",
            timeout=self.timeout,
        )
        response.raise_for_status()
        return response.json()

    def query(
        self,
        query: str,
        limit: int = 4,
        collections: list[str] | None = None,
    ) -> dict[str, Any]:
        payload: dict[str, Any] = {"query": query, "limit": limit}
        if collections:
            payload["collections"] = collections

        response = requests.post(
            f"{self.base_url.rstrip('/')}/v1/query",
            headers=self._headers(),
            json=payload,
            timeout=self.timeout,
        )
        response.raise_for_status()
        return response.json()
