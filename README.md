# claude-account-switcher

Use several Claude subscriptions with Claude Code on one machine, without logging in again each time you change between them.

You keep typing `claude`. A small wrapper looks at the folder you are in and starts Claude Code under the account that folder belongs to. Work repositories run on your work subscription, everything else runs on your personal one, and both can be open at once in different terminals.

This is an unofficial community tool. It is not made or endorsed by Anthropic.

## How it works

Claude Code reads its login, history and state from one config directory, `~/.claude` by default, and it honours the `CLAUDE_CONFIG_DIR` environment variable. This tool gives each account its own directory and sets that variable at launch.

Because each directory holds its own login, every account stays logged in and refreshes its own tokens. The tool never reads, copies or stores a credential.

The account for a launch is chosen in this order:

1. Override. `CLAUDE_ACCOUNT=work claude` forces an account for one launch.
2. Inherited account. A `claude` started from inside a running session keeps that session's account, even in a different folder.
3. Folder rule. The deepest rule that covers the current folder wins.
4. Default account. Any folder without a rule uses it. It lives in `~/.claude`, so your existing setup becomes the default account as it is.

## Requirements

- macOS or Linux
- bash 3.2 or newer (the bash that ships with macOS works)
- Claude Code installed and on your `PATH`
- For `add`, `migrate` and `doctor`: one of `osascript` (built into macOS), `python3` or `jq`

## Install

```sh
git clone https://github.com/nusendra/claude-account-switcher ~/.local/share/claude-account-switcher
~/.local/share/claude-account-switcher/claude-account install
```

Then put the wrapper ahead of the real `claude` on your `PATH`. Add this line to `~/.zshrc` or `~/.bashrc` and open a new terminal:

```sh
export PATH="$HOME/.claude-accounts/bin:$PATH"
```

Run `claude-account doctor` to confirm the wrapper is the `claude` your shell finds.

To update later, run `git pull` in the clone. The installed commands are links to it.

## Set up a second account

Your current login stays in `~/.claude` as the default account, named `personal` unless you pass `install --default NAME`.

```sh
claude-account add work                  # creates the account, then opens the browser login
claude-account rule ~/code/company work  # that folder and everything beneath it uses work
claude-account migrate                   # preview which session histories would move
claude-account migrate --apply           # move them
```

`add` shares your existing Claude Code setup with the new account by linking it: `settings.json`, `CLAUDE.md` and other top-level Markdown files, `skills`, `agents`, `commands`, `hooks`, `plugins`, `output-styles` and `keybindings.json`. You configure Claude Code once.

If the login that is in `~/.claude` today should not be your default account, add the other account first and log in there, then run `/login` inside a session in a default folder to change the default account's login.

## Show the account in the status line

`claude-account status` prints the account and the email that is logged in, for example `Work - you@company.com`. Add it to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"$HOME\"/.claude-accounts/bin/claude-account status"
  }
}
```

The email is read from the state file of the running session, so it shows who is really logged in.

## Commands

| Command | What it does |
|---|---|
| `claude-account install [--default NAME]` | Link `claude` and `claude-account` into `~/.claude-accounts/bin` |
| `claude-account add NAME [--no-login]` | Create an account that shares your setup, then log in |
| `claude-account rule FOLDER NAME` | Run `FOLDER` and everything beneath it under `NAME` |
| `claude-account unrule FOLDER` | Remove the rule for `FOLDER` |
| `claude-account list` | Show accounts, their logins and the folder rules |
| `claude-account which [FOLDER]` | Show which account a folder gets, and why |
| `claude-account migrate [--apply]` | Move session history to the account each folder now uses |
| `claude-account doctor [--fix]` | Check `PATH`, shared setup links, logins and MCP differences |
| `claude-account status` | Print `Account - email` for the status line |
| `claude-account uninstall` | Remove the wrapper and leave accounts and history on disk |

Rules live in `~/.claude-accounts/rules`, one per line, and you can edit the file by hand:

```
~/code/company        work
~/code/company/notes  personal
```

## What is shared and what is separate

Shared by every account, through links: settings, instructions, skills, agents, commands, hooks and plugins.

Separate for each account:

- The login. On macOS, Claude Code keeps one Keychain entry per config directory. On Linux, it keeps a credentials file inside each directory.
- Session history and per-project memory. `migrate` moves these when a folder changes account.
- The state file `.claude.json`. It holds the login identity, so it cannot be shared. `add` seeds it from the default account without the login, which carries over project trust and MCP servers. After that the two files drift: an MCP server added with `claude mcp add --scope user` exists only in the account you were using. `claude-account doctor` lists the differences.
- Connectors and anything else attached to the subscription itself.

## Things to know

- Sessions that were already running before you installed the wrapper keep the account they started with. Restart them.
- A shell opened from inside a session carries that session's account. Use a new terminal when you want the folder rule to apply.
- Programs that call the Claude Code binary by its full path skip the wrapper and get the default account.
- `migrate` only previews unless you pass `--apply`, and it never overwrites history that already exists at the destination. Close sessions in the affected folders before applying.

## Uninstall

```sh
claude-account uninstall
```

This removes the wrapper, so `claude` runs Claude Code directly again. Accounts, their logins and their history stay in `~/.claude-accounts` until you delete that folder. To move history back to `~/.claude` first, remove your rules and run `claude-account migrate --apply` before uninstalling.

## Development

```sh
bash test.sh
```

The tests run in a throwaway home directory with a fake `claude`, so they never touch your real configuration or logins. [CONTEXT.md](CONTEXT.md) defines the vocabulary used in the code, and [docs/adr](docs/adr) records the two design decisions that are easy to question later.

## License

[MIT](LICENSE)
