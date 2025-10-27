## 🚀 Sirius Web Installation and Execution Guide

This guide explains how to run and persist the **Sirius Web** application together with its preloaded PostgreSQL database using Docker.
You can easily share database states with teammates by exporting and re-importing timestamped `.tar.gz` snapshots.

---

### 🧩 1. Prerequisites

* **Install Docker**
  👉 [https://docs.docker.com/get-docker/](https://docs.docker.com/get-docker/)

---

### 🧱 2. Repository Setup

1. **Clone the Lab 2 repository**

   ```bash
   git clone git@github.com:MEWS2025/lab2-template.git
   cd lab2-template/sirius
   ```

   The folder structure will look like this:

   ```
   lab2-template/
     ├─ sirius/
     │   ├─ load_db_data_and_run.sh
     │   ├─ save_state.sh
     │   ├─ sirius-db-seed.tar.gz
     └─ langium/
   ```
---

### 🌐 3. Clone the Sirius Web Source

Clone the official Sirius Web repository into the `sirius` folder:

```bash
git clone git@github.com:eclipse-sirius/sirius-web.git
```

---

### 📦 4. Download the Application JAR

Download the prebuilt `sirius-web` JAR from the link below and place it inside the `sirius` folder:

👉 [Download JAR (sirius-web-*-.jar from the Assets on the side, the * would be some date)](https://github.com/eclipse-sirius/sirius-web/packages/2069582)


<img width="970" height="907" alt="sirius-web-jar-view" src="https://github.com/user-attachments/assets/bd792b89-2b0b-4de4-a95f-ca4b73a8b103" />


In case the link is broken, follow these steps - 
1. Go to [`Packages`](https://github.com/orgs/eclipse-sirius/packages?tab=packages&q=sirius-web) of the Sirius web repo.
2. Search for `sirius-web`
3. Select the package `org.eclipse.sirius.sirius-web` as given in the image below.
4. Renamed the downloaded jar to `sirius-web.jar`.

<img width="981" height="108" alt="sirius-web-package" src="https://github.com/user-attachments/assets/5b0f4b08-9ad2-45bc-837e-1343f719a31f" />


After downloading, the structure should look like:

```
lab2-template/
  ├─ sirius/
  │   ├─ sirius-db-seed/
  │   ├─ load_db_data_and_run.sh
  │   ├─ save_state.sh
  │   ├─ sirius-db-seed.tar.gz
  │   ├─ sirius-web/
  │   └─ sirius-web.jar
  └─ langium/
```

---

### ⚙️ 5. Running Sirius Web

To start **PostgreSQL** with the preloaded data and automatically run **Sirius Web**, simply execute:

```bash
bash load_db_data_and_run.sh
```

* This:

  * Extracts the `sirius-db-seed.tar.gz` bundle
  * Starts a **Postgres 17** container (port `5433`)
  * Loads all tables and data from the bundle
  * Launches `sirius-web.jar` connected to that database

Once it’s ready, you can open **Sirius Web** in your browser at:

👉 [http://localhost:8080](http://localhost:8080) (default port)

---

### 💾 6. Saving the Current Database State

Whenever you’ve made changes and want to persist the new DB state, run:

```bash
bash save_state.sh
```

This will:

* Dump the running database from Docker
* Create a **timestamped snapshot** (e.g. `sirius-db-seed-2025-10-26_10-30-00.tar.gz`)
* Save it in the current directory

You can commit and push this `.tar.gz` file to your Git repository to share it with teammates.

---

### ♻️ 7. Loading a Specific Saved State

To reload a specific saved snapshot:

```bash
bash load_db_data_and_run.sh sirius-db-seed-2025-10-26_10-30-00.tar.gz
```

If you omit the argument:

```bash
bash load_db_data_and_run.sh
```

…it will automatically use the default `sirius-db-seed.tar.gz`.

---

### 🧠 Summary

| Task                          | Command                                                          | Description                                     |
| ----------------------------- | ---------------------------------------------------------------- | ----------------------------------------------- |
| **Run Sirius Web**            | `bash load_db_data_and_run.sh`                                   | Starts Postgres & Sirius Web using default seed |
| **Run with a specific state** | `bash load_db_data_and_run.sh sirius-db-seed-<timestamp>.tar.gz` | Loads a chosen seed tar                         |
| **Save current DB state**     | `bash save_state.sh`                                             | Dumps DB, creates timestamped seed tar          |
| **Stop the DB**               | <kbd>Ctrl+C</kbd> or wait for JAR to exit                        | Container stops automatically (uses `--rm`)     |

---

### 🤝 Collaborative Workflow

1. One teammate runs `save_state.sh` to capture the latest data.
2. They commit & push the new `.tar.gz` to Git.
3. Others pull the repo and run:

   ```bash
   bash load_db_data_and_run.sh sirius-db-seed-<timestamp>.tar.gz
   ```
4. Everyone is instantly synced to the same DB state.

---

🧡 **Enjoy developing with Sirius Web + Docker!**
