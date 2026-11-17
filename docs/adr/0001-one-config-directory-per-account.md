# One config directory per Account, not token swapping

Each Account gets its own Claude Code config directory, selected at launch through `CLAUDE_CONFIG_DIR`, so every Account stays logged in at once and two sessions can run under different Accounts side by side. We rejected the more common design of swapping OAuth tokens in and out of the single Keychain item: Claude Code refreshes tokens while it runs, so a saved copy goes stale and forces the re-login the tool exists to avoid, and the tool would have to read and write credentials. With separate directories Claude Code keeps a distinct Keychain item per directory and the tool never touches a token.

`~/.claude` belongs to the Default Account (the Personal Account). Anything that reaches Claude Code without passing through the wrapper lands in `~/.claude`, so it must hold the Account that is safe to fall back to.

## Consequences

- The Setup is shared by linking each of its items from `~/.claude` into every other Account's directory.
- The main state file cannot be shared because it holds the login identity. A new Account's file is seeded from an existing one, and the two drift afterwards: a user-level MCP server added under one Account does not appear in the other.
- Session transcripts and per-project memory are per Account, so changing which Account a folder runs under means moving that folder's history.
