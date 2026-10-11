/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      screens: {
        'xs': '420px',
        '3xl': '1920px',
      },
      colors: {
        industrial: {
          dark: '#080e21',
          card: '#111b33',
          border: '#1f2d4d',
          accent: '#2563eb',
          warning: '#d97706',
          success: '#059669',
          danger: '#dc2626',
          purple: '#7c3aed'
        }
      }
    }
  },
  plugins: [],
}
