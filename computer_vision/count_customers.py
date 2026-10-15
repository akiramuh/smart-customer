"""Count people crossing a virtual line using Ultralytics YOLO tracking.

Run from the computer_vision folder:
    python count_customers.py

Press Q in the video window to quit. This script counts line crossings locally;
Firestore integration is intentionally not included yet.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Dict

import cv2
from ultralytics import YOLO


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Count people entering/exiting by crossing a line in webcam video."
    )
    parser.add_argument(
        "--camera", type=int, default=0, help="Camera device index (default: 0)."
    )
    parser.add_argument(
        "--model",
        type=str,
        default=None,
        help="Optional path to YOLO weights (default: yolo26n.pt beside this script).",
    )
    parser.add_argument(
        "--confidence", type=float, default=0.35,
        help="Detection confidence threshold between 0 and 1 (default: 0.35).",
    )
    parser.add_argument(
        "--line-ratio", type=float, default=0.60,
        help="Horizontal counting-line position as a frame-height ratio (default: 0.60).",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if not 0.0 <= args.confidence <= 1.0:
        raise SystemExit("--confidence must be between 0 and 1.")
    if not 0.05 <= args.line_ratio <= 0.95:
        raise SystemExit("--line-ratio must be between 0.05 and 0.95.")

    script_dir = Path(__file__).resolve().parent
    model_path = Path(args.model).expanduser() if args.model else script_dir / "yolo26n.pt"
    # Ultralytics can download the standard model when only its filename is used.
    model_source = str(model_path) if model_path.exists() else (
        args.model if args.model else "yolo26n.pt"
    )

    print(f"Loading YOLO model: {model_source}")
    model = YOLO(model_source)

    camera = cv2.VideoCapture(args.camera, cv2.CAP_DSHOW if hasattr(cv2, "CAP_DSHOW") else 0)
    if not camera.isOpened():
        camera.release()
        camera = cv2.VideoCapture(args.camera)
    if not camera.isOpened():
        raise SystemExit(
            f"Could not open camera index {args.camera}. Close other camera apps or try --camera 1."
        )

    entries = 0
    exits = 0
    previous_centers: Dict[int, int] = {}
    print("Webcam counting started. Press Q in the video window to stop.")

    try:
        while True:
            ok, frame = camera.read()
            if not ok:
                print("Could not read a frame from the camera; stopping.")
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

            cv2.line(frame, (0, line_y), (width, line_y), (0, 220, 255), 2)
            cv2.putText(
                frame,
                "COUNTING LINE",
                (12, max(25, line_y - 10)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.6,
                (0, 220, 255),
                2,
                cv2.LINE_AA,
            )

            boxes = result.boxes
            if boxes is not None and boxes.id is not None:
                xyxy = boxes.xyxy.cpu().tolist()
                track_ids = boxes.id.int().cpu().tolist()

                for coords, track_id in zip(xyxy, track_ids):
                    x1, y1, x2, y2 = (int(value) for value in coords)
                    center_x = (x1 + x2) // 2
                    center_y = (y1 + y2) // 2
                    old_y = previous_centers.get(track_id)

                    # Moving from above to below the line = entry.
                    if old_y is not None and old_y < line_y <= center_y:
                        entries += 1
                        print(f"ENTRY +1 | entries={entries}, exits={exits}")
                    # Moving from below to above the line = exit.
                    elif old_y is not None and old_y > line_y >= center_y:
                        exits += 1
                        print(f"EXIT  +1 | entries={entries}, exits={exits}")

                    previous_centers[track_id] = center_y
                    cv2.rectangle(frame, (x1, y1), (x2, y2), (50, 210, 90), 2)
                    cv2.circle(frame, (center_x, center_y), 4, (50, 210, 90), -1)
                    cv2.putText(
                        frame,
                        f"Person ID {track_id}",
                        (x1, max(20, y1 - 8)),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        0.55,
                        (50, 210, 90),
                        2,
                        cv2.LINE_AA,
                    )

            current_inside = max(0, entries - exits)
            cv2.rectangle(frame, (8, 8), (280, 100), (25, 32, 48), -1)
            cv2.putText(frame, f"Masuk: {entries}", (20, 35), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            cv2.putText(frame, f"Keluar: {exits}", (20, 61), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            cv2.putText(frame, f"Di dalam (estimasi): {current_inside}", (20, 87), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1)

            cv2.imshow("Smart Customer - YOLO Person Counting", frame)
            key = cv2.waitKey(1) & 0xFF
            if key == ord("q"):
                break
    finally:
        camera.release()
        cv2.destroyAllWindows()

    print("Counting stopped.")
    print(f"Total entries: {entries}")
    print(f"Total exits:   {exits}")


if __name__ == "__main__":
    main()
