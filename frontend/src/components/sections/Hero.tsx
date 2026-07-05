'use client'

import { motion, useScroll, useTransform } from 'framer-motion'
import { useRef } from 'react'

export default function Hero() {
  const containerRef = useRef<HTMLDivElement>(null)
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end start"]
  })
  
  const introOpacity = useTransform(scrollYProgress, [0, 0.5], [1, 0])
  const introScale = useTransform(scrollYProgress, [0, 0.5], [1, 0.9])

  const container = {
    hidden: { opacity: 0, y: 30 },
    show: { opacity: 1, y: 0, transition: { staggerChildren: 0.1, delayChildren: 0.3 } },
  }
  const item = {
    hidden: { opacity: 0, y: 20 },
    show: { opacity: 1, y: 0, transition: { duration: 0.8, ease: [0.16, 1, 0.3, 1] as const } },
  }

  const titleWords = ['B','R','K','N', '\u00A0', 'T','A','T','T','O','O','S']

  return (
    <section ref={containerRef} className="relative h-screen w-full flex items-center justify-center overflow-hidden pt-0 md:pt-20 pb-32 md:pb-20">
      
      {/* Decorative Edgy Logo Art Watermark */}
      <motion.div 
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 0.15, scale: 1 }}
        transition={{ duration: 2, ease: "easeOut" }}
        className="absolute inset-0 flex items-center justify-center pointer-events-none z-0 mix-blend-screen"
      >
        <img src="/images/logo.png" alt="BRKN Tattoos Art" className="w-[150vw] md:w-[100vw] max-w-[1400px] h-auto object-contain drop-shadow-[0_0_15px_rgba(255,255,255,0.1)] opacity-30" />
      </motion.div>

      {/* Projector Container - smaller than site width, 80% opacity over global background */}
      <motion.div 
        className="relative w-[90%] max-w-5xl h-[80vh] overflow-hidden opacity-80 mix-blend-screen"
        style={{ opacity: introOpacity, scale: introScale }}
      >
        {/* Video background */}
        <div className="absolute inset-0">
          <video
            autoPlay
            loop
            muted
            playsInline
            className="w-full h-full object-cover filter sepia-[0.3] grayscale-[0.8] contrast-[1.2] brightness-75 projector-fx pointer-events-none"
          >
            <source src="https://test-videos.co.uk/vids/sintel/mp4/h264/720/Sintel_720_10s_1MB.mp4" type="video/mp4" />
          </video>
          {/* Grain overlay */}
          <div className="absolute inset-0 bg-[url('https://upload.wikimedia.org/wikipedia/commons/7/76/1k_Dissolve_Noise_Texture.png')] opacity-20 mix-blend-overlay pointer-events-none" />
          
          {/* Vignette */}
          <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,transparent_40%,#0A0A0C_100%)] pointer-events-none" />
        </div>

      </motion.div>

      {/* Responsive Container for Typography - Bottom Left */}
      <motion.div
        variants={container}
        initial="hidden"
        animate="show"
        className="absolute inset-0 z-20 w-full max-w-7xl mx-auto px-6 md:px-12 flex flex-col justify-end pb-36 md:pb-32 pointer-events-none"
      >
        <div className="flex flex-col items-start">
          <h1 className="text-[clamp(3rem,12.5vw,11rem)] font-serif text-bone uppercase tracking-tighter leading-[0.85] mix-blend-difference flex flex-nowrap whitespace-nowrap overflow-visible drop-shadow-2xl -ml-1 md:-ml-2">
            {titleWords.map((char, i) => (
              <motion.span 
                key={i} 
                variants={item} 
                className="inline-block"
                transition={{ type: "spring", mass: 1.5, stiffness: 50, damping: 20 }}
              >
                {char}
              </motion.span>
            ))}
          </h1>
          
          <motion.p 
            initial={{ opacity: 0, y: 15 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ type: "spring", mass: 1.5, stiffness: 50, damping: 20, delay: 1.2 }}
            className="mt-4 md:mt-6 text-xl md:text-3xl font-serif italic text-accent-blood tracking-wide drop-shadow-lg pl-1 md:pl-2"
          >
            Where fine art meets the LA underground.
          </motion.p>
        </div>
      </motion.div>


      
    </section>
  )
}
