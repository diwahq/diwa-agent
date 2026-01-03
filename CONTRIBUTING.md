# Contributing to Diwa Agent

Thank you for your interest in contributing to Diwa Agent! We welcome contributions from the community to help make this the best open-source context memory layer for AI agents.

## Code of Conduct

This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](https://www.contributor-covenant.org/) code of conduct.

## How to Contribute

1.  **Fork the repository** on GitHub.
2.  **Clone your fork** locally.
    ```bash
    git clone https://github.com/YOUR_USERNAME/diwa-agent.git
    cd diwa-agent
    ```
3.  **Create a new branch** for your feature or bugfix.
    ```bash
    git checkout -b feature/my-new-feature
    ```
4.  **Make your changes**. Ensure you follow the existing code style (Elixir formatter) and add tests for any new functionality.
5.  **Run tests** to ensure no regressions.
    ```bash
    mix test
    ```
6.  **Commit your changes** with a clear commit message.
    ```bash
    git commit -m "Add feature X to improve Y"
    ```
7.  **Push to your fork**.
    ```bash
    git push origin feature/my-new-feature
    ```
8.  **Submit a Pull Request** to the `main` branch of the official repository.

## Development Setup

### Prerequisites

-   Elixir 1.15+
-   PostgreSQL 15+ (with `pgvector` extension)

### setting up the environment

```bash
# Install dependencies
mix deps.get

# Setup Database
mix ecto.setup
```

## Reporting Issues

If you find a bug or have a feature request, please open an issue on the [GitHub Issues](https://github.com/diwahq/diwa-agent/issues) page.

## License

By contributing, you agree that your contributions will be licensed under the MIT License defined in the `LICENSE` file.
