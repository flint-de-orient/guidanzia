---
name: Kinetic Precision
colors:
  surface: '#17130c'
  surface-dim: '#17130c'
  surface-bright: '#3e3930'
  surface-container-lowest: '#110e07'
  surface-container-low: '#1f1b13'
  surface-container: '#231f17'
  surface-container-high: '#2e2921'
  surface-container-highest: '#39342b'
  on-surface: '#ebe1d4'
  on-surface-variant: '#d2c5b0'
  inverse-surface: '#ebe1d4'
  inverse-on-surface: '#353027'
  outline: '#9b8f7c'
  outline-variant: '#4e4635'
  surface-tint: '#f0c04d'
  primary: '#ffe4af'
  on-primary: '#3f2e00'
  primary-container: '#f5c451'
  on-primary-container: '#6d5100'
  inverse-primary: '#785a00'
  secondary: '#abd533'
  on-secondary: '#273500'
  secondary-container: '#89b100'
  on-secondary-container: '#2f3f00'
  tertiary: '#6efcfc'
  on-tertiary: '#003737'
  tertiary-container: '#4bdfdf'
  on-tertiary-container: '#006060'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdf9d'
  primary-fixed-dim: '#f0c04d'
  on-primary-fixed: '#251a00'
  on-primary-fixed-variant: '#5b4300'
  secondary-fixed: '#c6f24e'
  secondary-fixed-dim: '#abd533'
  on-secondary-fixed: '#151f00'
  on-secondary-fixed-variant: '#3a4d00'
  tertiary-fixed: '#69f7f7'
  tertiary-fixed-dim: '#45dada'
  on-tertiary-fixed: '#002020'
  on-tertiary-fixed-variant: '#004f50'
  background: '#17130c'
  on-background: '#ebe1d4'
  surface-variant: '#39342b'
typography:
  headline-xl:
    fontFamily: Manrope
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Manrope
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-md:
    fontFamily: Manrope
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Hanken Grotesk
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-caps:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.08em
  data-mono:
    fontFamily: JetBrains Mono
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 40px
  container-max: 1440px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 32px
---

## Brand & Style

The design system is engineered for a high-performance, data-driven environment. It targets a professional audience that requires speed and precision without sacrificing a premium aesthetic. The brand personality is authoritative yet energetic, evoking the feeling of a sophisticated command center or a high-end financial terminal.

The visual style is a hybrid of **Corporate Modern** and **High-Contrast Bold**. It utilizes a deep, layered dark mode to create a sense of immense digital space, while sharp, high-energy accents (Warm Gold and Acid Lime) provide immediate visual hierarchy and directional energy. The UI is "tool-like," emphasizing density, clarity, and rapid information processing through a sophisticated "Dark Glass" aesthetic—utilizing subtle hairline borders and tonal shifts rather than heavy shadows to define structure.

## Colors

The palette is built on a "Deep Sea" foundation of #0A1229, providing a stable, low-strain background for extended use. 

- **Primary (Warm Gold):** Reserved for primary actions, key milestones, and critical branding elements. It signifies value and achievement.
- **Secondary (Acid Lime):** A high-visibility "streak" color used for positive performance indicators, real-time updates, and small-scale success states.
- **Tertiary (Soft Cyan):** Specifically allocated for data visualization and technical metadata to ensure distinct separation from action colors.
- **Surface Hierarchy:** Depth is created through a progression from the Base Navy (#0A1229) to Elevated Surfaces (#141F42). Connectivity and containment are managed strictly through Hairline Borders (#243056) to maintain a crisp, engineered look.

## Typography

This design system utilizes a three-tier typographic approach to balance professional refinement with technical utility.

1.  **Manrope (Headlines):** Chosen for its geometric balance and modern feel. It provides a confident, stable structure for page titles and section headers.
2.  **Hanken Grotesk (Body):** A sharp, contemporary sans-serif that maintains high legibility in dense data environments. It feels precise and efficient.
3.  **JetBrains Mono (Labels/Data):** Used for micro-copy, status labels, and numerical data. The monospaced nature emphasizes the "tool" aesthetic and ensures numerical alignment in dashboards and lists.

All uppercase labels should use `label-caps` with increased letter-spacing to enhance scan-speed in complex layouts.

## Layout & Spacing

The layout philosophy follows a **Fluid Grid** model based on a 4px baseline unit. This allows for the high density required for professional tools while maintaining rhythmic balance.

- **Desktop:** 12-column grid with 16px gutters. Elements should snap to the 4px grid for vertical rhythm.
- **Tablet:** 8-column grid with 16px gutters.
- **Mobile:** 4-column grid with 16px margins. Headlines scale down to `headline-lg-mobile` to maintain composition.

Spacing should be used to group related data points tightly (`sm` or `md`) while using larger gaps (`xl`) to separate distinct functional modules. This creates "islands" of information that help the user navigate complex views.

## Elevation & Depth

This design system rejects traditional soft shadows in favor of **Tonal Layers** and **Hairline Outlines**. This creates a flat, high-tech aesthetic that feels like a precision instrument.

- **Base Layer:** #0A1229 (The main background).
- **Surface Layer:** #141F42 (Cards, navigation sidebars, and modals).
- **Interactive Layer:** Surfaces that are hoverable should transition slightly in luminosity or gain a 1px border of #243056.
- **Accent Depth:** Use very subtle 40px blurs of #F5C451 at 5% opacity behind primary buttons or active states to create a "glow" effect without the weight of a shadow.

## Shapes

The shape language is "Soft-Industrial." The choice of `roundedness: 1` (4px default) ensures that elements feel approachable but remain disciplined and space-efficient.

- **Small Components:** Checkboxes, tags, and small buttons use the 4px radius.
- **Containers:** Large cards and modals use 8px (`rounded-lg`) to provide a distinct structural frame.
- **Data Points:** Graphs and progress bars should use sharp or 2px corners to maintain a "technical" look.

## Components

- **Buttons:** Primary buttons use a solid #F5C451 fill with #0A1229 text. Secondary buttons are outlined using #243056 with #F4F6FF text. Use a "High-Energy" hover state where the Acid Lime (#C6F24E) appears as a 2px bottom border.
- **Chips/Tags:** Use the Soft Cyan (#4ADEDE) at 10% opacity for backgrounds with a solid Soft Cyan text for data categories. Use Acid Lime for "Active" or "Success" status chips.
- **Input Fields:** Backgrounds should be #141F42 with a 1px border of #243056. On focus, the border transitions to Warm Gold (#F5C451).
- **Lists:** Use subtle #243056 dividers between rows. Zebra-striping is discouraged; instead, use hover states to highlight rows in #141F42.
- **Cards:** Cards are defined by their #141F42 fill and #243056 border. No shadows.
- **Progress Bars:** The track should be #243056, with the fill using a gradient from #F5C451 to #C6F24E to signify kinetic energy and progress.