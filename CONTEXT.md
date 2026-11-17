# Claude Account Switcher

Lets one person use several Claude subscriptions on one machine without logging in again, by tying each project folder to the subscription it should run under.

## Language

**Account**:
A named Claude subscription login that Claude Code can run under. Any number can exist, and all stay logged in at once.
_Avoid_: Profile, user, subscription, login

**Personal Account**:
The first of the two initial Accounts: the one paid for by the owner of the machine, used for their own projects.

**Work Account**:
The second of the two initial Accounts: the one provided by an employer, used for that employer's tasks.

**Setup**:
The settings, instructions, skills, agents, hooks and plugins that shape how Claude Code behaves. There is one Setup, shared by every Account.
_Avoid_: Config, profile

**Folder Rule**:
A statement that a folder, and everything beneath it, runs under a given Account. Where Folder Rules overlap, the one naming the deepest folder applies.
_Avoid_: Mapping, binding, route

**Default Account**:
The Account used in any folder that no Folder Rule covers. It is the Personal Account.
_Avoid_: Fallback account

**Override**:
A one-off choice of Account for a single session that ignores the Folder Rules.

**Inherited Account**:
The Account a session takes from the session that started it, whatever folder it runs in. It ranks below an Override and above the Folder Rules.
