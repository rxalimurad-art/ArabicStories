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
        cream: '#F5F3FF',
        gold:  '#F59E0B',
      },
    },
  },
  plugins: [],
}
