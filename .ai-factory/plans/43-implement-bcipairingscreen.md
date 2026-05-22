# Plan: Implement `BciPairingScreen`

## Context

Build the single-screen pairing UI (`BciPairingScreen`) inside `packages/bci_module/` that drives the full BCI device lifecycle — discovery, impedance, calibration — reading state from `bciPairingViewModelProvider` and playing the calibration-complete cue via `mind_audio`. The Service/Coordinator concrete implementations are out of scope (next milestone); this milestone delivers UI + l10n keys + asset + pubspec wiring so the screen compiles inside the package.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Package wiring & assets

- [x] **Task 1: Swap `just_audio` for `mind_audio` in `bci_module` pubspec and copy calibration sound asset**
  Files: `packages/bci_module/pubspec.yaml`, `packages/bci_module/assets/calibration_complete.wav` (new)
  In `packages/bci_module/pubspec.yaml` under `dependencies`:
  - **Remove** the `just_audio: ^0.10.5` line (note 17 explicitly forbids `bci_module` from importing `just_audio` directly — `AudioOneShot` / `AssetAudioCatalog` from `mind_audio` are the only entry points used).
  - **Add** `mind_audio: { path: ../mind_audio }`.
  - Keep existing `flutter` sdk, `flutter_riverpod`, `mind_l10n`, `mind_ui`.

  Create `packages/bci_module/assets/` directory and copy the calibration completion sound from `neiry_kit/example/assets/sounds/done.wav` into `packages/bci_module/assets/calibration_complete.wav` (use `done.wav` — that is the file present in the neiry example tree).

  Replace the existing empty `flutter:` block with:
  ```yaml
  flutter:
    uses-material-design: true   # package widgets use Material icons (close, bluetooth, check_circle, battery_full)
    assets:
      - assets/calibration_complete.wav
  ```
  **Guard 1:** the asset path must be `assets/calibration_complete.wav` (package-root-relative), NOT `packages/bci_module/assets/...`.

  Run `flutter pub get` from the host app root (`mind_mobile/`) — pubspec changes in a path-dep package take effect when the host's lockfile refreshes, not when running pub get inside the package directory.

### Phase 2: l10n keys

- [x] **Task 2: Add BCI pairing l10n keys to ARB files** (depends on Task 1)
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb`
  Append the following keys to `app_en.arb` (before the closing `}`), wired with a leading comma after the previous last entry:
  - `bciPairingTitle`: "Connect Headband"
  - `bciPairingNearbyDevices`: "Nearby devices"
  - `bciPairingKnownDevice`: "Paired"          (short form — fits as a list-row trailing chip)
  - `bciPairingSignalQuality`: "Signal quality"
  - `bciPairingAdjustHeadband`: "Adjust headband for good contact on all channels."
  - `bciPairingCalibration`: "Calibration"
  - `bciPairingStartCalibration`: "Start calibration"
  - `bciPairingCloseEyes`: "Close your eyes and relax."
  - `bciPairingCalibrationComplete`: "Calibration complete"
  - `bciPairingDisconnect`: "Disconnect"
  - `bciPairingDisconnectConfirm`: "Disconnect device?"

  Mirror all eleven keys into `app_ru.arb` with idiomatic Russian translations:
  - `bciPairingTitle` → "Подключить нейрогарнитуру"
  - `bciPairingNearbyDevices` → "Устройства рядом"
  - `bciPairingKnownDevice` → "Сопряжено"
  - `bciPairingSignalQuality` → "Качество сигнала"
  - `bciPairingAdjustHeadband` → "Поправьте гарнитуру для хорошего контакта на всех каналах."
  - `bciPairingCalibration` → "Калибровка"
  - `bciPairingStartCalibration` → "Начать калибровку"
  - `bciPairingCloseEyes` → "Закройте глаза и расслабьтесь."
  - `bciPairingCalibrationComplete` → "Калибровка завершена"
  - `bciPairingDisconnect` → "Отключить"
  - `bciPairingDisconnectConfirm` → "Отключить устройство?"

  Regenerate `AppLocalizations` by running `flutter pub get` from the **host app root** (`mind_mobile/`) — the `flutter_localizations` toolchain regenerates `app_localizations*.dart` during the host's pub-get / build cycle (the `mind_l10n` package itself has `flutter: generate: true` and `synthetic-package: false` in `l10n.yaml`).

### Phase 3: Disconnect dialog helper

- [x] **Task 3: Create public `showBciDisconnectDialog` helper** (depends on Task 2)
  Files: `packages/bci_module/lib/src/BciPairing/Views/BciDisconnectDialog.dart` (new)
  Create a top-level function `Future<bool> showBciDisconnectDialog(BuildContext context)` that shows an `AlertDialog` with title from `AppLocalizations.of(context)!.bciPairingDisconnectConfirm`, a `Cancel` action (returning `false`, label from existing `cancel` key) and a destructive `Disconnect` action (returning `true`, label from `bciPairingDisconnect`, red `TextStyle`). Returns the dialog result, defaulting to `false` if dismissed via barrier tap.

  **Guard 2:** function name must be `showBciDisconnectDialog` (no leading underscore — public) so `BciPairingTopBar` (a sibling file under `Views/`) can import it. Public is required because Dart's library-private `_`-prefix names cannot be imported across files even within the same package.

### Phase 4: Section widgets

- [x] **Task 4: Implement `BciSectionHeader` and `BciDiscoverySection`** (depends on Task 3)
  Files: `packages/bci_module/lib/src/BciPairing/Views/BciSectionHeader.dart` (new), `packages/bci_module/lib/src/BciPairing/Views/BciDiscoverySection.dart` (new)

  First create a **local** `BciSectionHeader` widget — do **not** import `BreathSessionListSectionHeader` from `breath_module` (cross-package coupling forbidden). `BciSectionHeader` is a `StatelessWidget` taking a `String title`, rendering:
  ```dart
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
  ```

  Then `BciDiscoverySection` as a **`ConsumerStatefulWidget`** (needs `_pendingSerial` local state). Reads `bciPairingViewModelProvider`. Layout:
  - `BciSectionHeader(title: l10n.bciPairingNearbyDevices)`.
  - If `state.isScanning` → render a `LinearProgressIndicator` at the top of the section. (Note: intentionally simpler than note 17's empty-vs-non-empty split — note 17 distinguishes "shimmer when empty" vs "progress bar when list present"; we render the bar in both cases. Acceptable simplification.)
  - `ListView.builder` (use `shrinkWrap: true` + `physics: const NeverScrollableScrollPhysics()` so it nests inside the outer scroll view) of `state.devices`. Each row:
    - Leading: when `_pendingSerial == device.serial && state.isConnecting` → `SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))`. Otherwise `Icon(Icons.bluetooth)`.
    - Title: `device.name` (with `overflow: TextOverflow.ellipsis`).
    - Subtitle: short serial suffix (last 6 chars of `device.serial`).
    - Trailing: if `device.isKnown` → small `Chip(label: Text(l10n.bciPairingKnownDevice))` styled with `VisualDensity.compact`.
    - `onTap`: `setState(() => _pendingSerial = device.serial)` then `ref.read(bciPairingViewModelProvider.notifier).onDeviceTap(device.serial)`.

  Inside `build()` (not `initState`) register:
  ```dart
  ref.listen<BciPairingState>(bciPairingViewModelProvider, (prev, next) {
    if (next.isConnecting == false && _pendingSerial != null) {
      setState(() => _pendingSerial = null);
    }
  });
  ```
  This clears the spinner once the connection attempt resolves.

  Known limitations (acceptable for this milestone, properly fixed in the Service milestone when `BciPairingState` may grow a `targetConnectingSerial` field):
  - Spinner does not appear for auto-reconnect (no user tap to set `_pendingSerial`).
  - Tapping a second device clears the first row's spinner even if it is still the active target.
  - If the screen is rebuilt mid-connect (e.g. backgrounded then resumed), `_pendingSerial` is `null` and no row shows the spinner.

- [x] **Task 5: Implement `BciImpedanceSection`** (depends on Task 4)
  Files: `packages/bci_module/lib/src/BciPairing/Views/BciImpedanceSection.dart` (new)
  `ConsumerWidget`. Reads `bciPairingViewModelProvider`. Wrap whole section in:
  ```dart
  IgnorePointer(
    ignoring: state.stage == BciPairingStage.discovery,
    child: AnimatedOpacity(
      opacity: state.stage == BciPairingStage.discovery ? 0.38 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: ...,
    ),
  );
  ```
  Layout:
  - `BciSectionHeader(title: l10n.bciPairingSignalQuality)`.
  - Horizontal `Row` (`mainAxisAlignment: MainAxisAlignment.spaceEvenly`) of one `Column` per `state.channels` entry: a 28×28 `Container` with `BoxDecoration(shape: BoxShape.circle, color: <quality colour>)` above a small `Text(channel.channelName)` label. Colour mapping helper (private top-level function in the file):
    - `BciSignalQuality.good` → `Colors.green`
    - `BciSignalQuality.fair` → `Colors.amber`
    - `BciSignalQuality.poor` → `Colors.red`
  - Always render four placeholder circles even when `state.channels.isEmpty` (use `Colors.grey.shade400` placeholders with no channel name label) so the section reserves vertical space.
  - Caption below the row: `Text(l10n.bciPairingAdjustHeadband)`, styled `bodySmall` with `colorScheme.onSurfaceVariant`, padded to align with section content.

- [x] **Task 6: Implement `BciCalibrationSection`** (depends on Task 5)
  Files: `packages/bci_module/lib/src/BciPairing/Views/BciCalibrationSection.dart` (new)
  `ConsumerStatefulWidget` (needs `initState`/`dispose` for the audio cue). Wrapped in the same `IgnorePointer` + `AnimatedOpacity` (disabled when `state.stage == BciPairingStage.discovery`). State fields:
  ```dart
  late final AudioOneShot _completionCue;
  bool _cueReady = false;
  ```
  `initState`:
  ```dart
  super.initState();
  _completionCue = AudioOneShot();
  unawaited(_loadCue());   // Guard 3: must use unawaited(...) to satisfy unawaited_futures lint
  ```
  `_loadCue()`:
  ```dart
  Future<void> _loadCue() async {
    final source = await AssetAudioCatalog().sourceFor(
      const AudioTrack('packages/bci_module/assets/calibration_complete.wav'),
    );
    await _completionCue.load(source);
    if (mounted) setState(() => _cueReady = true);
  }
  ```
  `dispose()`: call `_completionCue.dispose()` then `super.dispose()`.

  `build()`:
  - `ref.listen<BciPairingState>(bciPairingViewModelProvider, (prev, next) { ... })` — fires the cue:
    ```dart
    if (_cueReady &&
        prev != null &&                                  // Guard 4
        prev.calibration?.isComplete != true &&
        next.calibration?.isComplete == true) {
      _completionCue.play();
    }
    ```
  - `final state = ref.watch(bciPairingViewModelProvider);` for the rest of the tree.
  - `BciSectionHeader(title: l10n.bciPairingCalibration)`.
  - Full-width `ElevatedButton(onPressed: state.stage == BciPairingStage.impedance ? () => ref.read(bciPairingViewModelProvider.notifier).onStartCalibration() : null, child: Text(l10n.bciPairingStartCalibration))`, wrapped in horizontal padding.
  - When `state.calibration != null` and `!state.calibration!.isComplete`:
    - Row of 4 stage dots (12×12 circles, `mainAxisAlignment: MainAxisAlignment.center`, 8px gap) — filled (`colorScheme.primary`) for `i < state.calibration!.stagesCompleted`, outlined (1px border in `colorScheme.outline`, transparent fill) otherwise.
    - `Text(l10n.bciPairingCloseEyes)` centered below the dots.
  - When `state.calibration?.isComplete == true`:
    - `Row(mainAxisSize: MainAxisSize.min)` centered: `Icon(Icons.check_circle, color: Colors.green)` + 8px gap + `Text(l10n.bciPairingCalibrationComplete)`.

  Note: this section does **not** invoke `showBciDisconnectDialog`. The disconnect dialog is owned exclusively by `BciPairingTopBar`. Guard 2 (public helper name) is still required so the top bar can import it from a sibling file under `Views/` — same-package, but separate Dart libraries require public top-level names.

### Phase 5: Screen assembly

- [x] **Task 7: Implement `BciPairingTopBar` using `AppBar`** (depends on Task 6)
  Files: `packages/bci_module/lib/src/BciPairing/Views/BciPairingTopBar.dart` (new)
  `ConsumerWidget` implementing `PreferredSizeWidget` (so it slots into `Scaffold.appBar`). Returns:
  ```dart
  AppBar(
    leading: IconButton(
      icon: const Icon(Icons.close),
      onPressed: () => ref.read(bciPairingViewModelProvider.notifier).onClose(),
    ),
    title: Text(AppLocalizations.of(context)!.bciPairingTitle),
    centerTitle: true,
    actions: [ ... ],
  );
  ```
  `preferredSize` returns `const Size.fromHeight(kToolbarHeight)`. Reads `bciPairingViewModelProvider` via `ref.watch` inside `build`.

  `actions` content (in order, right-aligned):
  - When `state.batteryPercent != null` → a `Padding` wrapping `Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.battery_full, size: 16), const SizedBox(width: 4), Text('${state.batteryPercent}%')])`. **No emoji** — use `Icons.battery_full` per project convention (global rule: only use emojis when explicitly requested).
  - When `state.stage != BciPairingStage.discovery` → `TextButton(onPressed: () async { final ok = await showBciDisconnectDialog(context); if (ok && context.mounted) ref.read(bciPairingViewModelProvider.notifier).onDisconnect(); }, style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(AppLocalizations.of(context)!.bciPairingDisconnect))`.

  Using `AppBar` removes the manual `Stack` / `NavigationToolbar` centering that a plain `Row` cannot achieve when leading/trailing widths differ.

- [x] **Task 8: Implement `BciPairingScreen` and export it** (depends on Task 7)
  Files: `packages/bci_module/lib/src/BciPairing/BciPairingScreen.dart` (new), `packages/bci_module/lib/bci_module.dart`
  Create `BciPairingScreen` as a `ConsumerStatefulWidget`:
  ```dart
  class BciPairingScreen extends ConsumerStatefulWidget {
    const BciPairingScreen({super.key});
    static const String name = 'bci_pairing';
    static const String path = '/$name';
    ...
  }
  ```
  In `initState`: schedule `ref.read(bciPairingViewModelProvider.notifier).initState()` via `WidgetsBinding.instance.addPostFrameCallback((_) { ... })` so the ViewModel begins scanning when the screen mounts (the ViewModel's own `initState()` method is the trigger — see `BciPairingViewModel.dart:32`).

  `build()` returns:
  ```dart
  Scaffold(
    appBar: const BciPairingTopBar(),
    body: SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            BciDiscoverySection(),
            Divider(height: 1),
            BciImpedanceSection(),
            Divider(height: 1),
            BciCalibrationSection(),
            SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
  ```
  Use `EdgeInsets.symmetric(vertical: 16)` for inter-section breathing room inside each section's own root padding (do **not** reference `AppDimensions` — `mind_ui`'s `app_dimensions.dart` only exports `kCardCornerRadius` and has no spacing constants; pick the numeric `16` explicitly here to stay self-contained without expanding `mind_ui`'s scope).

  In `packages/bci_module/lib/bci_module.dart`, add the export line under the existing `// Screens` comment:
  ```dart
  export 'src/BciPairing/BciPairingScreen.dart';
  ```

## Commit Plan
- **Commit 1** (after tasks 1–2): "Wire bci_module pubspec asset and add BCI pairing l10n keys"
- **Commit 2** (after tasks 3–6): "Build BciPairing section widgets and disconnect dialog"
- **Commit 3** (after tasks 7–8): "Assemble BciPairingScreen with top bar and export"
