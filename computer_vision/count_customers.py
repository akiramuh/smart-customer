"""Count people crossing a virtual line and publish aggregate stats to Firestore.

Operational mode is headless by default: no video window, frames or bounding boxes
are shown or uploaded. Use --preview only for local debugging.

Example (PowerShell):
  python count_customers.py --credentials "C:\\secure\\smart-customer-service-account.json"

The credentials JSON must remain outside the repository and must never be committed.
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any

import cv2
import firebase_admin
from firebase_admin import credentials, firestore, messaging
from ultralytics import YOLO


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Count people crossing a virtual line and publish counts to Firestore."
    )
    parser.add_argument("--camera", type=int, default=0, help="Camera device index (default: 0).")
    parser.add_argument(
        "--model", type=str, default=None,
        help="Optional YOLO weights path (default: yolo26n.pt beside this script).",
    )
    parser.add_argument(
        "--confidence", type=float, default=0.35,
        help="Detection confidence threshold between 0 and 1 (default: 0.35).",
    )
    parser.add_argument(
        "--line-ratio", type=float, default=0.60,
        help="Counting-line position as a fraction of frame height (0.05–0.95).",
    )
    parser.add_argument(
        "--credentials", "--service-account", dest="credentials", default=None,
        help="Path to Firebase service-account JSON; never put this file in Git.",
    )
    parser.add_argument(
        "--project-id", default=None,
        help="Firebase/GCP project ID (defaults to the service account's project ID).",
    )
    parser.add_argument(
        "--camera-id", default="minimarket-main",
        help="Stable identifier for this camera (default: minimarket-main).",
    )
    parser.add_argument(
        "--max-capacity", type=int, default=40,
        help="Store capacity used by the dashboard (default: 40).",
    )
    parser.add_argument(
        "--alert-threshold", type=int, default=5,
        help="Send an FCM alert when estimated occupancy crosses this threshold (default: 5).",
    )
    parser.add_argument(
        "--publish-seconds", type=float, default=15.0,
        help="Firestore heartbeat interval in seconds (default: 15).",
    )
    parser.add_argument(
        "--snapshot-seconds", type=float, default=60.0,
        help="Historical chart snapshot interval in seconds (default: 60).",
    )
    parser.add_argument(
        "--preview", action="store_true",
        help="Show local debug video with bounding boxes. Disabled by default.",
    )
    return parser.parse_args()


def local_date_key() -> str:
    return datetime.now().astimezone().date().isoformat()


def create_firestore_client(args: argparse.Namespace):
    """Initialize Firebase Admin SDK. Server-side writes bypass client rules."""
    project_id = args.project_id or os.getenv("GOOGLE_CLOUD_PROJECT") or os.getenv("GCLOUD_PROJECT")

    if args.credentials:
        credentials_path = Path(args.credentials).expanduser().resolve()
        if not credentials_path.is_file():
            raise SystemExit(f"Service-account file not found: {credentials_path}")
        cred = credentials.Certificate(str(credentials_path))
        project_id = project_id or cred.project_id
        options: dict[str, str] = {}
        if project_id:
            options["projectId"] = project_id
        app = firebase_admin.initialize_app(cred, options=options or None)
    else:
        # Uses Application Default Credentials, such as `gcloud auth application-default login`.
        options = {"projectId": project_id} if project_id else None
        try:
            app = firebase_admin.initialize_app(options=options)
        except ValueError as exc:
            raise SystemExit(
                "Firebase credentials are not configured. Pass --credentials <path-to-json> "
                "or configure Application Default Credentials. Keep credential files outside Git."
            ) from exc

    if not project_id:
        project_id = app.project_id
    if not project_id:
        raise SystemExit("Project ID could not be determined. Pass --project-id explicitly.")
    print(f"Connected to Firebase project: {project_id}")
    return firestore.client(app=app)


class FirestorePublisher:
    """Persists a durable current state and periodically writes chart snapshots."""

    def __init__(self, db: Any, camera_id: str, max_capacity: int, snapshot_seconds: float):
        self.db = db
        self.camera_id = camera_id
        self.max_capacity = max_capacity
        self.snapshot_seconds = snapshot_seconds
        self.state_ref = db.collection("visitor_state").document(camera_id)
        self.activity_collection = db.collection("visitor_activity")
        self.current_activity_ref = self.activity_collection.document(f"current_{camera_id}")
        self.last_snapshot_at = 0.0

    def load_state(self) -> tuple[int, int, int, str]:
        """Return entries today, exits today, current occupancy and current date key."""
        today = local_date_key()
        snap = self.state_ref.get()
        data = snap.to_dict() or {}
        current = max(0, self._to_int(data.get("jumlahDiDalam")))
        saved_date = data.get("dateKey")
        if saved_date == today:
            entries = max(0, self._to_int(data.get("totalMasuk")))
            exits = max(0, self._to_int(data.get("totalKeluar")))
        else:
            # Daily entry/exit counters reset at local midnight; occupancy is retained.
            entries, exits = 0, 0
        print(f"Restored state: inside={current}, entries_today={entries}, exits_today={exits}")
        return entries, exits, current, today

    @staticmethod
    def _to_int(value: Any) -> int:
        return int(value) if isinstance(value, (int, float)) else 0

    def publish(
        self,
        entries: int,
        exits: int,
        current_inside: int,
        *,
        sensor_online: bool,
        force_snapshot: bool = False,
    ) -> None:
        date_key = local_date_key()
        state_payload = {
            "cameraId": self.camera_id,
            "dateKey": date_key,
            "jumlahDiDalam": max(0, current_inside),
            "totalMasuk": max(0, entries),
            "totalKeluar": max(0, exits),
            "maxCapacity": self.max_capacity,
            "sensorOnline": sensor_online,
            "updatedBy": "yolo-python",
            "schemaVersion": 1,
            "timestamp": firestore.SERVER_TIMESTAMP,
        }

        # Durable producer state makes counts survive a script restart.
        self.state_ref.set(state_payload, merge=True)
        # The existing Flutter RealtimeService reads the newest document in this collection.
        self.current_activity_ref.set(state_payload, merge=True)

        now = time.monotonic()
        if force_snapshot or self.last_snapshot_at == 0 or now - self.last_snapshot_at >= self.snapshot_seconds:
            snapshot_payload = dict(state_payload)
            snapshot_payload["isSnapshot"] = True
            self.activity_collection.add(snapshot_payload)
            self.last_snapshot_at = now


FCM_ALERT_TOPIC = "smart_customer_alerts"
FCM_NOTIFICATION_CHANNEL = "smart_customer_alerts"


def send_crowd_alert(current_inside: int, threshold: int, camera_id: str) -> str:
    """Send a crowd alert to Android devices subscribed to the FCM topic."""
    message = messaging.Message(
        notification=messaging.Notification(
            title="Smart Customer - Minimarket Ramai",
            body=(
                f"Jumlah pengunjung di dalam minimarket sudah mencapai "
                f"{current_inside} orang (ambang ramai: {threshold})."
            ),
        ),
        data={
            "event": "crowd_threshold_reached",
            "cameraId": camera_id,
            "jumlahDiDalam": str(current_inside),
            "alertThreshold": str(threshold),
        },
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                channel_id=FCM_NOTIFICATION_CHANNEL,
                sound="default",
                tag="smart_customer_crowd_alert",
            ),
        ),
        topic=FCM_ALERT_TOPIC,
    )
    return messaging.send(message)


def open_camera(index: int):
    # DirectShow tends to be more reliable on Windows; fall back to OpenCV default.
    if hasattr(cv2, "CAP_DSHOW") and os.name == "nt":
        camera = cv2.VideoCapture(index, cv2.CAP_DSHOW)
        if camera.isOpened():
            return camera
        camera.release()
    return cv2.VideoCapture(index)


def main() -> None:
    args = parse_args()
    if not 0.0 <= args.confidence <= 1.0:
        raise SystemExit("--confidence must be between 0 and 1.")
    if not 0.05 <= args.line_ratio <= 0.95:
        raise SystemExit("--line-ratio must be between 0.05 and 0.95.")
    if args.max_capacity < 1:
        raise SystemExit("--max-capacity must be at least 1.")
    if args.alert_threshold < 1:
        raise SystemExit("--alert-threshold must be at least 1.")
    if args.publish_seconds < 5:
        raise SystemExit("--publish-seconds must be at least 5 to avoid excessive database writes.")
    if args.snapshot_seconds < 30:
        raise SystemExit("--snapshot-seconds must be at least 30 to avoid excessive database writes.")
    if not args.camera_id.strip():
        raise SystemExit("--camera-id must not be empty.")

    db = create_firestore_client(args)
    publisher = FirestorePublisher(db, args.camera_id.strip(), args.max_capacity, args.snapshot_seconds)
    entries, exits, current_inside, active_date = publisher.load_state()

    script_dir = Path(__file__).resolve().parent
    model_path = Path(args.model).expanduser() if args.model else script_dir / "yolo26n.pt"
    model_source = str(model_path) if model_path.exists() else (args.model or "yolo26n.pt")
    print(f"Loading YOLO model: {model_source}")
    model = YOLO(model_source)

    camera = open_camera(args.camera)
    if not camera.isOpened():
        camera.release()
        try:
            publisher.publish(entries, exits, current_inside, sensor_online=False, force_snapshot=True)
        except Exception as exc:  # noqa: BLE001 - show the Firestore failure before exiting.
            print(f"Could not publish offline state: {exc}", file=sys.stderr)
        raise SystemExit(
            f"Could not open camera index {args.camera}. Close other camera apps or try --camera 1."
        )

    previous_centers: dict[int, int] = {}
    # Only alert on an observed crossing from below the threshold to at/above it.
    # If the script starts with occupancy already above the threshold, it will not
    # send a duplicate alert until occupancy falls below and crosses again.
    alert_pending = False
    last_alert_attempt = 0.0
    print("Customer counting and Firestore publishing started.")
    print(f"Crowd alert threshold: {args.alert_threshold} people; FCM topic: {FCM_ALERT_TOPIC}")
    if args.preview:
        print("Preview/debug mode enabled. Press Q or Esc to stop.")
    else:
        print("Headless operational mode: no video window or bounding boxes will be displayed.")
    print("Stop with Ctrl+C in this terminal.")

    last_publish = 0.0
    count_changed = False
    try:
        # Publish an initial healthy heartbeat once the camera has opened.
        publisher.publish(entries, exits, current_inside, sensor_online=True, force_snapshot=True)
        last_publish = time.monotonic()

        while True:
            ok, frame = camera.read()
            if not ok:
                print("Could not read a frame from the camera; stopping.", file=sys.stderr)
                break

            height, width = frame.shape[:2]
            line_y = int(height * args.line_ratio)
            result = model.track(
                frame,
                persist=True,
                tracker="bytetrack.yaml",
                classes=[0],  # COCO class 0 = person
                conf=args.confidence,
                verbose=False,
            )[0]

            boxes = result.boxes
            if boxes is not None and boxes.id is not None:
                xyxy = boxes.xyxy.cpu().tolist()
                track_ids = boxes.id.int().cpu().tolist()
                for coords, track_id in zip(xyxy, track_ids):
                    x1, y1, x2, y2 = (int(value) for value in coords)
                    center_x = (x1 + x2) // 2
                    center_y = (y1 + y2) // 2
                    old_y = previous_centers.get(track_id)

                    if old_y is not None and old_y < line_y <= center_y:
                        previous_inside = current_inside
                        entries += 1
                        current_inside += 1
                        count_changed = True
                        print(f"ENTRY +1 | entries={entries}, exits={exits}, inside={current_inside}")
                        if previous_inside < args.alert_threshold <= current_inside:
                            alert_pending = True
                    elif old_y is not None and old_y > line_y >= center_y:
                        exits += 1
                        current_inside = max(0, current_inside - 1)
                        count_changed = True
                        print(f"EXIT -1 | entries={entries}, exits={exits}, inside={current_inside}")
                        if current_inside < args.alert_threshold:
                            alert_pending = False

                    previous_centers[track_id] = center_y

                    if args.preview:
                        cv2.rectangle(frame, (x1, y1), (x2, y2), (50, 210, 90), 2)
                        cv2.circle(frame, (center_x, center_y), 4, (50, 210, 90), -1)
                        cv2.putText(
                            frame, f"Person ID {track_id}", (x1, max(20, y1 - 8)),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.55, (50, 210, 90), 2, cv2.LINE_AA,
                        )

            now = time.monotonic()
            if (
                alert_pending
                and current_inside >= args.alert_threshold
                and now - last_alert_attempt >= 10.0
            ):
                last_alert_attempt = now
                try:
                    message_id = send_crowd_alert(
                        current_inside,
                        args.alert_threshold,
                        args.camera_id.strip(),
                    )
                    print(
                        f"FCM crowd alert sent to topic '{FCM_ALERT_TOPIC}': {message_id}"
                    )
                    alert_pending = False
                except Exception as exc:  # noqa: BLE001 - retry after a short delay.
                    print(
                        f"FCM alert send failed; will retry: {exc}",
                        file=sys.stderr,
                    )
            today = local_date_key()
            if today != active_date:
                active_date = today
                entries, exits = 0, 0
                count_changed = True
                print("New local day detected; daily entry/exit totals reset.")

            if count_changed or now - last_publish >= args.publish_seconds:
                try:
                    publisher.publish(entries, exits, current_inside, sensor_online=True)
                    last_publish = now
                    count_changed = False
                except Exception as exc:  # noqa: BLE001 - retry on the next heartbeat.
                    print(f"Firestore publish failed; will retry: {exc}", file=sys.stderr)
                    # Keep count_changed true so the current state retries next frame.
                    last_publish = now

            if args.preview:
                cv2.line(frame, (0, line_y), (width, line_y), (0, 220, 255), 2)
                cv2.putText(
                    frame, "COUNTING LINE", (12, max(25, line_y - 10)),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 220, 255), 2, cv2.LINE_AA,
                )
                cv2.rectangle(frame, (8, 8), (340, 105), (25, 32, 48), -1)
                cv2.putText(frame, f"Masuk: {entries}", (20, 35), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
                cv2.putText(frame, f"Keluar: {exits}", (20, 61), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
                cv2.putText(frame, f"Di dalam (estimasi): {current_inside}", (20, 88), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1)
                cv2.imshow("Smart Customer - Debug Preview", frame)
                key = cv2.waitKey(1) & 0xFF
                if key in (ord("q"), 27):
                    break
    except KeyboardInterrupt:
        print("Stop requested by user (Ctrl+C).")
    finally:
        camera.release()
        if args.preview:
            cv2.destroyAllWindows()
        try:
            publisher.publish(entries, exits, current_inside, sensor_online=False, force_snapshot=True)
        except Exception as exc:  # noqa: BLE001
            print(f"Could not publish final offline state: {exc}", file=sys.stderr)

    print("Counting stopped.")
    print(f"Total entries today: {entries}")
    print(f"Total exits today:   {exits}")
    print(f"Estimated inside:    {current_inside}")


if __name__ == "__main__":
    main()
