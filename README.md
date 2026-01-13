🧠 What is DiscordStorage?

DiscordStorage is an experimental, cross-platform application built with Flutter that enables the storage and retrieval of files using Discord channels as a backend.

Files are automatically split into chunks, uploaded as message attachments, and reassembled when downloaded.
The system tracks files using Discord message IDs and verifies their integrity using SHA-256 checksums.

The application runs on Android and Windows from a single codebase and focuses on reliability, structure, and data consistency rather than cloud features at the user scale.


---

🎯 Why was this project created?

DiscordStorage was primarily created as a technical experiment and learning project.

The goal here was not to create an alternative system to Google Drive, but to explore what could be done when a platform not designed for storage is used for storage purposes.

This project was created for the following reasons:

I wanted to see how much Discord's infrastructure could be pushed.

I wanted to design a custom file abstraction layer.

I wanted to gain practical experience with rate limits, retries, and large file transfers.

I wanted a real project that would bring out real-world edge cases.

I enjoy creating unusual but technically feasible systems.


In short:

> This project was created because I could create it and because it was interesting to do so.




---

🧩 Project Scope

DiscordStorage is intentionally kept focused:

There is no external cloud synchronization.

There is no dependency on third-party storage services.

There is no attempt to compete with commercial cloud platforms.

The sharing service is no longer operational; the server has been shut down.
https://github.com/KeremKuyucu/discordStorage-share
project link


Translated with DeepL.com (free version)
