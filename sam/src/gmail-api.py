import argparse
import base64
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

SCOPES = ["https://www.googleapis.com/auth/gmail.readonly"]
BASE_DIR = Path(__file__).resolve().parent.parent
CREDENTIALS_PATH = BASE_DIR / "credentials.json"
TOKEN_PATH = BASE_DIR / "token.json"
STATE_PATH = BASE_DIR / "gmail_watch_state.json"


def load_credentials() -> Credentials:
    creds = None
    if TOKEN_PATH.exists():
        creds = Credentials.from_authorized_user_file(str(TOKEN_PATH), SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                str(CREDENTIALS_PATH), SCOPES
            )
            creds = flow.run_local_server(port=0)
        TOKEN_PATH.write_text(creds.to_json(), encoding="utf-8")

    return creds


def gmail_service():
    return build("gmail", "v1", credentials=load_credentials())


def load_state() -> dict[str, Any]:
    if not STATE_PATH.exists():
        return {}
    return json.loads(STATE_PATH.read_text(encoding="utf-8"))


def save_state(state: dict[str, Any]) -> None:
    STATE_PATH.write_text(json.dumps(state, indent=2), encoding="utf-8")


def header_map(payload: dict[str, Any]) -> dict[str, str]:
    headers = payload.get("headers", [])
    return {header["name"]: header["value"] for header in headers}


def print_message_summary(service, message_id: str) -> None:
    message = (
        service.users().messages().get(userId="me", id=message_id, format="full").execute()
    )
    payload = message.get("payload", {})
    headers = header_map(payload)
    sender = headers.get("From", "(no sender)")
    subject = headers.get("Subject", "(no subject)")
    date = headers.get("Date", "(no date)")
    snippet = message.get("snippet", "").strip() or "(no preview text)"

    print(f"From: {sender}")
    print(f"Subject: {subject}")
    print(f"Date: {date}")
    print(f"Snippet: {snippet}")
    print()


def register_watch(topic_name: str, label_ids: list[str]) -> None:
    service = gmail_service()
    body: dict[str, Any] = {"topicName": topic_name}
    if label_ids:
        body["labelIds"] = label_ids
        body["labelFilterBehavior"] = "INCLUDE"

    response = service.users().watch(userId="me", body=body).execute()
    state = load_state()
    state.update(
        {
            "topicName": topic_name,
            "labelIds": label_ids,
            "historyId": response.get("historyId"),
            "expiration": response.get("expiration"),
        }
    )
    save_state(state)

    print("Gmail watch registered.")
    print(f"Topic: {topic_name}")
    print(f"History ID: {response.get('historyId')}")
    print(f"Expiration (ms since epoch): {response.get('expiration')}")


def stop_watch() -> None:
    service = gmail_service()
    service.users().stop(userId="me").execute()
    state = load_state()
    state["stopped"] = True
    save_state(state)
    print("Gmail watch stopped.")


def decode_pubsub_message(envelope: dict[str, Any]) -> dict[str, Any]:
    message = envelope.get("message", {})
    data = message.get("data", "")
    if not data:
        return {}

    padding = "=" * (-len(data) % 4)
    decoded = base64.urlsafe_b64decode(data + padding).decode("utf-8")
    return json.loads(decoded)


def process_history(service, history_id: str | None) -> str | None:
    if not history_id:
        print("No stored historyId yet; register a watch first.")
        return history_id

    response = (
        service.users()
        .history()
        .list(userId="me", startHistoryId=history_id, historyTypes=["messageAdded"])
        .execute()
    )

    history = response.get("history", [])
    seen_ids: set[str] = set()

    for record in history:
        for item in record.get("messagesAdded", []):
            message = item.get("message", {})
            message_id = message.get("id")
            if not message_id or message_id in seen_ids:
                continue
            seen_ids.add(message_id)
            print_message_summary(service, message_id)

    next_history_id = response.get("historyId", history_id)
    state = load_state()
    state["historyId"] = next_history_id
    save_state(state)
    return next_history_id


def build_handler():
    class PubSubHandler(BaseHTTPRequestHandler):
        def do_POST(self):
            content_length = int(self.headers.get("Content-Length", "0"))
            raw_body = self.rfile.read(content_length)

            try:
                envelope = json.loads(raw_body.decode("utf-8"))
                notification = decode_pubsub_message(envelope)
                history_id = notification.get("historyId")
                email_address = notification.get("emailAddress")

                print("Received Gmail push notification.")
                print(f"Email address: {email_address}")
                print(f"Incoming history ID: {history_id}")

                service = gmail_service()
                state = load_state()
                prior_history_id = state.get("historyId")
                if prior_history_id:
                    process_history(service, prior_history_id)
                else:
                    state["historyId"] = history_id
                    save_state(state)
                    print("Stored initial historyId from notification.")

                if history_id:
                    state = load_state()
                    state["historyId"] = history_id
                    save_state(state)

                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"ok")
            except Exception as exc:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(str(exc).encode("utf-8"))

        def log_message(self, format, *args):
            return

    return PubSubHandler


def serve(host: str, port: int) -> None:
    server = ThreadingHTTPServer((host, port), build_handler())
    print(f"Listening for Pub/Sub push notifications on http://{host}:{port}")
    print("This endpoint must be reachable by Google Pub/Sub to receive pushes.")
    server.serve_forever()


def pull_history() -> None:
    service = gmail_service()
    state = load_state()
    history_id = state.get("historyId")
    next_history_id = process_history(service, history_id)
    if next_history_id == history_id:
        print("No new messageAdded history entries found.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Register and handle Gmail push notifications."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    watch_parser = subparsers.add_parser("watch", help="Register Gmail watch")
    watch_parser.add_argument(
        "--topic",
        required=True,
        help="Pub/Sub topic name, for example projects/PROJECT_ID/topics/TOPIC_NAME",
    )
    watch_parser.add_argument(
        "--label",
        action="append",
        default=["INBOX"],
        help="Gmail label to include. Repeatable. Defaults to INBOX.",
    )

    subparsers.add_parser("stop", help="Stop Gmail watch")
    subparsers.add_parser(
        "pull-history",
        help="Fetch messageAdded changes since the last stored historyId",
    )

    serve_parser = subparsers.add_parser(
        "serve", help="Run a simple HTTP endpoint for Pub/Sub push delivery"
    )
    serve_parser.add_argument("--host", default="127.0.0.1")
    serve_parser.add_argument("--port", type=int, default=8080)

    return parser


def main() -> None:
    args = build_parser().parse_args()

    try:
        if args.command == "watch":
            register_watch(args.topic, args.label)
        elif args.command == "stop":
            stop_watch()
        elif args.command == "pull-history":
            pull_history()
        elif args.command == "serve":
            serve(args.host, args.port)
    except HttpError as error:
        print(f"An error occurred: {error}")


if __name__ == "__main__":
    main()
