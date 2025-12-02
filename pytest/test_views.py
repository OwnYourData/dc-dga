import pytest
import os
import sys
import glob
import json
import requests
import subprocess
from pathlib import Path

cwd = os.getcwd()

dga_host = os.getenv('DGA_HOST') or "https://my.go-data.at"
session_token = os.getenv('SESSION_TOKEN') or ""

def test_service():
    response = requests.get(dga_host)
    assert response.status_code == 200

# iterate over all testcases
@pytest.mark.parametrize('input', glob.glob(cwd + '/01_input/*.view'))
def test(input):
    with open(input) as f:
        content = f.read()
    command = "curl -o /dev/null -s -w \"%{http_code}\" --cookie \"_dc_base_session=" + session_token + "\" " + dga_host + content
    # show output with "pytest -s"
    # print(f"\n[DEBUG] Executing command:\n{command}\n")
    process = subprocess.run(command, shell=True, capture_output=True, text=True)
    assert process.returncode == 0
    assert process.stdout.strip() == "200"
