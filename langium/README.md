# Workspace overview

This project contains the relevant packages to build a VS Code Extension for your defined language. The workspace contains the following packages:

- [packages/extension](./packages/extension/langium-quickstart.md): Contains the VSCode extension code. For the lab, you can ignore this package.
- [packages/language](./packages/language/README.md) This package contains the language definition and language services. 


For the lab, you will have to edit the following files within [packages/language](./packages/language/README.md):

- `ceml.langium`: The grammar definition of your language (Part A.1).
- `ceml-validator.ts`: Additional validation rules (that cannot be inferred from the grammar alone) are specified here (Part A.2).


## What's in the folder?

Some file are contained in the root directory as well.

- [package.json](./package.json) - The manifest file the main workspace package
- [tsconfig.json](./tsconfig.json) - The base TypeScript compiler configuration
- [tsconfig.build.json](./package.json) - Configuration used to build the complete source code.
- [.gitignore](.gitignore) - Files ignored by git
