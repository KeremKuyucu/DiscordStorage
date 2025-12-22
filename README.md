🧠 What is DiscordStorage?

DiscordStorage is an experimental, cross-platform application built with Flutter that allows files to be stored and retrieved using Discord channels as a backend.

Files are automatically split into chunks, uploaded as message attachments, and later reassembled on download.
The system tracks files using Discord message IDs and verifies integrity using SHA-256 checksums.

The application runs on Android and Windows from a single codebase and focuses on reliability, structure, and data consistency rather than user-scale cloud features.


---

🎯 Why was this project built?

DiscordStorage was created mainly as a technical experiment and learning project.

The idea was not to build a Google Drive alternative, but to explore what can be done when a platform not designed for storage is treated like one.

This project exists because:

I wanted to see how far Discord’s infrastructure could be pushed

I wanted to design a custom file abstraction layer

I wanted hands-on experience with rate limits, retries, and large file transfers

I wanted a real project that exposes real-world edge cases

I simply enjoy building systems that are unusual but technically possible


In short:

> This project was built because I can build it — and because it’s interesting to do so.




---

🧩 Project Scope

DiscordStorage is intentionally kept focused:

No external cloud sync

No dependency on third-party storage services

No attempt to compete with commercial cloud platforms


It is a self-contained proof of concept meant for experimentation, learning, and showcasing system design skills.
