import type { Metadata } from 'next'
import { Playfair_Display, Space_Grotesk, UnifrakturMaguntia } from 'next/font/google'
import './globals.css'

const playfair = Playfair_Display({
  subsets: ['latin'],
  variable: '--font-playfair',
  display: 'swap',
})

const space = Space_Grotesk({
  subsets: ['latin'],
  variable: '--font-space',
  display: 'swap',
})

const gothic = UnifrakturMaguntia({
  weight: '400',
  subsets: ['latin'],
  variable: '--font-gothic',
  display: 'swap',
})

export const metadata: Metadata = {
  title: 'BRKN Tattoos',
  description: 'Ultra-premium LA tattoo shop.',
}

import { ReactLenis } from 'lenis/react'

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" className={`${playfair.variable} ${space.variable} ${gothic.variable}`}>
      <body className="antialiased bg-void-charcoal text-bone">
        <ReactLenis root>
          <div className="noise-overlay"></div>
          {children}
        </ReactLenis>
      </body>
    </html>
  )
}
