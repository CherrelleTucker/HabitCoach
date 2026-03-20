# Chat Log Guidelines

Record conversations to preserve context and decisions.

## Format

```markdown
# [Context/Phase Description]

## Message 1
> [User's exact message]

## Message 2
> [User's exact message]
```

## Rules

- Use `>` blockquotes for user messages
- Number messages sequentially
- Add section headers (`#`) to group messages by topic or phase
- Preserve the user's exact wording

## Location

- Root-level conversations → `/chat_messages.md`
- Topic-specific conversations → `{topic}/chat_messages.md`

## Adding to Existing Logs

When appending to an existing chat log, add a new section header that describes the conversation phase:

```markdown
# Build Book Recommender System

## Message 1
> ...

# Clarify Export Format

## Message 5
> ...
```

Section titles should be short and descriptive of what that conversation accomplished.
