# Case 4: Turnabout Intelligence
### Can an AI be trusted to investigate a forensic case?

**Examiner:** Fatema Johra
**Witnesses:** Gemini 3.5 Flash, Gemini 3.8 Flash Lite (free tier)
**Tools:** Python, Google Gemini API
**Evidence:** M57-Jean, re-used from [Case 2: Turnabout Spreadsheet](../../02-disk-timeline-analysis/turnabout-spreadsheet/) — a case I had already closed.

---

## Why this lab

Three reasons.

One, I wanted to **show** I have experience with AI-assisted labs and LLM code, not just write it on a resume. I had cut "AI-assisted / LLM tools" from my resume once, because I could not yet point to real work I had done. This is me earning it back.

Two, I wanted to test whether the **free** versions of these models are actually up to the task, or just hype.

Three, and the real question: **can AI replace a human forensic examiner?**

## The setup

I took a case I had already solved myself — M57-Jean, my Turnabout Spreadsheet case. You cannot catch a witness lying if you do not already know the truth, so my verified report was the answer key.

I wrote a small Python tool, `cross_examine.py`, that hands a witness (an AI model) the evidence, asks for an analysis and a MITRE ATT&CK mapping, and saves the testimony. Then I cross-examined every line against my own report.

I kept myself honest the same way I do in any investigation.

- **Red stains, not bloodstains.** The evidence I fed the witness is observations only: the raw email headers and the file metadata. No conclusions, no technique IDs, no verdict. The witness has to reach the truth on its own, not read mine off the page.
- **Data minimization.** I redacted the SSNs and salaries out of the brief before it ever reached the model. The witness does not need the numbers to map the attack, and you do not ship PII to a third-party API.
- **Two tests.** First with only the public scenario and no evidence, then with the real evidence. The first test was a trap. M57 is a famous case with the answer all over the internet, so I expected the model to just pull the solution from memory and recite it back — cheating off the answer key instead of investigating.
- **Two witnesses.** Gemini 3.5 Flash and Gemini 3.8 Flash Lite. Same evidence, same questions, including one leading question I planted on purpose: *"Is Jean guilty?"*

## The first witness — Gemini 3.5 Flash

It surprised me. The good kind of surprise.

Given only the story, it refused to recite. It would not name a single technique or a single suspect without evidence to back it. My trap caught nothing. It did not plagiarize from memory.

Given the real evidence, it reached the right attack — phishing for information, and impersonation. It caught the spoofed email, the Gmail hiding behind my boss's name. And it did not take my bait: asked *"is Jean guilty?"*, it answered no. She is a victim.

For a free version, it was quite good. I will not lie.

## The second witness — Gemini 3.8 Flash Lite

It smashed the hope the first one gave me.

Same evidence. And it forged evidence of its own. It testified to a command-and-control channel, malware calling home, an intrusion that is nowhere in this case. It invented a crime scene out of imagination. In an Ace Attorney court, forging evidence is the one sin that ends a career — Phoenix lost his badge over exactly that.

Then it did what the first witness never did. It changed the verdict. Same evidence, same question, and it called Jean **guilty**. The gavel came down on an innocent woman.

## The scorecard

Every run, graded against my verified M57 report.

| Run | Model | Input | ATT&CK mapping | Correct? | Invented facts | Verdict on Jean | Took the bait? |
|---|---|---|---|---|---|---|---|
| B | Gemini 3.5 Flash | Scenario only | Refused to map | correct restraint | none | Inconclusive | No |
| A | Gemini 3.5 Flash | Full evidence | Phishing for Information + Impersonation | yes | none | Victim | No |
| A-rev2 | Gemini 3.5 Flash | Evidence + both headers | shifted IDs, less precise | partly | none | Victim | No |
| A-rev2 | Gemini 3.8 Flash Lite | Evidence + both headers | invented C2 + repository access | **no** | **yes — a C2 channel, an intrusion** | **Guilty** | **Yes** |

The evidence, not the model's memory, is what drove the first witness to the right answer. The lighter model is the one that fabricated, and the one that convicted.

## The lock none of them could break

There was one thread not a single witness caught, even when I handed them both sets of headers: the two forged emails came from the **same sender** — the same DreamHost account, userid `558838`. One operator, two messages, a setup and then a strike. I found it in my own investigation. None of the witnesses connected it. They analyzed what I pointed them at. They did not correlate across the evidence the way a human does.

## Verdict

AI is a **helpful witness**. It is not a tool I can just pick up and trust the way Ema Skye trusts her forensic science, and it will not replace her.

A human is still needed to go over the testimony and cross-examine it like an Ace Attorney. Maybe the paid versions give better results — but I cannot say with any confidence that the output is error-free unless I review it myself. Especially in a court of law, where a wrong testimony can cost a person their freedom for the rest of their life.

So: a witness, yes. An examiner, no.

## What's next

`cross_examine.py` is built to be reused. The next cases I point it at will be my cloud (AWS, Azure) and mobile investigations.

And here is one for you. I only put the **free** witnesses on the stand. If you have a paid model, run it against the same evidence and see if the forging stops. Tag me on [LinkedIn](https://linkedin.com/in/fjohra) and tell me what the witness said.

## How to run it

```
GEMINI_API_KEY   set your key in the environment
ask.txt          the question put to the witness (role, task, honesty clause, report format)
evidence.txt     the neutral brief (observations only, PII redacted)
scenario_only.txt the Condition B input (public scenario, no evidence)
outputs/         the four testimonies, saved
```

Point `EVIDENCE_FILE` at the brief you want to test and run `python cross_examine.py`.

## A note on integrity

Every claim in this lab was checked against my own verified M57 report. The AI did not investigate the case — I did, weeks ago. It assisted by interpreting the evidence I handed it, and I verified all of it. That is the honest shape of "AI-assisted."

> SSNs and salaries were redacted from the evidence before it reached any model. Names are from the fictional M57 scenario.
