Here’s a concise and clean **README.md** you can put at the root of your `lab2-template` folder 👇

---

## 🧩 Lab 2 — Graphical & Textual Concrete Syntax Development

This lab focuses on exploring **two complementary approaches** to defining *concrete syntaxes* for domain models:

1. **Graphical Concrete Syntax** using **[Eclipse Sirius Web](https://github.com/eclipse-sirius/sirius-web)**

   * Create and customize visual model editors directly in the browser.
   * Define diagrams, shapes, colors, and layout rules for your metamodel elements.
   * The graphical syntax allows users to model visually through diagrams.

2. **Textual Concrete Syntax** using **[Langium](https://github.com/langium/langium)**

   * Build a language grammar for your metamodel.
   * Automatically generate a VS Code extension for textual editing.
   * The textual syntax allows users to model through structured DSLs.

---

### 📦 Folder Structure

```
lab2-template/
  ├─ sirius/     → Graphical syntax (Sirius Web + Docker + Postgres)
  └─ langium/    → Textual syntax (Langium grammar and VS Code extension)
```

* The **`sirius`** folder contains scripts to run the **Sirius Web** environment with a preloaded database.
* The **`langium`** folder contains a **Langium project** to implement and test your textual DSL.

---

### 🎯 Learning Goals

* Understand how **graphical and textual syntaxes** represent the same underlying metamodel differently.
* Learn how to set up and run **Sirius Web** for diagram-based modeling.
* Learn how to design a **Langium grammar** for textual modeling.

---

### 🚀 Next Steps

1. Follow the setup guide inside the [`sirius/`](./sirius) folder to run **Sirius Web**.
2. Open the [`langium/`](./langium) folder in VS Code and build your **Langium grammar**.
---