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

👉 [Download JAR](https://github-registry-files.githubusercontent.com/117671057/6e64a700-b0d8-11f0-8ded-84193d7ef5ce?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAVCODYLSA53PQK4ZA%2F20251026%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20251026T044206Z&X-Amz-Expires=300&X-Amz-Signature=1aa98d598e9f927ae9776bfc104b800adeb634d0260eeef63a088ede43410f08&X-Amz-SignedHeaders=host&response-content-disposition=filename%3Dsirius-web-2025.10.1.jar.md5&response-content-type=application%2Foctet-stream)

After downloading, the structure should look like:

```
lab2-template/
  ├─ sirius/
  │   ├─ sirius-db-seed/
  │   ├─ load_db_data_and_run.sh
  │   ├─ save_state.sh
  │   ├─ sirius-db-seed.tar.gz
  │   ├─ sirius-web/
  │   └─ sirius-web-2025.10.1.jar
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
