import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        void: {
          DEFAULT: '#000000',
          charcoal: '#0A0A0C',
        },
        bone: {
          DEFAULT: '#D4D4D4',
        },
        accent: {
          gold: '#B89947',
          blood: '#8A0303',
        },
      },
      fontFamily: {
        serif: ['var(--font-playfair)', 'serif'],
        sans: ['var(--font-space)', 'sans-serif'],
        gothic: ['var(--font-gothic)', 'serif'],
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
}
export default config
