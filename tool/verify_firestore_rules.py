#!/usr/bin/env python3
"""Live isolation smoke test using disposable accounts; never logs credentials.

Run explicitly: python3 tool/verify_firestore_rules.py --live
Reads the public Android Firebase config. Creates and removes synthetic accounts
and documents only. Does not use or modify existing users or reminder content.
"""
import argparse
import json
from pathlib import Path
import secrets
import urllib.error
import urllib.parse
import urllib.request


def request(url, payload=None, token=None, method=None, expected=200):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(url, data=None if payload is None else json.dumps(payload).encode(), headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            status, raw = response.status, response.read()
    except urllib.error.HTTPError as error:
        status, raw = error.code, error.read()
    if status != expected:
        # Avoid echoing response bodies which may contain session credentials.
        raise RuntimeError(f"Expected HTTP {expected}, received {status}")
    return json.loads(raw) if raw else {}


def fields(value):
    if value is None:
        return {"nullValue": None}
    if isinstance(value, bool):
        return {"booleanValue": value}
    if isinstance(value, int):
        return {"integerValue": str(value)}
    if isinstance(value, str):
        return {"stringValue": value}
    if isinstance(value, list):
        return {"arrayValue": {"values": [fields(item) for item in value]}}
    return {"mapValue": {"fields": {key: fields(item) for key, item in value.items()}}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live", action="store_true", required=True)
    parser.parse_args()
    config = json.loads(Path("android/app/google-services.json").read_text())
    project = config["project_info"]["project_id"]
    key = config["client"][0]["api_key"][0]["current_key"]
    auth = "https://identitytoolkit.googleapis.com/v1/accounts:"
    root = f"projects/{project}/databases/(default)/documents"
    base = "https://firestore.googleapis.com/v1/" + root
    accounts, created = [], []

    def account(anonymous=False):
        payload = {"returnSecureToken": True}
        if not anonymous:
            payload.update(email="shien-smoke-" + secrets.token_hex(8) + "@example.com", password=secrets.token_urlsafe(24))
        result = request(auth + "signUp?key=" + key, payload)
        accounts.append(result)
        return result, payload

    def write(user, path, data, expected=200):
        name = root + "/" + path
        body = {"writes": [{"update": {"name": name, "fields": fields(data)["mapValue"]["fields"]}, "updateTransforms": [{"fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME"}]}]}
        result = request(base + ":commit", body, user["idToken"], expected=expected)
        if expected == 200 and (user["idToken"], path) not in created:
            created.append((user["idToken"], path))
        return result

    try:
        alice, credentials = account()
        bob, _ = account()
        guest, _ = account(anonymous=True)
        uid = alice["localId"]
        path = f"users/{uid}/reminders/smoke"
        record = {"schemaVersion": 3, "id": "smoke", "title": "Disposable sync test", "note": "", "anchorAt": "2026-12-01T09:00:00.000", "dueAt": "2026-12-01T09:00:00.000", "createdAt": "2026-10-30T00:00:00.000", "category": "general", "repeat": "once", "weekdays": [], "interval": 1, "lastDayOfMonth": False, "additionalTimes": [], "leadMinutes": 0, "isPriority": False, "tags": [], "sound": "soft", "isPaused": False, "isCompleted": False, "snoozedUntil": None}
        write(alice, path, {"data": record, "mutationId": "test-insert"})
        request(base + "/" + path, token=alice["idToken"])
        print("PASS: owner can create and read a reminder", flush=True)
        request(base + "/" + path, token=bob["idToken"], expected=403)
        write(bob, path, {"data": record, "mutationId": "blocked"}, expected=403)
        request(base + "/" + path, expected=403)
        write(guest, f'users/{guest["localId"]}/reminders/smoke', {"data": record, "mutationId": "blocked"}, expected=403)
        print("PASS: other accounts, anonymous accounts and unauthenticated access are denied", flush=True)
        second = request(auth + "signInWithPassword?key=" + key, credentials)
        request(base + "/" + path, token=second["idToken"])
        print("PASS: same account can read from a second session", flush=True)
        write(alice, f"users/{uid}/profile/main", {"displayName": "Sync Test", "photoBase64": None, "photoHidden": True})
        request(base + f"/users/{uid}/profile/main", token=bob["idToken"], expected=403)
        print("PASS: private profile is isolated", flush=True)
        write(alice, path, {"data": None, "mutationId": "test-delete"})
        result = request(base + "/" + path, token=second["idToken"])
        assert "nullValue" in result["fields"]["data"]
        print("PASS: deletion tombstone reaches the second session", flush=True)
        write(alice, f"users/{uid}", {"deleted": True})
        write(alice, path, {"data": record, "mutationId": "blocked-after-delete"}, expected=403)
        print("PASS: account deletion blocks new writes from existing sessions", flush=True)
    finally:
        failures = 0
        for token, path in reversed(created):
            try:
                request(base + "/" + urllib.parse.quote(path, safe="/"), token=token, method="DELETE")
            except Exception:
                failures += 1
        for user in accounts:
            try:
                request(auth + "delete?key=" + key, {"idToken": user["idToken"]})
            except Exception:
                failures += 1
        if failures:
            raise RuntimeError(f"Cleanup incomplete for {failures} disposable test resources")
        print("PASS: disposable test documents and accounts removed", flush=True)


if __name__ == "__main__":
    main()
