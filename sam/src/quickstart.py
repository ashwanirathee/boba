import os.path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# If modifying these scopes, delete the file token.json.
SCOPES = ["https://www.googleapis.com/auth/gmail.readonly"]


def header_map(payload):
  headers = payload.get("headers", [])
  return {header["name"]: header["value"] for header in headers}


def main():
  """Reads the user's 10 most recent Gmail messages."""
  creds = None
  # The file token.json stores the user's access and refresh tokens, and is
  # created automatically when the authorization flow completes for the first
  # time.
  if os.path.exists("token.json"):
    creds = Credentials.from_authorized_user_file("token.json", SCOPES)
  # If there are no (valid) credentials available, let the user log in.
  if not creds or not creds.valid:
    if creds and creds.expired and creds.refresh_token:
      creds.refresh(Request())
    else:
      flow = InstalledAppFlow.from_client_secrets_file(
          "credentials.json", SCOPES
      )
      creds = flow.run_local_server(port=0)
    # Save the credentials for the next run
    with open("token.json", "w") as token:
      token.write(creds.to_json())

  try:
    # Call the Gmail API
    service = build("gmail", "v1", credentials=creds)
    results = (
        service.users()
        .messages()
        .list(userId="me", maxResults=10, labelIds=["INBOX"])
        .execute()
    )
    messages = results.get("messages", [])

    if not messages:
      print("No messages found.")
      return

    print("Last 10 emails:\n")
    for idx, message in enumerate(messages, start=1):
      full_message = (
          service.users()
          .messages()
          .get(userId="me", id=message["id"], format="full")
          .execute()
      )
      payload = full_message.get("payload", {})
      headers = header_map(payload)
      sender = headers.get("From", "(no sender)")
      subject = headers.get("Subject", "(no subject)")
      date = headers.get("Date", "(no date)")
      snippet = full_message.get("snippet", "").strip() or "(no preview text)"

      print(f"{idx}. From: {sender}")
      print(f"   Subject: {subject}")
      print(f"   Date: {date}")
      print(f"   Snippet: {snippet}")
      print()

  except HttpError as error:
    # TODO(developer) - Handle errors from gmail API.
    print(f"An error occurred: {error}")


if __name__ == "__main__":
  main()
