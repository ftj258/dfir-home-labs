## Getting the SIEM lab a home (Oracle Cloud)

I wanted a working Wazuh SIEM for this lab, not just screenshots. Getting a machine to run it on turned out to be its own small investigation.

### First try: my laptop

I'm most comfortable in VMware, so I started there. I built an Ubuntu 26.04 Desktop VM with Wazuh's recommended minimum (4 vCPUs, 8 GB RAM, 60 GB disk) and put it on my D: drive with my other VMs.

It crawled. Then my whole laptop started lagging too.

Task Manager explained it. My laptop only has 7.7 GB of RAM total and it was sitting at 95%. I had given the VM more memory than the machine actually has. On top of that, D: is an external USB drive and it was pinned at 100% disk. Not a great place for Wazuh's indexer, which hits the disk hard.

I checked if I could add more RAM. I can't, it's not upgradeable on this laptop. Shrinking the VM to around 3 GB would put Wazuh under its own minimum, so that was out too.

### Second try: Oracle Cloud free tier

Oracle's Always Free tier gives you an Ampere A1 ARM instance with 2 OCPUs and 12 GB of RAM. That's enough for Wazuh, and it costs nothing.

Except every time I hit Create I got **"Out of host capacity."** I tried all three availability domains in Ashburn. I tried dropping to 1 OCPU / 6 GB. Same thing every time. The free A1 instances are popular and capacity only opens up when someone else's instance gets reclaimed.

### Third try: let a script keep trying for me

Instead of refreshing the console all day, I installed the OCI CLI and wrote [`retry-oci-a1-launch.ps1`](./retry-oci-a1-launch.ps1). It goes through each availability domain, waits, and tries again until one works. When it finally succeeds it saves the instance details, beeps and pops up a message so I don't miss it.

Things that broke along the way:

- **PowerShell wouldn't run the OCI installer.** Execution policy blocks scripts by default. I ran it once with `-ExecutionPolicy Bypass` rather than changing the setting for the whole system.
- **401 NotAuthenticated.** The API key in my config didn't match what I'd uploaded to Oracle. I compared the fingerprints to sort it out.
- **429 TooManyRequests.** My first version was too impatient. After 19 attempts Oracle rate-limited my account and the script quit. Now it pauses between tries, waits 5 minutes between rounds, and backs off longer (10, 20, 40, up to 60 minutes) if Oracle pushes back again.

### If you want to use it

1. Install the OCI CLI, run `oci setup config`, and upload your API public key in the Oracle console.
2. Copy `lab-config.example.json` to `lab-config.local.json` and fill in your own OCIDs, availability domains and SSH key path.
3. Run `powershell -ExecutionPolicy Bypass -File .\retry-oci-a1-launch.ps1` and leave it. Keep your computer awake. It can take hours or even days.

Your config file, the OCI config and all keys are in `.gitignore`. Don't commit them.
