---
name: Kinetic Obsidian
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
    fontFamily: Sora
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Sora
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Sora
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
  headline-md:
    fontFamily: Sora
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Sora
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Sora
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Sora
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Sora
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.05em
  mono-data:
    fontFamily: Sora
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 20px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  container-margin: 24px
  gutter: 16px
  section-gap: 48px
  stack-xs: 4px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 24px
---

## Brand & Style

This design system is engineered for high-performance environments that demand both focus and intensity. The brand personality is aggressive yet sophisticated, blending the precision of a high-end dashboard with the energy of a premium sports or gaming interface. It targets power users who value speed, clarity, and a sense of "prestige-tech" urgency.

The aesthetic leans into **Corporate Modern with High-Contrast accents**. It utilizes deep, layered navy surfaces to create an expansive sense of depth, allowing the warm gold and acid lime accents to pierce through the interface. The emotional response is one of controlled energy—an "always-on" state where data feels alive and actionable. Visual interest is maintained through sharp geometric precision and deliberate use of vibrant color "streaks" to guide the eye toward success states and critical metrics.

## Colors

The color palette is built on a foundation of "Deep Obsidian" tones to maximize contrast for the vibrant accent colors.

- **Foundation:** The `#0A1229` base provides a near-infinite backdrop. Secondary surfaces use `#141F42` to create structural hierarchy without breaking the dark-mode immersion.
- **Accents:** 
    - **Warm Gold (#F5C451):** Reserved for primary actions, branding elements, and premium status indicators. It provides a sense of "achievement" and "value."
    - **Acid Lime (#C6F24E):** Used specifically for momentum, positive growth, success notifications, and "streak" indicators. It is the high-energy pulse of the UI.
    - **Soft Cyan (#4ADEDE):** Dedicated to data visualization and informational highlights, providing a cool counter-balance to the warmer accents.
- **Typography:** Primary text uses a high-visibility off-white, while muted text sits back in a desaturated blue-grey to reduce cognitive load in data-heavy views.

## Typography

This design system exclusively uses **Sora** to maintain brand continuity and capitalize on its geometric, tech-forward apertures. 

Large headlines utilize heavy weights (700) and negative letter spacing to create a compact, impactful look suitable for "Guidanzia Digital" aesthetics. Body text is kept at a comfortable 400 weight for legibility against the dark background. For data points and metrics, ensure tabular numerals are enabled to maintain vertical alignment in lists and dashboards. Labels should be uppercase or medium-weight to distinguish them clearly from body content.

## Layout & Spacing

The layout philosophy follows a **Fluid Grid** model with a base unit of 4px.

- **Desktop:** 12-column grid with 24px gutters. Content is often organized in "widgets" or "cards" that span 3, 4, or 6 columns.
- **Mobile:** 4-column grid with 16px margins. 
- **Rhythm:** Use an 8px-step vertical rhythm for standard components, but allow for 4px increments in dense data tables. Horizontal padding within elevated surfaces should be a consistent 24px to provide "breathing room" amidst high-energy colors.

## Elevation & Depth

Depth is communicated through **Tonal Layers** and **Low-Contrast Outlines** rather than traditional shadows.

1.  **Level 0 (Base):** `#0A1229` — The main canvas.
2.  **Level 1 (Card/Surface):** `#141F42` — Used for primary content containers. 
3.  **Borders:** Every elevated surface must have a 1px "Hairline" border of `#243056`. This defines the edges clearly in a low-light environment without the "muddiness" of heavy shadows.
4.  **Interaction Depth:** Upon hover or active state, an element may receive a subtle outer glow using a 10% opacity version of the Primary Gold or Secondary Lime color to simulate "energy" emission.

## Shapes

The design system utilizes a consistent **8px (Rounded)** corner radius. 

This specific radius strikes a balance between the mechanical precision of sharp corners and the modern friendliness of fully rounded shapes. It ensures that components feel structural and solid. 
- **Small Components (Checkboxes, mini-chips):** Use 4px (Soft) to maintain visual proportions.
- **Interactive Elements (Buttons, Cards):** Strictly 8px.
- **Outer Containers:** May use 12px or 16px only when nesting 8px inner cards to maintain concentric visual harmony.

## Components

- **Buttons:**
  - **Primary:** Warm Gold (#F5C451) background with black or very dark navy text for maximum contrast. No border.
  - **Success/Action:** Acid Lime (#C6F24E) for "Start," "Win," or "Complete" actions.
  - **Ghost:** Transparent background with `#243056` border and primary text.
- **Input Fields:**
  - Background: `#0A1229` (inset look) or `#141F42` (on base). 1px border using `#243056`. Focus state switches border to Warm Gold.
- **Cards:**
  - Surface `#141F42`, 1px border `#243056`, 8px corner radius.
- **Chips/Badges:**
  - High-energy indicators (e.g., "Live," "Hot," "+25%") use a solid Acid Lime background with condensed Sora Bold text.
- **Lists:**
  - Items separated by 1px `#243056` lines. Hover states should use a subtle tint of the primary color at 5% opacity.
- **Data Visuals:**
  - Use Soft Cyan (#4ADEDE) for trend lines, coupled with Acid Lime for positive peaks. Use thin, precise strokes (1.5pt to 2pt).