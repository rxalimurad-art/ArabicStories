/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      fontFamily: {
        quran: ['IndoPak', '"Amiri Quran"', 'serif'],
        urdu:  ['"Noto Nastaliq Urdu"', 'serif'],
      },
      colors: {
        forest: {
          50:  '#f0fdf4',
          100: '#dcfce7',
          700: '#15803d',
          800: '#166534',
          900: '#14532d',
        },
        cream: '#FFF9F0',
        gold:  '#B8860B',
      },
    },
  },
  plugins: [],
}
