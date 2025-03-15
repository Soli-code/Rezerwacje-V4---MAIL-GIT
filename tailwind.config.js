/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './index.html',
    './src/**/*.{js,ts,jsx,tsx}'
  ],
  theme: {
    extend: {
      colors: {
        solrent: {
          orange: '#FF6B00',
          dark: '#333333',
          gray: '#666666',
          light: '#F5F5F5'
        }
      }
    },
  },
  plugins: [],
};