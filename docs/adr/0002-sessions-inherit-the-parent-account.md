# A session inherits its parent's Account

When one session starts another `claude` in a different folder, the inner session runs under the parent's Account even if a Folder Rule for that folder names a different one. A task is one piece of work: if a Work Account session reaches into another folder, that is still work, and it should be billed to and visible under the Work Account wherever the files sit. This is the one deliberate exception to "the folder determines the Account"; we rejected re-resolving the folder on every launch for that reason.

## Consequences

- Precedence is Override, then Inherited Account, then Folder Rule, then Default Account.
- A shell opened from inside a session carries the Account with it, so `claude` launched from that shell in a personal folder still runs under the parent's Account. A new terminal is unaffected.
