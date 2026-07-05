'use client'

import { motion, useScroll, useTransform } from 'framer-motion'
import { useRef, useState } from 'react'
import { heavyPhysics } from '../motion/MotionWrapper'

export default function InstagramCTA() {
  const containerRef = useRef<HTMLElement>(null)
  
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start end", "end start"]
  })

  // Parallax effects for the grid columns
  const y1 = useTransform(scrollYProgress, [0, 1], [0, -150])
  const y2 = useTransform(scrollYProgress, [0, 1], [50, -50])
  const y3 = useTransform(scrollYProgress, [0, 1], [150, -100])

  return (
    <section ref={containerRef} className="py-24 px-6 sm:px-12 w-full max-w-7xl mx-auto flex flex-col gap-12 overflow-hidden">
      <div className="flex justify-between items-end border-b border-bone/20 pb-4">
        <h2 className="text-3xl sm:text-5xl font-serif text-bone uppercase tracking-widest">
          The Vault
        </h2>
        <span className="text-sm font-sans tracking-[0.2em] text-accent-blood uppercase">
          Instagram
        </span>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 md:h-[900px] md:overflow-hidden relative pb-12 md:pb-0">
        
        {/* Column 1 */}
        <motion.div style={{ y: y1 }} className="flex flex-col gap-6">
          {/* Mobile Position 1 (Knuckles) */}
          <div className="relative group w-full h-[400px] bg-void overflow-hidden md:hidden">
            <div className="absolute inset-0 bg-[url('/images/tattoo_3_1783205869223.png')] bg-cover bg-center mix-blend-luminosity grayscale group-hover:grayscale-0 transition-all duration-700 group-hover:scale-105" />
            <div className="absolute inset-0 bg-void-charcoal/40 group-hover:bg-transparent transition-colors duration-700" />
          </div>
          
          {/* Desktop Position 1 (Back Piece) */}
          <div className="relative group w-full h-[500px] bg-void overflow-hidden hidden md:block">
            <div className="absolute inset-0 bg-[url('/images/back_piece.jpg')] bg-cover bg-center mix-blend-luminosity grayscale group-hover:grayscale-0 transition-all duration-700 group-hover:scale-105" />
            <div className="absolute inset-0 bg-void-charcoal/40 group-hover:bg-transparent transition-colors duration-700" />
          </div>

          {/* Desktop Bottom Left (Position 4) */}
          <div className="relative group w-full h-[400px] bg-void overflow-hidden hidden md:block">
            <div className="absolute inset-0 bg-[url('/images/2.jpeg')] bg-cover bg-center mix-blend-luminosity grayscale group-hover:grayscale-0 transition-all duration-700 group-hover:scale-105" />
            <div className="absolute inset-0 bg-void-charcoal/40 group-hover:bg-transparent transition-colors duration-700" />
          </div>
        </motion.div>

        {/* Column 2 */}
        <motion.div style={{ y: y2 }} className="flex flex-col gap-6 md:mt-12">
          {/* Mobile Position 2 */}
          <div className="relative group w-full h-[400px] bg-void overflow-hidden md:hidden">
            <div className="absolute inset-0 bg-[url('/images/noah_1.jpg')] bg-cover bg-center mix-blend-luminosity grayscale group-hover:grayscale-0 transition-all duration-700 group-hover:scale-105" />
            <div className="absolute inset-0 bg-void-charcoal/40 group-hover:bg-transparent transition-colors duration-700" />
          </div>
          {/* Desktop Position 2 */}
          <div className="relative group w-full h-[400px] bg-void overflow-hidden hidden md:block">
            <div className="absolute inset-0 bg-[url('/images/noah_1.jpg')] bg-cover bg-center mix-blend-luminosity grayscale group-hover:grayscale-0 transition-all duration-700 group-hover:scale-105" />
            <div className="absolute inset-0 bg-void-charcoal/40 group-hover:bg-transparent transition-colors duration-700" />
          </div>
          
          <div className="relative group w-full h-[250px] bg-void border border-bone/10 flex items-center justify-center p-8 group overflow-hidden">
             {/* Magnetic Button */}
             <motion.a 
                href="https://instagram.com/brkntattoos"
                target="_blank"
                rel="noopener noreferrer"
                className="relative z-20 px-4 sm:px-8 py-6 border border-bone text-bone font-sans uppercase tracking-[0.2em] sm:tracking-[0.3em] text-sm sm:text-base text-center w-full bg-void-charcoal hover:bg-bone hover:text-void transition-colors duration-500"
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                transition={heavyPhysics}
              >
                Enter The Row
              </motion.a>
          </div>
        </motion.div>

        {/* Column 3 (Hidden on mobile) */}
        <motion.div style={{ y: y3 }} className="flex flex-col gap-6 hidden md:flex">
          {/* Desktop Position 3 */}
          <div className="relative group w-full h-[400px] bg-void overflow-hidden">
            <div className="absolute inset-0 bg-[url('/images/3.jpeg')] bg-cover bg-center mix-blend-luminosity grayscale group-hover:grayscale-0 transition-all duration-700 group-hover:scale-105" />
            <div className="absolute inset-0 bg-void-charcoal/40 group-hover:bg-transparent transition-colors duration-700" />
          </div>
          {/* Desktop Position 5 (Bottom Right) */}
          <div className="relative group w-full h-[500px] bg-void overflow-hidden">
             <div className="absolute inset-0 bg-[url('/images/tattoo_2_1783205858266.png')] bg-cover bg-center mix-blend-luminosity grayscale group-hover:grayscale-0 transition-all duration-700 group-hover:scale-105" />
             <div className="absolute inset-0 bg-void-charcoal/40 group-hover:bg-transparent transition-colors duration-700" />
          </div>
        </motion.div>
        
      </div>
    </section>
  )
}
