'use client'

import { motion, AnimatePresence } from 'framer-motion'
import { useState } from 'react'
import { heavyPhysics } from '../motion/MotionWrapper'

export default function BookingForm() {
  const [isVerified, setIsVerified] = useState(false)

  const handleVerification = (e: React.FormEvent) => {
    e.preventDefault()
    setIsVerified(true)
  }

  // Animation variants for the staggered form fields
  const container = {
    hidden: { opacity: 0 },
    show: {
      opacity: 1,
      transition: {
        staggerChildren: 0.1,
        delayChildren: 0.3
      }
    }
  }

  const item = {
    hidden: { opacity: 0, y: 20 },
    show: { opacity: 1, y: 0, transition: heavyPhysics }
  }

  return (
    <section className="py-24 px-6 sm:px-12 w-full max-w-4xl mx-auto flex flex-col gap-16 relative overflow-hidden">
      
      {/* Decorative Edgy Logo Art */}
      <motion.div 
        initial={{ opacity: 0, x: 50 }}
        whileInView={{ opacity: 0.15, x: 0 }}
        viewport={{ once: true, margin: "-100px" }}
        transition={{ duration: 1.5, ease: "easeOut" }}
        className="absolute right-0 top-0 w-[400px] md:w-[600px] pointer-events-none translate-x-1/4 md:translate-x-1/3 -translate-y-12 md:-translate-y-24 z-0 mix-blend-screen"
      >
        <img src="/images/logo.png" alt="BRKN Tattoos Art" className="w-full h-auto object-contain drop-shadow-[0_0_15px_rgba(255,255,255,0.1)]" />
      </motion.div>

      <div className="flex flex-col gap-4 relative z-10">
        <h2 className="text-4xl sm:text-6xl font-serif text-bone uppercase tracking-widest leading-none">
          Initiation
        </h2>
        <p className="text-bone/50 font-sans tracking-widest uppercase text-sm">
          Submit your vision. We will reach out if it aligns.
        </p>
      </div>

      <div className="relative min-h-[500px] z-10">
        {/* Verification Wave Shatter */}
        <AnimatePresence>
          {!isVerified && (
            <motion.div 
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, scale: 1.1, filter: "blur(20px)", transition: { duration: 0.8, ease: "anticipate" } }}
              className="absolute inset-0 flex flex-col items-center justify-center bg-void border border-accent-blood p-8 z-20 text-center"
            >
              <h3 className="text-2xl font-serif text-accent-blood mb-6 uppercase tracking-widest">Age Gate</h3>
              <p className="text-bone/70 font-sans tracking-widest text-sm mb-12">
                You must be 18 years of age or older to enter the parlor.
              </p>
              <motion.button 
                onClick={handleVerification}
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                transition={heavyPhysics}
                className="border border-bone text-bone px-8 py-4 font-sans uppercase tracking-[0.2em] hover:bg-bone hover:text-void transition-colors duration-300"
              >
                I am 18 or older
              </motion.button>
            </motion.div>
          )}
        </AnimatePresence>

        {/* The Actual Form with Staggered Cascade */}
        {isVerified && (
          <motion.form 
            variants={container}
            initial="hidden"
            animate="show"
            className="flex flex-col gap-8 w-full relative z-10"
            onSubmit={(e) => e.preventDefault()}
          >
            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              <motion.div variants={item} className="flex flex-col gap-2 relative group">
                <label className="text-xs uppercase tracking-[0.2em] text-bone/50 transition-colors group-focus-within:text-accent-gold">Full Name</label>
                <input type="text" className="bg-transparent border-b border-bone/20 focus:border-transparent outline-none py-2 text-bone font-sans transition-colors duration-300 peer" required />
                <span className="absolute bottom-0 left-1/2 w-0 h-[1px] bg-accent-gold transition-all duration-500 ease-out peer-focus:w-full peer-focus:left-0"></span>
              </motion.div>
              
              <motion.div variants={item} className="flex flex-col gap-2 relative group">
                <label className="text-xs uppercase tracking-[0.2em] text-bone/50 transition-colors group-focus-within:text-accent-gold">Email</label>
                <input type="email" className="bg-transparent border-b border-bone/20 focus:border-transparent outline-none py-2 text-bone font-sans transition-colors duration-300 peer" required />
                <span className="absolute bottom-0 left-1/2 w-0 h-[1px] bg-accent-gold transition-all duration-500 ease-out peer-focus:w-full peer-focus:left-0"></span>
              </motion.div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              <motion.div variants={item} className="flex flex-col gap-2 relative group">
                <label className="text-xs uppercase tracking-[0.2em] text-bone/50 transition-colors group-focus-within:text-accent-gold">Instagram Handle</label>
                <input type="text" placeholder="@" className="bg-transparent border-b border-bone/20 focus:border-transparent outline-none py-2 text-bone font-sans transition-colors duration-300 peer" />
                <span className="absolute bottom-0 left-1/2 w-0 h-[1px] bg-accent-gold transition-all duration-500 ease-out peer-focus:w-full peer-focus:left-0"></span>
              </motion.div>

              <motion.div variants={item} className="flex flex-col gap-2 relative group">
                <label className="text-xs uppercase tracking-[0.2em] text-bone/50 transition-colors group-focus-within:text-accent-gold">Body Placement</label>
                <input type="text" className="bg-transparent border-b border-bone/20 focus:border-transparent outline-none py-2 text-bone font-sans transition-colors duration-300 peer" required />
                <span className="absolute bottom-0 left-1/2 w-0 h-[1px] bg-accent-gold transition-all duration-500 ease-out peer-focus:w-full peer-focus:left-0"></span>
              </motion.div>
            </div>

            <motion.div variants={item} className="flex flex-col gap-2 relative group">
              <label className="text-xs uppercase tracking-[0.2em] text-bone/50 transition-colors group-focus-within:text-accent-gold">The Vision (Concept)</label>
              <textarea rows={4} className="bg-transparent border-b border-bone/20 focus:border-transparent outline-none py-2 text-bone font-sans transition-colors duration-300 resize-none peer" required></textarea>
              <span className="absolute bottom-0 left-1/2 w-0 h-[1px] bg-accent-gold transition-all duration-500 ease-out peer-focus:w-full peer-focus:left-0"></span>
            </motion.div>

            <motion.div variants={item} className="flex flex-col gap-2 group">
              <label className="text-xs uppercase tracking-[0.2em] text-bone/50">Reference Material (Optional)</label>
              <input 
                type="file" 
                accept="image/*"
                multiple
                className="text-bone/50 font-sans text-sm file:mr-4 file:py-2 file:px-4 file:border file:border-bone/20 file:bg-transparent file:text-bone file:uppercase file:tracking-widest file:text-xs hover:file:bg-bone/10 transition-colors file:cursor-pointer cursor-pointer" 
              />
            </motion.div>

            <motion.button 
              variants={item}
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.95 }}
              transition={heavyPhysics}
              className="mt-8 bg-bone text-void py-6 uppercase font-sans tracking-[0.3em] font-bold hover:bg-accent-gold transition-colors duration-500"
              type="submit"
            >
              Submit Request
            </motion.button>
          </motion.form>
        )}
      </div>
    </section>
  )
}
