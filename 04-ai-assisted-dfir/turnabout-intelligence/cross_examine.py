import os
import time
from google import genai
from google.genai import errors

client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])

EVIDENCE_FILE = "evidence.txt"   

# read the task/question
ask = open("ask.txt", encoding="utf-8").read()

# read the evidence file
with open(EVIDENCE_FILE, encoding="utf-8") as f:
    evidence = f.read()

# build the prompt
prompt = ask + "\n\n--- EVIDENCE ---\n" + evidence

# send it, with retry-on-busy (503)
resp = None
for attempt in range(5):
    try:
        resp = client.models.generate_content(
            model="gemini-3.5-flash-lite",
            contents=prompt
        )
        break
    except errors.ServerError as e:
        wait = 2 ** attempt
        print(f"Witness busy (try {attempt+1}/5) - waiting {wait}s...")
        time.sleep(wait)

if resp is None:
    print("Witness unavailable after 5 tries. Try again later.")
    raise SystemExit

# save the testimony
with open("A_rev2_flash-lite.txt", "w", encoding="utf-8") as f:
    f.write(resp.text)
print(resp.text)