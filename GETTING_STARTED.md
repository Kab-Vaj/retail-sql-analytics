# Getting Started: Run This Project Yourself

There are two ways to run the project. Pick one.

| | Option A: in your browser | Option B: on your computer |
|---|---|---|
| Install anything? | No | PostgreSQL (free) |
| Setup time | About 5 minutes, mostly waiting | About 20 minutes |
| Cost | Free within GitHub's monthly allowance | Free |
| Best for | Trying it right now, from any computer | Practicing SQL often, offline |

---

## Option A: Run it in your browser (GitHub Codespaces)

A Codespace is a computer in the cloud that GitHub sets up for you. This project tells it to install PostgreSQL, load all the data and run the tests on its own.

### 1. Start the Codespace

1. Go to the project page: https://github.com/Kab-Vaj/retail-sql-analytics
2. Click the green **Code** button, open the **Codespaces** tab, and click **Create codespace on main**.
3. A code editor opens in your browser. Wait while it sets up. The first time takes about 3 to 5 minutes.
4. You're ready when the terminal panel at the bottom says **All data tests passed** and **Setup complete**.

### 2. Run a query

1. In the file list on the left, open `queries` and then `01_basics.sql`.
2. Click anywhere inside one query, or highlight it with your mouse.
3. Press **Ctrl+E** then **Ctrl+E** again (on a Mac, **Cmd+E** twice). You can also right-click and choose **Run Selected Query**.
4. The first time, it asks which connection to use. Pick **Retail portfolio database**.
5. The results open in a panel on the right.

Try editing a query (change a `LIMIT 10` to `LIMIT 5`, or a state from `'IL'` to `'CA'`) and run it again. You can't break anything.

### 3. Other useful commands

Type these in the terminal at the bottom and press Enter:

| Command | What it does |
|---|---|
| `./scripts/run_tests.sh` | Rebuilds the models and runs all 16 data tests |
| `./scripts/setup.sh` | Resets the database to its original state, in case you changed data |
| `psql` | Opens a SQL prompt connected to the database (type `\q` to leave) |

### 4. Stop it when you're done

A Codespace stops by itself after 30 minutes of no activity. To stop it right away, go to https://github.com/codespaces, click the **...** next to your Codespace, and choose **Stop codespace**. Next time, open it from that same page and everything will still be there.

Personal GitHub accounts get a free monthly allowance of Codespaces hours, which is enough for many hours of practice each month on the smallest machine. You can see your usage under GitHub **Settings > Billing and plans**.

---

## Option B: Run it on your own computer (Windows or Mac)

This uses **pgAdmin**, a free point-and-click program for PostgreSQL. You don't need the command line.

### 1. Install PostgreSQL and pgAdmin

1. Go to https://www.postgresql.org/download/ and choose **Windows** or **macOS**.
2. Click **Download the installer** and download the latest version.
3. Run the installer and keep the default options. pgAdmin is included.
4. When it asks for a password, choose one and **write it down**. You'll need it in pgAdmin.
5. If it offers to launch "Stack Builder" at the end, you can skip it.

### 2. Download the project

1. Go to https://github.com/Kab-Vaj/retail-sql-analytics
2. Click the green **Code** button, then **Download ZIP**.
3. Unzip it somewhere easy to find, like your Documents folder.

### 3. Create the database

1. Open **pgAdmin**.
2. In the left panel, click **Servers**, then your PostgreSQL server. Enter the password from step 1.
3. Right-click **Databases** and choose **Create > Database...**
4. Name it `retail_portfolio` and click **Save**.

### 4. Load the project, in this order

1. Click the new `retail_portfolio` database in the left panel.
2. From the menu, choose **Tools > Query Tool**.
3. For each file below, click the **folder icon** (Open File) in the Query Tool, choose the file, then click the **play button** (or press **F5**) to run it:

| Order | File | What you should see |
|---|---|---|
| 1 | `schema/01_create_tables.sql` | "Query returned successfully" |
| 2 | `data/02_seed_data.sql` | Takes a few seconds, then "Query returned successfully" |
| 3 | `models/analytics_models.sql` | "Query returned successfully" |
| 4 | `tests/data_tests.sql` | A table of 16 tests, all marked **PASS** |

### 5. Run queries

1. Open any file in the `queries` folder the same way.
2. **Highlight one query** with your mouse and press **F5**. pgAdmin runs only what's highlighted.
   If you run a whole file without highlighting, pgAdmin shows only the last query's results.
3. Results appear in the panel below.

To reset everything back to the original data, run files 1 to 3 again.

---

## Where to go next

- Read the queries in order, `01_basics.sql` through `07_business_analysis.sql`. Each one has a comment explaining what it answers.
- Pick a query, cover it up, and try writing it yourself from the comment. That's great interview practice.
- Look at the models in `models/analytics_models.sql` and query them directly, for example `SELECT * FROM analytics.dim_customers LIMIT 20;`

## If something goes wrong

| Problem | Fix |
|---|---|
| Codespace terminal shows an error during setup | Type `./scripts/setup.sh` in the terminal and press Enter to run setup again |
| Ctrl+E does nothing in the Codespace | Click the database icon in the far-left bar, connect to **Retail portfolio database**, then try again |
| pgAdmin says `relation "orders" does not exist` | Run files 1 and 2 from step 4 first, and make sure `retail_portfolio` is selected |
| pgAdmin says `schema "analytics" does not exist` | Run `models/analytics_models.sql` (file 3) |
| Forgot the PostgreSQL password | Reinstall PostgreSQL. It's the simplest fix on a practice machine. |
