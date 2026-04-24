---
description: Initialize a new Python CLI project with cli, services, and migrations folders
---

# Python CLI Project Initializer

You are helping initialize a new Python CLI project. Ask the user the following questions one at a time:

1. **Project name**: What should the CLI be called? (e.g., myapp-cli)
2. **CLI framework**: Which framework? (click/typer/argparse)
3. **Database**: Need database support? (yes/no)
   - If yes: Which database? (sqlite/postgresql/mysql/mongodb)
   - If yes: Which ORM/library? (sqlalchemy/peewee/pymongo/none)
4. **Configuration**: How should config be handled? (yaml/toml/json/env-file)
5. **Additional features**:
   - Logging setup (yes/no)
   - Progress bars/rich output (rich/tqdm/none)
   - API client functionality (requests/httpx/none)
   - Background tasks (yes/no)

## After gathering requirements:

### 1. Create Project Structure
```
{project_name}/
├── cli/
│   ├── __init__.py
│   ├── main.py              # Entry point and CLI setup
│   └── commands/            # Command modules
│       ├── __init__.py
│       └── example.py
├── services/
│   ├── __init__.py
│   ├── database.py          # Database service (if selected)
│   ├── config.py            # Configuration service
│   └── logger.py            # Logging service (if selected)
├── migrations/              # Database migrations (if DB selected)
│   ├── __init__.py
│   └── versions/
├── tests/
│   ├── __init__.py
│   ├── test_cli.py
│   └── test_services.py
├── .env.example
├── .gitignore
├── pyproject.toml           # or setup.py
├── requirements.txt
└── README.md
```

### 2. Create pyproject.toml

Set up with:
- Project metadata
- Dependencies based on selections
- Entry point for CLI: `[project.scripts]` section
- Development dependencies (pytest, black, ruff, mypy)

### 3. Create CLI Entry Point (cli/main.py)

Based on selected framework:
- Set up Click/Typer/argparse CLI structure
- Import and register all commands
- Add version flag
- Add verbose/debug flags
- Set up logging if selected

### 4. Create Example Command (cli/commands/example.py)

Create a sample command that demonstrates:
- Command structure
- Using services
- Error handling
- Output formatting

### 5. Create Services

**services/config.py**:
- Load configuration from selected format
- Environment variable support
- Config validation

**services/database.py** (if DB selected):
- Database connection setup
- Connection pooling
- Basic CRUD operations template

**services/logger.py** (if logging selected):
- Structured logging setup
- Log to file and console
- Different log levels

### 6. Create Migration Setup (if DB selected)

If using SQLAlchemy:
- Set up Alembic
- Create initial migration template
- Document migration commands

If using other ORMs:
- Create appropriate migration structure
- Document migration process

### 7. Create .env.example

Include all required environment variables:
```
# Database Configuration (if applicable)
DATABASE_URL=sqlite:///./app.db
# DATABASE_URL=postgresql://user:password@localhost/dbname

# API Configuration (if applicable)
API_KEY=your_api_key_here
API_BASE_URL=https://api.example.com

# Application Settings
LOG_LEVEL=INFO
DEBUG=false
```

### 8. Create .gitignore

Include Python-specific ignores:
- __pycache__/
- *.py[cod]
- .env
- *.db
- .pytest_cache/
- dist/
- build/
- *.egg-info/

### 9. Create README.md

Document:
- Project description
- Installation instructions
- Available commands and usage examples
- Configuration options
- Development setup
- Testing instructions
- Migration management (if DB)

Example structure:
```markdown
# {Project Name}

## Installation

\`\`\`bash
pip install -e .
\`\`\`

## Configuration

Copy `.env.example` to `.env` and fill in your values.

## Usage

\`\`\`bash
# Show all commands
{project-name} --help

# Run example command
{project-name} example --name "World"
\`\`\`

## Development

\`\`\`bash
# Install dev dependencies
pip install -e ".[dev]"

# Run tests
pytest

# Run linter
ruff check .

# Format code
black .
\`\`\`

## Database Migrations (if applicable)

\`\`\`bash
# Create migration
alembic revision --autogenerate -m "description"

# Run migrations
alembic upgrade head
\`\`\`
```

### 10. Create Initial Tests

Create basic test structure:
- Test CLI command invocation
- Test service functions
- Mock external dependencies

### 11. Initialize Git Repository
```bash
git init
git add .
git commit -m "Initial commit: Python CLI project structure"
```

## Example CLI Commands to Create:

Based on the framework chosen, create these example commands:

**For Click**:
```python
@click.command()
@click.option('--name', default='World', help='Name to greet')
@click.option('--count', default=1, help='Number of greetings')
def hello(name, count):
    """Simple program that greets NAME COUNT times."""
    for _ in range(count):
        click.echo(f'Hello {name}!')
```

**For Typer**:
```python
def hello(
    name: str = typer.Option("World", help="Name to greet"),
    count: int = typer.Option(1, help="Number of greetings")
):
    """Simple program that greets NAME COUNT times."""
    for _ in range(count):
        typer.echo(f'Hello {name}!')
```

## Final Steps:

1. Show the user the complete directory structure
2. Explain how to install and run the CLI
3. Show example commands
4. Explain the migration workflow (if DB selected)
5. Suggest next steps for development
