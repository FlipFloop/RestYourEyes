# RestYourEyes

RestYourEyes is a lightweight (2.3Mb!) macOS menu bar application designed to help you reduce eye strain by reminding you to take regular breaks. It implements the popular 20-20-20 rule and other common timing patterns to keep your eyes healthy during long coding sessions.

Its aim is to be minimal. If you wish to see a new feature or optimize the code, please submit a PR.

## Features

- **Unintrusive Menu Bar Icon**: Shows the time remaining until your next break (optional).
- **Full Screen Break Overlay**: Gently forces you to take a break with a dimmed overlay.
- **Multiple Presets**:
  - **20-20-20 Rule**: 20 minutes work, 20 seconds break.
  - **10m - 10s**: 10 minutes work, 10 seconds break.
  - **Pomodoro**: 25 minutes work, 5 minutes break.
- **Controls**:
  - **Snooze**: Need 2 more minutes to finish a thought? Hit Snooze.
  - **Skip**: Urgent deadline? Skip the current break.

## Installation & Build

### Prerequisites

- macOS (10.13+)
- [Zig](https://ziglang.org/download/) (version 0.15.0 or later recommended)

### Building from Source

1. Clone the repository:

   ```bash
   git clone https://github.com/FlipFloop/RestYourEyes.git
   cd RestYourEyes
   ```

2. Build the application:

   ```bash
   zig build -Doptimize=ReleaseSmall
   ```

3. The application bundle will be generated in `zig-out/RestYourEyes.app`. You can drag this to your Applications folder.

   ```bash
   open zig-out/RestYourEyes.app
   ```

## License

This project is **Source Available** and free for personal, non-commercial use.

**You may:**

- View, modify, and use this software for your own personal use.
- Share this software with others for free.
- Contribute to the codebase.

**You may NOT:**

- Sell this software or any derivatives of it.
- Use this software for commercial purposes without explicit permission.
- Charge for distribution of this software.

For the full terms, please refer to the [LICENSE](LICENSE) file or contact the author: [Victor Guyard](https://victorguyard.com)
