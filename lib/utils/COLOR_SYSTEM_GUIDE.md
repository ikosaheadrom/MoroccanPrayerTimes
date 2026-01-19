# Color System Migration Guide

## Quick Start

The new color system `AppColorsStreamlined` is ready to use. To implement it in main.dart:

### 1. Import the new color system at the top of main.dart:
```dart
import 'utils/app_colors_streamlined.dart';
```

### 2. Initialize colors in your widget:
```dart
final colors = await AppColorsStreamlined.init(context);
// OR use cached version:
final colors = AppColorsStreamlined.fromCache();
```

### 3. Replace color references with variables

## Color Variable Mapping

### Priority 1: Headers
- `color: Theme.of(context).colorScheme.primary` → `colors.header_txt`
- Page background → `colors.header_bg`

### Priority 2: Tabs
- Tab text → `colors.tab_txt`
- Tab background → `colors.tab_bg`

### Priority 3: Surface (Main Content)
- Surface background → `colors.surface_bg`
- Surface text → `colors.surface_txt`
- Surface secondary text → `colors.surface_subtxt`

### Priority 4: Primary Container
- `scheme.onPrimaryContainer` → `colors.primarycontainer_txt`
- Secondary text → `colors.primarycontainer_subtxt`
- `scheme.primaryContainer` → `colors.primarycontainer_bg`

### Priority 5: Secondary Container
- Secondary text → `colors.secondarycontainer_txt`
- Secondary text muted → `colors.secondarycontainer_subtxt`
- Background → `colors.secondarycontainer_bg`
- **Highlighted state:**
  - `colors.HLsecondarycontainer_bg`
  - `colors.HLsecondarycontainer_txt`
  - `colors.HLsecondarycontainer_subtxt`

### Priority 6: Tertiary Container
- `colors.tertiarycontainer_txt`
- `colors.tertiarycontainer_subtxt`
- `colors.tertiarycontainer_bg`

### Priority 7: Buttons
- Enabled/Active → `colors.button_on`
- Disabled → `colors.button_off`

### Priority 8: Switches/Toggles
- Active → `colors.switch_on`
- Inactive → `colors.switch_off`

### Priority 9: Text Fields
- Input text → `colors.textfield_txt`
- Hint/Helper text → `colors.textfield_subtxt`
- Background → `colors.textfield_bg`

### Priority 10: Dropdowns
- Normal text → `colors.dropdown_txt`
- Normal background → `colors.dropdown_bg`
- Selected text → `colors.HLdropdown_txt`
- Selected background → `colors.HLdropdown_bg`

## Additional Variables

- **Borders:** `colors.border`, `colors.divider`
- **States:** `colors.error_txt`, `colors.error_bg`, `colors.success_txt`, `colors.success_bg`, `colors.warning_txt`, `colors.warning_bg`
- **Overlays:** `colors.shadow`, `colors.scrim`

## Customization

To customize any color, edit the saturation/lightness values in `app_colors_streamlined.dart`:

```dart
/// Example: Prayer card background
Color get prayerCardBackground => isDarkMode 
  ? _hsl(0.80, 0.22)  // Dark mode: saturation=0.80, lightness=0.22
  : _hsl(0.50, 0.90); // Light mode: saturation=0.50, lightness=0.90
```

Change the values (0.80, 0.22) and hot restart to see changes.

## Common Replacements

| Old Code | New Code |
|----------|----------|
| `Theme.of(context).colorScheme.primary` | `colors.button_on` or `colors.primarycontainer_txt` |
| `scheme.primaryContainer` | `colors.primarycontainer_bg` |
| `scheme.onPrimaryContainer` | `colors.primarycontainer_txt` |
| `Theme.of(context).colorScheme.surface` | `colors.surface_bg` |
| `Theme.of(context).colorScheme.outline` | `colors.border` or `colors.divider` |
| `Colors.red` | `colors.error_txt` |
| `Colors.green` | `colors.success_txt` |

## Next Steps

The color system is ready. Now replace all `color:` references in main.dart using these variables.
