import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      manifest: {
        name: 'بیان - Quran Reader',
        short_name: 'بیان',
        description: 'Quran with Al-Bayan Urdu translation and tafseer',
        theme_color: '#1B4332',
        background_color: '#FFF9F0',
        display: 'standalone',
        orientation: 'portrait',
        lang: 'ur',
        dir: 'rtl',
        icons: [
          { src: '/icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: '/icon-512.png', sizes: '512x512', type: 'image/png' }
        ]
      }
    })
  ],
  build: { outDir: 'dist' }
})
