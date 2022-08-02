#!/usr/bin/env bash
firefox localhost:8000/build/index.html
python3 -m http.server 8000
