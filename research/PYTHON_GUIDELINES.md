# Python Guidelines

## Tools

Always use `uv` for package management and running scripts.

```bash
# Install packages
uv add requests pandas

# Run scripts
uv run python main.py

# Never use naked python or pip
```

## README-Driven Development

### Before Coding

1. **Create the README first** - Describe what the code will do before writing it
2. **Define functional requirements** - What inputs, what outputs, what behavior
3. **Outline the implementation plan** - Module structure, key functions, data flow

### After Coding

1. **Check against the README** - Does the code do what was planned?
2. **Reconcile differences** - Either:
   - Update the README to reflect reality (if the change was an improvement)
   - Revisit the code (if it drifted from the intent)

## Code Style

### Clarity Over Cleverness

Write code that is easy to read and easy to change. Optimize for the next person (or future you) who has to understand it.

- Use descriptive names
- Keep functions short and focused
- Prefer explicit over implicit

### DRY (Don't Repeat Yourself)

If you write the same logic twice, extract it. But don't abstract prematurely—wait until you see the pattern repeat.

```python
# Bad: repeated logic
def fetch_users():
    response = requests.get(BASE_URL + "/users")
    response.raise_for_status()
    return response.json()

def fetch_orders():
    response = requests.get(BASE_URL + "/orders")
    response.raise_for_status()
    return response.json()

# Good: extracted
def fetch(endpoint):
    response = requests.get(BASE_URL + endpoint)
    response.raise_for_status()
    return response.json()
```

### Modular Structure

Separate concerns into modules. Each file should have a clear responsibility.

```
project/
├── config.py      # Settings, constants
├── data.py        # Data fetching and storage
├── process.py     # Business logic, transformations
├── output.py      # Display, export, visualization
└── main.py        # Entry point, CLI
```

### Easy to Update

Structure code so changes are localized:

- Configuration in one place
- Related logic grouped together
- Clear boundaries between modules
- Functions that do one thing
