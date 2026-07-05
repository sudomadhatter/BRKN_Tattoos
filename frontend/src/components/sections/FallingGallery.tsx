'use client'

import { motion, useScroll, useTransform, MotionValue } from 'framer-motion'
import { useRef } from 'react'

const cards = [
  { id: 1, img: '/images/5.jpeg', title: 'The Architect' },
  { id: 2, img: '/images/6.jpeg', title: 'Void Caller' },
  { id: 3, img: '/images/7.jpeg', title: 'Crimson Edge' },
  { id: 4, img: '/images/4.jpeg', title: 'Midnight Sun' },
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

  // Final serif slide: fades in earlier, then HOLDS at full for the rest of the
  // tunnel so it sits fully visible before the Booking section scrolls up over it.
  const finalOpacity = useTransform(scrollYProgress, (v) => {
    if (v <= 0.72) return 0;
    if (v >= 0.82) return 1;
    return (v - 0.72) / 0.10;
  });
  const finalScale = useTransform(scrollYProgress, (v) => {
    if (v <= 0.72) return 0.8;
    if (v >= 0.82) return 1;
    return 0.8 + (((v - 0.72) / 0.10) * 0.2);
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
          <h2 className="text-4xl sm:text-7xl md:text-8xl font-serif text-bone uppercase tracking-widest drop-shadow-2xl text-center px-6 leading-tight">
            Fall Into<br className="block sm:hidden" /> The Ink
          </h2>
          {/* Deep background tunnel glow behind the text */}
          <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,transparent_0%,#0a0a0a_80%)] -z-10" />
        </motion.div>

        {/* Phase 2: Sequential Overlapping Images */}
        {/* Each image starts exactly when the previous image hits its midpoint (fading out) */}
        <div className="absolute inset-0 z-30 flex items-center justify-center pointer-events-none">
          <FallingImage src={cards[0].img} progress={scrollYProgress} range={[0.12, 0.34]} offset="-translate-x-20 -translate-y-12" />
          <FallingImage src={cards[1].img} progress={scrollYProgress} range={[0.26, 0.48]} offset="translate-x-32 translate-y-20" />
          <FallingImage src={cards[2].img} progress={scrollYProgress} range={[0.40, 0.62]} offset="-translate-x-40 translate-y-10" />
          <FallingImage src={cards[3].img} progress={scrollYProgress} range={[0.54, 0.76]} offset="translate-x-20 -translate-y-32" />
        </div>

        {/* Phase 3: Final About Artist Slide */}
        <motion.div
          className="absolute inset-0 z-60 flex items-center justify-center pointer-events-auto px-6 md:px-12"
          style={{ opacity: finalOpacity, scale: finalScale }}
        >
          <div className="w-full max-w-6xl grid grid-cols-1 md:grid-cols-2 gap-6 md:gap-24 items-center">

            {/* Left: Artist Image */}
            <div className="relative w-full aspect-[3/4] max-h-[32vh] md:max-h-[80vh] overflow-hidden rounded-md border border-bone/10 shadow-2xl">
              <div 
                className="absolute inset-0 bg-cover bg-center grayscale contrast-125"
                style={{ backgroundImage: `url(/images/mr_brkn.jpg)` }}
              />
              <div className="absolute inset-0 bg-void-charcoal/20 mix-blend-overlay" />
            </div>

            {/* Right: Artist Copy */}
            <div className="flex flex-col items-start text-left space-y-4 md:space-y-6">
              <div>
                <p className="text-accent-blood tracking-[0.3em] text-xs md:text-sm font-sans uppercase mb-2">
                  The Vision
                </p>
                <h2 className="text-4xl sm:text-5xl md:text-6xl font-serif text-bone uppercase tracking-widest drop-shadow-lg">
                  Artist Mr. BRKN
                </h2>
                <p className="text-bone/50 tracking-widest text-sm md:text-base font-sans uppercase mt-2">
                  Black & Grey • Realism • Custom Work
                </p>
              </div>

              <div className="space-y-4 text-bone/80 font-sans text-sm md:text-base leading-relaxed max-w-lg">
                <p>
                  Started in New York and took those traditional fundamentals of portrait and realism to the next level with the soul of LA creativity and street culture.
                </p>
                <p>
                  Running a custom studio means being blessed to choose who I work with. It ensures it's always the perfect fit for both the artist and the client.
                </p>
              </div>

              <div className="pt-4 border-t border-bone/20 w-full max-w-sm">
                <p className="text-xl md:text-2xl font-serif italic text-bone drop-shadow-md">
                  "Here to turn your skin into a masterpiece."
                </p>
              </div>
            </div>

          </div>
        </motion.div>

      </div>
    </section>
  )
}
