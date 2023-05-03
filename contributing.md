# Contributing

Testing locally:

```shell
asdf plugin test <plugin-name> <plugin-url> [--asdf-tool-version <version>] [--asdf-plugin-gitref <git-ref>] [test-command*]

# E.g., to test the currently-released version:
asdf plugin test swag https://github.com/behoof4mind/asdf-swag.git "swag --version"

# Or to test against a local commit:
asdf plugin test swag ./.git --asdf-tool-version 1.8.10 --asdf-plugin-gitref main "swag --version"
```

Tests are automatically run in GitHub Actions on push and PR.
