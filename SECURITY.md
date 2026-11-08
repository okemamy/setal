# Security

Setal deletes files. If you find a way it could delete something outside
what an item describes — a path that escapes `PathGuard`, a project folder
wrongly detected as a build artifact, a symlink being followed — please
report it privately through GitHub's **Security › Report a vulnerability**
rather than in a public issue.

Please include the path layout needed to reproduce it. A failing test in
`Tests/SetalCoreTests` is the best possible report.
