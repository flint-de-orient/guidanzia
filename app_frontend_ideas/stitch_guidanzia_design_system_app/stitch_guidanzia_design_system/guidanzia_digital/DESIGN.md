---
name: Guidanzia Digital
colors:
  surface: '#faf8ff'
  surface-dim: '#d2d9f9'
  surface-bright: '#faf8ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f3ff'
  surface-container: '#ebedff'
  surface-container-high: '#e3e7ff'
  surface-container-highest: '#dbe1ff'
  on-surface: '#131b32'
  on-surface-variant: '#4e4635'
  inverse-surface: '#282f48'
  inverse-on-surface: '#eff0ff'
  outline: '#807663'
  outline-variant: '#d2c5b0'
  surface-tint: '#785a00'
  primary: '#785a00'
  on-primary: '#ffffff'
  primary-container: '#f5c451'
  on-primary-container: '#6d5100'
  inverse-primary: '#f0c04d'
  secondary: '#4f6700'
  on-secondary: '#ffffff'
  secondary-container: '#c6f24e'
  on-secondary-container: '#546d00'
  tertiary: '#006a6a'
  on-tertiary: '#ffffff'
  tertiary-container: '#4bdfdf'
  on-tertiary-container: '#006060'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
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
  background: '#faf8ff'
  on-background: '#131b32'
  surface-variant: '#dbe1ff'
typography:
  display-xl:
    fontFamily: Sora
    fontSize: 72px
    fontWeight: '800'
    lineHeight: '1.1'
    letterSpacing: -0.04em
  display-lg:
    fontFamily: Sora
    fontSize: 48px
    fontWeight: '800'
    lineHeight: '1.1'
    letterSpacing: -0.03em
  headline-md:
    fontFamily: Sora
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  headline-sm:
    fontFamily: Sora
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
  body-lg:
    fontFamily: Be Vietnam Pro
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.7'
  body-md:
    fontFamily: Be Vietnam Pro
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.6'
  label-bold:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '700'
    lineHeight: '1.2'
  display-lg-mobile:
    fontFamily: Sora
    fontSize: 40px
    fontWeight: '800'
    lineHeight: '1.1'
  headline-md-mobile:
    fontFamily: Sora
    fontSize: 28px
    fontWeight: '700'
    lineHeight: '1.2'
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  gutter: 16px
  margin-mobile: 20px
  margin-desktop: 40px
  stack-sm: 8px
  stack-md: 24px
  stack-lg: 48px
---

## Brand & Style

This design system is engineered for the next generation of Indian professionals. The aesthetic is **High-Contrast Bold**, moving away from traditional academic tropes to embrace a high-energy, consumer-first identity. It is designed to feel like a high-end lifestyle or fintech app rather than a digital classroom.

The personality is confident and playful. While previously a dark-mode first system, it has transitioned to a **Light Mode** foundation to improve legibility and provide a cleaner, more accessible experience for professional use. It leverages oversized typography and a vibrant accent palette to navigate users through complex career data with ease and excitement. Visual interest is maintained through structural linework, flat surfaces, and intentional "streaks" of acid lime rather than organic shapes or realistic textures.

## Colors

The palette is anchored in a clean, professional Light Mode base, utilizing a Deep Navy neutral for text and structural elements to maintain high contrast.

- **Primary (Warm Gold):** Reserved for core branding and primary CTA surfaces. It evokes achievement and optimism.
- **Secondary (Acid Lime):** Used as a "highlighter" for success states, progress indicators, and decorative streaks to add energy.
- **Tertiary (Soft Cyan):** Specifically allocated for data visualization and AI-driven insights to distinguish informational content from navigational actions.
- **Neutral (Deep Navy):** Provides the foundational ink for typography and borders, ensuring every element feels grounded against the light background.

## Typography

The typographic system relies on **Sora** for massive, geometric headlines that demand attention. To accommodate the target audience, the system is optimized for multilingual support:
- **English:** Sora (Headlines) and Be Vietnam Pro (Body).
- **Hindi & Bengali:** Use Google Noto Sans Devanagari/Bengali for technical legibility, matched to the x-height of Be Vietnam Pro.

Body copy is set with generous line heights to ensure readability during long discovery sessions. Tight tracking is strictly enforced for display sizes to maintain a compact, "designed" feel. **Hanken Grotesk** is used exclusively for labels and technical metadata to provide a distinct functional voice.

## Layout & Spacing

This design system uses a **Fluid Grid** model focused on mobile-first interaction. 

- **Thumb-Zone Optimization:** All primary actions (navigation, "Next" steps, filters) are placed in the bottom 30% of the screen. 
- **Rhythm:** A 4px baseline grid governs all spacing. Vertical stacks use 24px as the standard gap between content blocks to ensure the UI feels "breathable" despite the bold colors.
- **Margins:** 20px safe areas on mobile ensure content does not feel cramped against the bezel. On desktop, the content is capped at a 1200px max-width container.

## Elevation & Depth

In Light Mode, the system maintains a clean, modern aesthetic by avoiding traditional drop shadows in favor of tonal layering and structural definition.

- **Tonal Layering:** Depth is created by using subtle shifts in surface color. Containers and cards sit on the primary background with clearly defined borders.
- **Structural Outlines:** Every container and card features a `2px` solid border in the Neutral Deep Navy (`#0A1229`) to provide a "Brutalist-lite" structure that contains the vibrant accent colors.
- **Action Emphasis:** Primary CTA buttons utilize the high-contrast Primary Gold against the light background. Focus states and active elements are signaled through border-color shifts rather than "lifting" elements.

## Shapes

The shape language is a mix of hyper-rounded containers and full-pill interactive elements, providing a friendly yet structured feel.

- **Cards:** Use a consistent 24px radius to create an approachable container for career data.
- **Buttons:** Always use a full-pill (999px) radius to maximize "tapability" and visual distinction from content cards.
- **Decorative Elements:** Use 2px "hairlines" for all dividers and borders to maintain a structured, technical feel that balances the soft rounded corners.

## Components

- **Buttons:** Primary buttons are Solid Gold with Deep Navy text; Secondary are Outlined Acid Lime with Deep Navy text. All buttons are Pill-shaped with a minimum height of 56px for mobile accessibility.
- **Chips:** Small, 12px-radius tags used for career categories. Use a light neutral background with Tertiary Cyan for text to provide a soft distinction.
- **Input Fields:** 12px radius, light background, with 2px borders that turn Gold on active state. Labels must be Hanken Grotesk Bold, positioned above the field in Deep Navy.
- **Cards:** The core of the experience. Background is the lightest surface container, border is 2px Hairline. Content inside cards must follow the 24px padding rule.
- **Selection Controls:** Checkboxes and Radios are oversized (24px width) and use the Acid Lime color when selected to provide high-visibility feedback against the light background.
- **Lists:** Career paths or schools are displayed in high-contrast list items with 16px bottom margins, separated by hairline borders. Avoid icons; use bold typography or color streaks for visual hierarchy.