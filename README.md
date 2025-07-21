
# Setup MySQL Action

[![GitHub Actions Status](https://github.com/kayqueGovetri/setup-mysql/workflows/CI/badge.svg)](https://github.com/kayqueGovetri/setup-mysql/actions)
[![License](https://img.shields.io/github/license/kayqueGovetri/setup-mysql)](LICENSE)

## Overview

This GitHub Action automates the setup and configuration of MySQL in your CI workflow, simplifying database initialization and integration tests. It is designed to be easy to use and customizable for your project needs.

## Features

- Installs MySQL server in your CI environment
- Configures user, password, database, and port
- Runs initialization SQL scripts
- Works on Linux and Windows runners
- Simple and quick integration into GitHub Actions workflows

## Usage

Add the following step in your GitHub Actions workflow `.yml` file:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup MySQL
        uses: kayqueGovetri/setup-mysql@v1
        with:
          mysql-version: '8.0'
          root-password: 'rootpass'
          database-name: 'my_db'
          user: 'dev'
          user-password: 'devpass'
          port: 3306
          init-sql: 'scripts/init.sql'
```

### Inputs

| Name           | Description                                | Default  | Required |
| -------------- | ------------------------------------------| -------- | -------- |
| `mysql-version`| MySQL version to install (e.g., 8.0)      | `8.0`    | No       |
| `root-password`| Password for MySQL root user                | `root`   | Yes      |
| `database-name`| Name of the database to create              | `test`   | No       |
| `user`         | Database user to create                      | `user`   | No       |
| `user-password`| Password for the database user               | `password`| No      |
| `port`         | Port for MySQL server                        | `3306`   | No       |
| `init-sql`     | Path to the SQL initialization script       | -        | No       |

## Example

```yaml
name: CI

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup MySQL
        uses: kayqueGovetri/setup-mysql@v1
        with:
          mysql-version: '8.0'
          root-password: 'rootpass'
          database-name: 'my_db'
          user: 'dev'
          user-password: 'devpass'
          port: 3307
          init-sql: 'init.sql'

      - name: Run Tests
        run: |
          mysql -h 127.0.0.1 -P 3307 -u dev -p'devpass' my_db < tests/test.sql
```

## Notes

- Supported operating systems:
  - **Linux** (Ubuntu)
  - **macOS** 13 (Ventura), and 14 (Sonoma)
  - **Windows** (Windows Server, Windows 10/11 runners)

- MySQL will be installed and configured according to the specified version.
- Make sure the path to the `init-sql` file is correct and accessible within the Action context.
- The MySQL service may take a few seconds to become available after installation.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
