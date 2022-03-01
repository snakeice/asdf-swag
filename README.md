<div align="center">

# asdf-swag [![Build](https://github.com/behoof4mind/asdf-swag/actions/workflows/build.yml/badge.svg)](https://github.com/behoof4mind/asdf-swag/actions/workflows/build.yml) [![Lint](https://github.com/behoof4mind/asdf-swag/actions/workflows/lint.yml/badge.svg)](https://github.com/behoof4mind/asdf-swag/actions/workflows/lint.yml)


[swag](https://github.com/swaggo/swag) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

# Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Why?](#why)
- [Contributing](#contributing)
- [License](#license)

# Dependencies

- `bash`, `curl`, `tar`: generic POSIX utilities.
- `SOME_ENV_VAR`: set this environment variable in your shell config to load the correct version of tool x.

# Install

Plugin:

```shell
asdf plugin add swag
# or
asdf plugin add swag https://github.com/behoof4mind/asdf-swag.git
```

swag:

```shell
# Show all installable versions
asdf list-all swag

# Install specific version
asdf install swag latest

# Set a version globally (on your ~/.tool-versions file)
asdf global swag latest

# Now swag commands are available
swag --version
```

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/behoof4mind/asdf-swag/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [Denis Lavrushko](https://github.com/behoof4mind/)
