# Smart Customer — Computer Vision

A first local prototype for people detection, tracking, and line-crossing counts using Ultralytics YOLO and ByteTrack.

## Contents

- `count_customers.py` — webcam person tracking and entry/exit line-crossing counts.
- `requirements.txt` — Python package dependencies.
- `yolo26n.pt` — place the model weights in this folder if you want to use a local copy. If the file is absent, Ultralytics may download the standard `yolo26n.pt` weights when online.

## Setup (Windows PowerShell)

From this folder, create/activate a virtual environment if needed, then run:

```powershell
python -m pip install -r requirements.txt
python count_customers.py
```

Optional arguments:

```powershell
python count_customers.py --camera 1
python count_customers.py --confidence 0.4 --line-ratio 0.55
```

Press `Q` while the video window is focused to stop.

## Notes and limitations

- This prototype counts a tracked person when their center crosses a horizontal line: top-to-bottom is counted as entry, bottom-to-top as exit. Position the camera so movement follows that convention, or adjust the line position with `--line-ratio`.
- Tracker IDs can switch or be lost when people are occluded; line-crossing counts may therefore be imperfect. Test and calibrate camera placement before relying on the numbers.
- Counts are currently displayed locally and printed in the terminal. **Firestore publishing is not implemented in this script yet.**
- Do not commit the Python virtual environment (`.venv`). Keep dependencies in `requirements.txt` instead.
