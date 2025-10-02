## 1. Create a Diagrid Catalyst Account

First, create a free Diagrid Catalyst account by visiting [https://catalyst.diagrid.io/signup](https://catalyst.diagrid.io/signup) and signing up with your email address.

If you already have an account, you can skip this step and proceed with installing the Diagrid CLI.

You can use the **Catalyst Signup** page in the browser in this sandbox, or use a different browser window.

## 2. Download & Install the Diagrid CLI

```bash,run
curl -o- https://downloads.diagrid.io/cli/install.sh | bash
```

```bash,run
sudo mv ./diagrid /usr/local/bin 
```

## 3. Login to the Diagrid CLI

Run the following command to login to the Diagrid CLI. This will open a browser window where you can login with your email address and password.

```bash,run
diagrid login
```