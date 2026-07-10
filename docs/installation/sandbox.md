# Install Record Health Check in your sandbox

This guide installs Record Health Check into a Salesforce **sandbox** with no coding and no command line.

> [!NOTE]
> **What is a "sandbox"?** A sandbox is a Salesforce testing copy. Nothing you
> do here touches real customer data or your live (production) org. It is the right place to
> try something new.

## Before you start

You need:

- **A Salesforce sandbox you can log in to** (whoever provisions sandboxes in your org can create one).
- **Permission to customize pages and Setup** in that sandbox: typically **Customize Application** on your profile.
- **Who runs the Deploy button:** the person clicking **Deploy to Salesforce** must be able to install Apex into the target org. If deployment fails with an Apex-authoring permission error, assign **Author Apex** or ask a Salesforce admin with deploy permissions to run the install.
- **Do not close the browser tab partway through the deploy.**

Right after install, **Step 4** assigns the Permission Set named **Record Health Check User** so you can run the card. That is separate from deploy permissions.

You do **not** need: the Salesforce CLI, Git, VS Code, or any download.

## Step 1: Click the Deploy button

On the project's main page (the [README](../../README.md)), find the button that says
**Deploy to Salesforce** and click it.

It opens a website called **githubsfdeploy**. The tool deploys this project's metadata into the Salesforce org you log in to. It installs package metadata; it does not read or export your records.

## Step 2: Log in to your sandbox

The deploy page asks you to log in.

1. Click **Login to Salesforce**.
2. Log in to the **sandbox**, not production. The login page displays **test.salesforce.com**, or the page provides a **Sandbox** option. If only production login appears, request the sandbox login URL from whoever manages sandboxes. Sandbox My Domain URLs end in `.sandbox.my.salesforce.com`.
3. Enter your sandbox username and password and approve any verification prompt.

> [!WARNING]
> **Safety check:** If you are unsure whether you are in production or sandbox, **stop
> and confirm with the org owner.** Use a sandbox for the first install. Install into
> production only after the org has reviewed the package.

## Step 3: Click Deploy and wait

1. After logging in you will see a page listing the components to install: Apex classes,
   a Lightning component, Custom Metadata Types, and sample data.
2. Click **Deploy**.
3. Wait until the deploy finishes and you see a green **success** message.

If you see a red error message instead, take a screenshot and send it to whoever shared this
project with you, or see [Troubleshooting](#if-something-goes-wrong) below.

**What the deploy installed:**

- The **recordHealthCheck** card you can add to a record page
- Setup areas for **Check Sets** and **Rules**
- **Sample checks** (15 Account Check Sets and 132 Rules across reusable samples,
  teaching sets, and a demo set) so you have something to look at immediately
- Two **Permission Sets** that control who can use it

## Step 4: Give yourself permission to use it

Installing the files is not enough: Salesforce also needs to grant you permission to run
the card.

1. In your sandbox, click the **gear icon** (top right) → **Setup**.
2. In the **Quick Find** box on the left, type **Permission Sets** and click it.
3. Click **Record Health Check User**.
4. Click **Manage Assignments** → **Add Assignment**.
5. Check the box next to **your own name**, then click **Assign** → **Done**.

> Two Permission Sets were installed. **`Record_Health_Check_User`** lets a user run the card. **`Record_Health_Check_Admin`** adds advanced details (`Record_Health_Check_View_Details`) and a reserved configure permission. See [Getting Started: Step 1b](getting-started.md#step-1b-assign-permission-sets).

## Step 5: Add the card to a page and see it work

1. Open any **Account** record in your sandbox (Accounts tab → click any account; create one
   if the sandbox is empty).
2. Click the **gear icon** (top right) → **Edit Page**. This opens the Lightning App Builder.
3. On the left, find **recordHealthCheck** in the component list and **drag it** onto the
   page (a sidebar or the main area both work).
4. With the card selected, look at the right-hand panel. In the **Check Set**
   picker, choose:

   ```text
   Account_Data_Quality
   ```

   It is the Developer Name of one of the sample Check Sets that came with the install.
5. Click **Save**. If it asks you to **Activate**, click **Activate** and accept the
   defaults.
6. Click **Back** to return to the Account.

The record page now shows a **Record Health Check** card with checks and pass/fail statuses.

The next step is configuring your own checks.

## Next

You now have a working installation.

- Build your first check: [Getting Started](getting-started.md)
- Draft checks with an AI assistant: [LLM Configuration Guide](../guides/llm-configuration.md)
- Copy examples: [Examples](../examples/index.md)
- Look up every setting: [Configuration Guide](../guides/configuration-guide.md)

## If something goes wrong

| What you see | Likely cause | What to do |
| ------------ | --------------------- | ---------- |
| The deploy page shows a **red error** | A component did not install, often because of a permissions or API-version issue | Take a screenshot and send it to the person who shared this project. Note: **Formula** checks need org API **v63.0 or later** (Spring '25). |
| Install succeeded but **you don't see the card** on the page | The card was not added, or the Check Set selection is wrong | Re-check **Step 5**. The **Check Set** should be `Account_Data_Quality`. |
| You see the card but it says you **don't have access** | The Permission Set is not assigned | Go back to **Step 4** and confirm **Record Health Check User** is assigned to you. |
| You logged in and it deployed to the **wrong org** | You logged in to production or a different sandbox by mistake | The package does not update business records. To remove the metadata, contact whoever manages that org. Next time, verify the login URL in **Step 2** before clicking **Deploy**. |

More detailed help: [Configuration Guide: Troubleshooting](../guides/configuration-guide.md#13-troubleshooting).
