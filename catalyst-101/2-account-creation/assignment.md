## 1. Create a Diagrid Catalyst Account

Let's start by creating a free Diagrid Catalyst account by using the **Catalyst** tab on the left in this sandbox and signing up with your email address or Google/GitHub account.

> [!NOTE]
> Alternatively you can use another browser tab and visit [https://catalyst.diagrid.io/signup](https://catalyst.diagrid.io/signup) to sign up for Diagrid Catalyst.

If you already have an account, you can skip this step and proceed with downloading the Diagrid CLI.

Once you've signed up, you should see the *Welcome to Catalyst* page in the **Catalyst** tab. You'll be using the Diagrid CLI to create resources and run Dapr applications in the next steps, so come back the instructions and continue with the next step to download and install the Diagrid CLI.

## 2. Download & install the Diagrid CLI

The Diagrid CLI is a command line tool that allows you to create and manage Catalyst resources and run local Dapr applications with Catalyst.

Run the following command in the **Terminal** tab to download the Diagrid CLI:

```bash,run
curl -o- https://downloads.diagrid.io/cli/install.sh | bash
```

Move the CLI to the local user path:

```bash,run
sudo mv ./diagrid /usr/local/bin 
```

Check that the Diagrid CLI is installed by running:

```bash,run
diagrid -h
```

This should list the available CLI commands.

## 3. Login to Catalyst

Before you can use the Diagrid CLI to create resources or run applications the CLI needs to be connected to your Catalyst account.

In the **Terminal** tab, run the following command:

```bash,run
diagrid login --no-browser
```

> [!NOTE]
> When using The Diagrid CLI on your local machine, you'll mostly likely use `diagrid login` which opens a browser tab to login. The `--no-browser` flag is only needed in this sandbox environment since it can't open a new browser tab.

You'll see an output like this:

```text,nocopy
logging in to 'https://api.r1.diagrid.io/'...
Visit: https://login.diagrid.io/activate?user_code=XXXX-XXXX and confirm the code matches: XXXX-XXXX
Code confirmed? (Y/N)
```

1. Click on the login link provided in the output (the one that contains the user code) to open a new browser tab.
2. You'll need to login to your Catalyst account in this browser tab if you haven't already.
3. Verify that the code in the browser matches the code in the terminal, click the *Confirm* button and come back to this sandbox environment.
4. Press `Y` followed by the `Enter` key in the **Terminal** tab to confirm.

The CLI is now logged in to your Catalyst account and should show a message like this:

```text,nocopy
Using organization <ORG_NAME> (<ORG_ID>)
Successfully authenticated
```

Check that you're logged in by running:

```bash,run
diagrid whoami
```

The output should show the organization, user and API endpoint:

```text,nocopy
Organization: <ORG_NAME> (<ORG_ID>)
User: <USER_NAME> (<EMAIL>)
API: https://api.r1.diagrid.io
```

---

Now that you have a Catalyst account and the Diagrid CLI installed and configured, you're ready to proceed to the next challenge, where you'll use the Diagrid CLI to run two Dapr applications that communicate via a Pub/Sub service that is built into Catalyst.
