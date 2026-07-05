'use client'

import { motion, useScroll, useTransform, MotionValue } from 'framer-motion'
import { useRef } from 'react'

const cards = [
  { id: 1, img: 'https://picsum.photos/seed/brkn1/800/1000', title: 'The Architect' },
  { id: 2, img: 'https://picsum.photos/seed/brkn2/800/1000', title: 'Void Caller' },
  { id: 3, img: 'https://picsum.photos/seed/brkn3/800/1000', title: 'Crimson Edge' },
  { id: 4, img: 'https://picsum.photos/seed/brkn4/800/1000', title: 'Midnight Sun' },
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
  // Scale starts small when its range begins, and grows massive by the time its range ends.
  const scale = useTransform(progress, (v) => {
    if (v <= range[0]) return 0.5;
    if (v >= range[1]) return 4.0;
    const p = (v - range[0]) / (range[1] - range[0]);
    return 0.5 + (p * 3.5);
  });
  
  // Opacity: Starts at 0. Fades in during the first half of its growth. Fades out during the second half.
  const opacity = useTransform(progress, (v) => {
    if (v <= range[0] || v >= range[1]) return 0;
    
    const midPoint = range[0] + (range[1] - range[0]) / 2;
    
    if (v < midPoint) {
      // Fading in
      return (v - range[0]) / (midPoint - range[0]);
    } else {
      // Fading out
      return 1 - ((v - midPoint) / (range[1] - midPoint));
    }
  });
  
  return (
    <motion.div 
      className={`absolute flex flex-col items-center justify-center pointer-events-none ${offset}`}
      style={{ 
        scale, 
        opacity,
        willChange: "transform, opacity"
      }}
    >
      <div className="relative w-[280px] sm:w-[350px] h-[380px] sm:h-[450px] overflow-hidden rounded-md border border-bone/10 shadow-2xl">
        <div 
          className="absolute inset-0 bg-cover bg-center grayscale"
          style={{ backgroundImage: `url(${src})` }}
        />
        <div className="absolute inset-0 bg-void-charcoal/20 mix-blend-overlay" />
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

  // Phase 1 (Intro): Stays visible at the start, fades out slowly between 0.10 and 0.25 to make room for Image 1.
  const introOpacity = useTransform(scrollYProgress, (v) => {
    if (v <= 0.10) return 1;
    if (v >= 0.25) return 0;
    return 1 - ((v - 0.10) / 0.15);
  });
  const introScale = useTransform(scrollYProgress, (v) => {
    if (v <= 0) return 1;
    if (v >= 0.3) return 1.5;
    return 1 + ((v / 0.3) * 0.5);
  });

  // Final serif slide fading in at the absolute end of the tunnel
  const finalOpacity = useTransform(scrollYProgress, (v) => {
    if (v <= 0.85) return 0;
    if (v >= 1.0) return 1;
    return (v - 0.85) / 0.15;
  });
  const finalScale = useTransform(scrollYProgress, (v) => {
    if (v <= 0.85) return 0.8;
    if (v >= 1.0) return 1;
    return 0.8 + (((v - 0.85) / 0.15) * 0.2);
  });

  return (
    <section ref={containerRef} className="h-[400vh] w-full relative bg-void">
      <div className="sticky top-0 h-screen w-full overflow-hidden flex items-center justify-center bg-void">
        
        {/* Phase 1: The Starting Text */}
        <motion.div 
          className="absolute inset-0 z-50 flex flex-col items-center justify-center pointer-events-none"
          style={{ opacity: introOpacity, scale: introScale }}
        >
          <p className="text-accent-blood tracking-[0.5em] text-sm md:text-base font-sans uppercase mb-4">
            The Void
          </p>
          <h2 className="text-5xl sm:text-7xl md:text-8xl font-serif text-bone uppercase tracking-widest drop-shadow-2xl">
            Fall Into The Ink
          </h2>
          {/* Deep background tunnel glow behind the text */}
          <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,transparent_0%,#0a0a0a_80%)] -z-10" />
        </motion.div>

        {/* Phase 2: Sequential Overlapping Images */}
        {/* Each image starts exactly when the previous image hits its midpoint (fading out) */}
        <div className="absolute inset-0 z-30 flex items-center justify-center pointer-events-none">
          <FallingImage src={cards[0].img} progress={scrollYProgress} range={[0.15, 0.40]} offset="-translate-x-20 -translate-y-12" />
          <FallingImage src={cards[1].img} progress={scrollYProgress} range={[0.30, 0.55]} offset="translate-x-32 translate-y-20" />
          <FallingImage src={cards[2].img} progress={scrollYProgress} range={[0.45, 0.70]} offset="-translate-x-40 translate-y-10" />
          <FallingImage src={cards[3].img} progress={scrollYProgress} range={[0.60, 0.85]} offset="translate-x-20 -translate-y-32" />
        </div>

        {/* Phase 3: Final Serif Slide */}
        <motion.div
          className="absolute inset-0 z-60 flex items-center justify-center pointer-events-none"
          style={{ opacity: finalOpacity, scale: finalScale }}
        >
          <h2 className="text-6xl sm:text-8xl md:text-[10rem] font-serif text-bone uppercase tracking-widest drop-shadow-[0_0_30px_rgba(255,255,255,0.2)]">
            BRKN Tattoos
          </h2>
        </motion.div>

      </div>
    </section>
  )
}
