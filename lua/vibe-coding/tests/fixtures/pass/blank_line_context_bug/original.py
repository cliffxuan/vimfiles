import json
import sys
from glob import glob
from pathlib import Path
from typing import Any, Dict, List

import gr_signin
import requests
import typer
import urllib3