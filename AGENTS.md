# DSH-app Vision

DSH-app is Akash's ambitious project to make the DSH mobile experience a truly standalone native Android app.

Akash loved the Flutter UI from `ccch1mneyyy/dsh-Go`; its interface, themes, chats, and companions were already perfect and are not the problem. `JopenChen/dsh-go` showed that the DeepSeek Harness engine could be rewritten in Go.

The goal is to remove the non-native local engine stack—PRoot, Ubuntu/rootfs, Node.js, and any Termux or external runtime dependency—and replace it with a complete Android-native Go engine while keeping the existing UI unchanged.

Every important DSH capability should be wired, ported, migrated, or rewritten for native Android as needed, including tools, shell, files, search, web search, Git, GitHub, package and plugin management, phone control, voice, authentication, persistence, and recovery.

The finished DSH-app must install and run by itself. Akash is ambitious enough to use AI to rewrite every engine-side component necessary to make that vision real.
