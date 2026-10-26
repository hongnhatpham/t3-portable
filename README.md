<img src="assets/icon.svg" width="64" height="64" alt="">

# T3 Portable

[T3 Code](https://t3.codes) for Windows computers where you can't install software. Everything runs from one folder: T3 Code, Claude Code, Codex, Git, your sign-ins and your threads. It keeps itself up to date with the official T3 Code releases.

Needs Windows 10 or 11 and an internet connection.

## Quick start

1. **Download.** On this page, click **Code**, then **Download ZIP**.
2. **Unblock.** Right-click the ZIP, choose **Properties**, tick **Unblock** at the bottom, then click **OK**. This stops Windows from warning about the files inside.
3. **Extract.** Right-click the ZIP, choose **Extract All**, and pick a place you can save files, such as Documents, the Desktop or a USB drive.
4. **Start.** Open the extracted folder and double-click **T3 Code.cmd**. The first start downloads about 450 MB, so give it a few minutes.
5. **Sign in** once, with your own subscriptions:
   - **Claude:** open a terminal in T3 and run `claude auth login`.
   - **Codex:** open T3's settings, set up Codex and sign in with ChatGPT. T3 downloads Codex into this folder.

T3 Code opens in its own window (Microsoft Edge without tabs or an address bar). Keep the black window open while you work. Close it to quit. Double-click **T3 Code.cmd** again any time to open another window.

Sign-ins are saved in the `data` folder. Treat it like a password. If you lose a USB drive with it, sign out of all sessions in your ChatGPT and Claude account settings.

## If something goes wrong

- **Windows asks before running T3 Code.cmd:** the ZIP wasn't unblocked. Allow it to run, or delete the folder and start again from step 2.
- **T3 doesn't open by itself:** double-click **T3 Code.cmd** again.
- **A download fails:** check the internet connection and start again. Anything missing is downloaded again.
- **Windows says an app "has been blocked by your system administrator":** see [If programs are blocked](#if-programs-are-blocked).

## Updates

Every start checks for updates in the background. They apply the next time you start T3 Code.

- T3 Code follows the **nightly** channel. To change it, edit `T3CODE_CHANNEL` near the top of `T3 Code.cmd` (`stable`, `nightly` or `preview`).
- Claude Code updates the same way. T3 Code keeps Codex updated itself.
- The last update check is logged in `data\update.log`.

## When PowerShell is blocked

Downloads use PowerShell first because it follows the computer's proxy settings. If PowerShell is blocked or fails, the built-in `curl` and `certutil` take over. T3's own terminal works the same way: PowerShell first, then cmd. Claude uses the portable Git Bash, so it doesn't need PowerShell. To skip PowerShell completely, run `set T3P_NO_POWERSHELL=1` before starting `T3 Code.cmd` from a cmd window.

## If programs are blocked

Some computers only run programs IT has approved. Nothing in this folder works there. These options need only a browser:

- Keep T3 Code running on another computer and reach it from here with T3 Connect (`t3 connect` on that computer).
- Use Codex on the web (chatgpt.com/codex) or Claude Code on the web (claude.ai/code) with GitHub repositories.

Check your institution's rules before running software it hasn't approved.

## What's in the folder

| Path | What it is |
| --- | --- |
| `T3 Code.cmd` | Starts T3 Code |
| `scripts\setup.cmd` | Downloads and updates |
| `data\` | T3 Code data, threads and sign-ins, created on first start |
| `bin\`, `tools\` | Downloaded programs |
| `projects\` | A place for your projects, so they travel with the folder |
