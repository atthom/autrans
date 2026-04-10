/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class', // Enable dark mode with class strategy
  theme: {
    extend: {
      colors: {
        gray: {
          850: '#1a202e', // Custom gray between 800 and 900
        },
      },
    },
  },
  plugins: [],
}
