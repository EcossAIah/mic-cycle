# Testing

There is no XCTest target. Tests are small executables compiled with `swiftc`
by `test-core-audio.sh`.

## Logic tests

```sh
./test-core-audio.sh --logic-only
```

`Tests/CoreAudioLogicTests.swift` drives `CoreAudioClient.switchAndVerify` and
`CoreAudioClient.nextInput` with fake device lists, reads, and writes. Nothing
touches real hardware, so this runs in CI. It checks:

- a switch succeeds only when the readback matches the requested device
- delayed readback is polled without repeating the write
- the production retry window allows confirmation after 350 ms
- a mismatched readback fails after bounded retries
- unavailable and ineligible devices are rejected before any write
- write, read, and enumeration failures propagate
- cycling skips ineligible devices, wraps, and handles an unknown current
  device, an all-ineligible list, and an empty list

## Hardware smoke test

```sh
./test-core-audio.sh
```

This runs the logic tests, then `Tests/CoreAudioSmoke.swift`, which:

1. lists the inputs and records the current default
2. refuses to run if there is no eligible input or no restorable original default
3. switches to each eligible input through the app's code path and confirms it
   with an independent Core Audio read
4. checks that an invalid device ID is rejected
5. checks that a default-input change notification arrives
6. restores the original default input (exit code 2 if that fails)

It changes the system default input while it runs, so do not run it during a call
or recording. It does not capture audio or check audio quality.

## Manual checks

These need a person at the Mac:

- The menu lists the expected inputs, with a checkmark on the current one.
- Choosing an input switches it and shows the confirmation panel.
- Control+Option+M cycles through the inputs and wraps.
- Plugging in or removing a USB or Bluetooth microphone updates the menu.
- Changing the input in System Settings > Sound updates the checkmark.
- With the shortcut taken by another app, the menu shows the registration error.
- Copy Diagnostics puts readable text on the clipboard.
