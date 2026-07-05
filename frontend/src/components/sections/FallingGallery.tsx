'use client'

import { motion, useScroll, useTransform, MotionValue } from 'framer-motion'
import { useRef } from 'react'

const cards = [
  { id: 1, img: 'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28?q=80&w=1000&auto=format&fit=crop', title: 'The Architect' },
  { id: 2, img: 'https://images.unsplash.com/photo-1611080359871-36ba93eb8ee0?q=80&w=1000&auto=format&fit=crop', title: 'Void Caller' },
  { id: 3, img: 'https://images.unsplash.com/photo-1590246814883-58847973e443?q=80&w=1000&auto=format&fit=crop', title: 'Crimson Edge' },
  { id: 4, img: 'https://images.unsplash.com/photo-1562085375-7b5ce97bba12?q=80&w=1000&auto=format&fit=crop', title: 'Midnight Sun' },
]

// A helper component to handle the specific transform of a single falling image
const FallingImage = ({ 
  src, 
  progress, 
  range, 
  offset 
}: { 
  src: string, 
  progress: MotionValue<number>, 
  range: number[], 
  offset: string 
}) => {
  // Scale from tiny in the distance (0.1) to massive and flying past the camera (6)
  const scale = useTransform(progress, range, [0.1, 6], { clamp: true })
  
  // Opacity explicitly 0 before and after the range to prevent any peaking
  // Clamped strictly to avoid extrapolation bugs.
  const opacity = useTransform(
    progress, 
    [0, range[0], range[0] + 0.05, range[1] - 0.05, range[1], 1], 
    [0, 0, 1, 1, 0, 0],
    { clamp: true }
  )
  
  return (
    <motion.div 
      className="absolute flex flex-col items-center justify-center pointer-events-none"
      style={{ 
        scale, 
        opacity,
        willChange: "transform, opacity"
      }}
    >
      <div className={`relative w-[300px] sm:w-[400px] h-[400px] sm:h-[500px] overflow-hidden ${offset}`}>
        <div 
          className="absolute inset-0 bg-cover bg-center grayscale"
          style={{ backgroundImage: `url(${src})` }}
        />
        <div className="absolute inset-0 bg-void-charcoal/20" />
      </div>
    </motion.div>
  )
}

export default function FallingGallery() {
  const containerRef = useRef<HTMLDivElement>(null)
  
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end end"]
  })

  // Fade out the intro text and the solid cover image as we start falling
  const introOpacity = useTransform(scrollYProgress, [0, 0.15], [1, 0], { clamp: true })
  const introScale = useTransform(scrollYProgress, [0, 0.15], [1, 1.5], { clamp: true })

  // Final gothic slide fading in at the very end
  const finalOpacity = useTransform(scrollYProgress, [0.85, 1], [0, 1], { clamp: true })
  const finalScale = useTransform(scrollYProgress, [0.85, 1], [0.8, 1], { clamp: true })

  return (
    <section ref={containerRef} className="h-[400vh] w-full relative bg-void">
      <div className="sticky top-0 h-screen w-full overflow-hidden flex items-center justify-center">
        
        {/* The Falling Images */}
        {/* We distribute their animation ranges so nothing appears until the user scrolls past 10% */}
        <FallingImage src={cards[0].img} progress={scrollYProgress} range={[0.15, 0.35]} offset="-translate-x-12 -translate-y-8" />
        <FallingImage src={cards[1].img} progress={scrollYProgress} range={[0.35, 0.55]} offset="translate-x-24 translate-y-16" />
        <FallingImage src={cards[2].img} progress={scrollYProgress} range={[0.55, 0.75]} offset="-translate-x-32 translate-y-4" />
        <FallingImage src={cards[3].img} progress={scrollYProgress} range={[0.75, 0.95]} offset="translate-x-12 -translate-y-24" />

        {/* Final Gothic Slide */}
        <motion.div
          style={{ opacity: finalOpacity, scale: finalScale }}
          className="absolute inset-0 z-40 flex items-center justify-center pointer-events-none"
        >
          <h2 className="text-6xl sm:text-9xl font-gothic text-bone tracking-widest drop-shadow-[0_0_30px_rgba(255,255,255,0.2)]">
            BRKN Tattoos
          </h2>
        </motion.div>

        {/* Deep background tunnel glow */}
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,transparent_0%,#0a0a0a_80%)] pointer-events-none z-20" />
      </div>
    </section>
  )
}
