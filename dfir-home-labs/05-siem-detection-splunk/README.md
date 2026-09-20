# Lab 5: SIEM Detection Engineering (Splunk)

**Status:** Not yet started - fill in once completed

## Objective

Build a detection search from scratch against a raw security dataset, rather than tuning an existing
rule - going one step beyond alert triage into detection content development.

## Tools

- [Splunk Enterprise (free trial)](https://www.splunk.com/en_us/download/splunk-enterprise.html)
- [Boss of the SOC (BOTS) dataset](https://github.com/splunk/botsv3) - free security dataset built by Splunk for training

## Process

<!-- Fill in once completed: your search queries, in order, with reasoning -->

1. `index=botsv1 | stats count by sourcetype` - oriented on available data sources
2.
3.

## Findings

<!-- What did you find? What detection did you build? -->

## What this demonstrates

I work with Splunk daily for alert triage - this lab demonstrates the other side of that skill: building
a detection from raw data rather than working from an existing alert.
